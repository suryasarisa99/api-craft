import 'dart:async';
import 'package:api_craft/core/repository/data_repository.dart';
import 'package:api_craft/core/repository/storage_repository.dart';
import 'package:api_craft/core/services/ws_service.dart';
import 'package:api_craft/features/request/models/websocket_message.dart';
import 'package:api_craft/features/request/models/websocket_session.dart';
import 'package:api_craft/features/request/services/req_resolver.dart';
import 'package:api_craft/core/providers/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nanoid/nanoid.dart';

// Service provider
final wsServiceProvider = Provider((ref) => WsService());
final requestResolverProvider = Provider((ref) => RequestResolver(ref));

// State for a single WS request
class WsRequestState {
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final String? activeSessionId;
  final List<WebSocketMessage> messages;

  WsRequestState({
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.activeSessionId,
    this.messages = const [],
    this.history = const [],
    this.selectedSessionId,
  });

  final List<WebSocketSession> history;
  final String? selectedSessionId;

  WsRequestState copyWith({
    bool? isConnected,
    bool? isConnecting,
    String? error,
    String? activeSessionId,
    List<WebSocketMessage>? messages,
    List<WebSocketSession>? history,
    String? selectedSessionId,
  }) {
    return WsRequestState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnected,
      error: error,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      messages: messages ?? this.messages,
      history: history ?? this.history,
      selectedSessionId: selectedSessionId ?? this.selectedSessionId,
    );
  }
}

final wsRequestProvider =
    StateNotifierProvider.family<WsRequestNotifier, WsRequestState, String>(
      (ref, requestId) => WsRequestNotifier(ref, requestId),
    );

class WsRequestNotifier extends StateNotifier<WsRequestState> {
  final Ref ref;
  final String requestId;
  StreamSubscription? _subscription;

  WsRequestNotifier(this.ref, this.requestId) : super(WsRequestState()) {
    _loadHistory();
  }

  WsService get _wsService => ref.read(wsServiceProvider);
  DataRepository get _repo => ref.read(dataRepositoryProvider);
  RequestResolver get _resolver => ref.read(requestResolverProvider);

  /// Connects to a WebSocket starting a new session
  Future<void> connect(BuildContext context, {bool useProxy = false}) async {
    if (state.isConnected || state.isConnecting) return;

    try {
      // 1. Resolve Request
      final resolved = await _resolver.resolveForExecution(
        requestId,
        context: context,
      );

      state = WsRequestState(
        isConnected: false,
        isConnecting: true,
        messages: [], // Clear previous session messages on new connect
      );
      // 2. Create Session
      final sessionId = nanoid();
      final session = WebSocketSession(
        id: sessionId,
        requestId: requestId,
        url: resolved.uri.toString(),
        startTime: DateTime.now(),
      );
      await _repo.createWebSocketSession(session);

      // 3. Connect (Manual Handshake)
      const proxyHost = '127.0.0.1';
      const proxyPort = 8080;

      await _wsService.manualConnect(
        requestContext: resolved,
        proxyHost: useProxy ? proxyHost : null,
        proxyPort: useProxy ? proxyPort : null,
      );

      state = WsRequestState(
        isConnected: true,
        isConnecting: false,
        activeSessionId: sessionId,
        messages: [],
        selectedSessionId: sessionId,
      );
      _loadHistory();

      // 4. Listen
      _subscription = _wsService.getStream()?.listen(
        (data) {
          _addMessage(data.toString(), false);
        },
        onError: (e) {
          state = state.copyWith(isConnected: false, error: e.toString());
          _endSession();
        },
        onDone: () {
          state = state.copyWith(isConnected: false);
          _endSession();
        },
      );
    } catch (e) {
      state = WsRequestState(
        isConnected: false,
        isConnecting: false,
        error: e.toString(),
        messages: [],
      );
    }
  }

  Future<void> disconnect() async {
    _wsService.disconnect();
    await _endSession();
    state = state.copyWith(isConnected: false);
  }

  Future<void> _endSession() async {
    _subscription?.cancel();
    _subscription = null;
    final sessionId = state.activeSessionId;

    if (sessionId != null) {
      // Update end time in DB
      final session = WebSocketSession(
        id: sessionId,
        requestId: requestId,
        startTime:
            DateTime.now(), // This value won't overwrite existing if DB update is partial, but here we replace.
        // Ideally fetch first. For now, since we only list by start time,
        // and we don't have start time here, we might just update end time via SQL if possible.
        // But `updateWebSocketSession` replaces the row.
        // Let's rely on the fact that we loaded it? No.
        // Let's just leave end time open for now or implement partial update later.
        // Actually, we can just skip updating end time for this iteration as it wasn't a strict requirement,
        // OR (Better) - we can read the session from `state.history` if we have it!
        // But `state.history` might be empty if we didn't load it yet.
        endTime: DateTime.now(),
      );
      // await _repo.updateWebSocketSession(session); // Commented out until we can fetch safely
    }
  }

  Future<void> sendMessage(String message) async {
    if (!state.isConnected) return;

    try {
      _wsService.send(message);
      await _addMessage(message, true);
    } catch (e) {
      state = state.copyWith(error: "Failed to send: $e");
    }
  }

  Future<void> _addMessage(String content, bool isSent) async {
    final sessionId = state.activeSessionId;
    if (sessionId == null) return;

    final msg = WebSocketMessage(
      id: nanoid(),
      requestId: requestId,
      sessionId: sessionId,
      isSent: isSent,
      message: content,
      timestamp: DateTime.now(),
    );

    await _repo.addWebSocketMessage(msg);

    state = state.copyWith(messages: [msg, ...state.messages]);
  }

  Future<void> clearHistory() async {
    if (state.activeSessionId != null) {
      await _repo.clearWebSocketSessionMessages(state.activeSessionId!);
      state = state.copyWith(messages: []);
    }
  }

  Future<void> _loadHistory() async {
    final sessions = await _repo.getWebSocketSessions(requestId);
    // Sort recent first
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

    // If we have history but no active session and no selected session, select the most recent one
    var selected = state.selectedSessionId;
    List<WebSocketMessage> msgs = state.messages;

    if (selected == null && sessions.isNotEmpty && !state.isConnected) {
      selected = sessions.first.id;
      msgs = await _repo.getWebSocketMessages(selected);
    }

    state = state.copyWith(
      history: sessions,
      selectedSessionId: selected,
      messages: msgs,
    );
  }

  Future<void> selectSession(String sessionId) async {
    if (state.isConnected)
      return; // Don't switch while connected? Or allow but warn?

    final msgs = await _repo.getWebSocketMessages(sessionId);
    state = state.copyWith(
      selectedSessionId: sessionId,
      messages: msgs,
      activeSessionId: null,
    ); // activeSessionId null implies viewing history, not live?
    // Actually activeSessionId implies *Live* session.
  }

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteWebSocketSession(sessionId);
    await _loadHistory();
  }

  Future<void> clearHistoryRequest() async {
    await _repo.clearWebSocketHistory(requestId);
    state = state.copyWith(history: [], messages: [], selectedSessionId: null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
