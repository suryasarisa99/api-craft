import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestLoadingState {
  final bool isSending;
  final DateTime? sendStartTime;
  final String? sendError;

  const RequestLoadingState({
    this.isSending = false,
    this.sendStartTime,
    this.sendError,
  });

  RequestLoadingState copyWith({
    bool? isSending,
    DateTime? sendStartTime,
    String? sendError,
  }) {
    return RequestLoadingState(
      isSending: isSending ?? this.isSending,
      sendStartTime: sendStartTime ?? this.sendStartTime,
      sendError: sendError ?? this.sendError,
    );
  }
}

final requestLoadingProvider =
    NotifierProvider.family<
      RequestLoadingNotifier,
      RequestLoadingState,
      String
    >(RequestLoadingNotifier.new);

class RequestLoadingNotifier extends Notifier<RequestLoadingState> {
  final String id;
  RequestLoadingNotifier(this.id);

  @override
  RequestLoadingState build() {
    return const RequestLoadingState();
  }

  void startSending() {
    state = state.copyWith(
      isSending: true,
      sendStartTime: DateTime.now(),
      sendError: null,
    );
  }

  void finishSending() {
    state = state.copyWith(isSending: false);
  }

  void setError(String error) {
    state = state.copyWith(isSending: false, sendError: error);
  }
}
