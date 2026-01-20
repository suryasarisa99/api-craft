import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_craft/features/request/services/req_resolver.dart';
import 'package:api_craft/core/models/models.dart';
import 'package:api_craft/features/sidebar/file_tree_provider.dart';
import 'package:api_craft/features/request/models/node_config_model.dart';
import 'package:api_craft/features/request/models/node_model.dart';
import 'package:api_craft/features/workspace/workspace_model.dart';

void main() {
  group('ReqResolver Inheritance Tests', () {
    test(
      'resolveRequestSettings should return defaults if no settings configured',
      () {
        final overrideContainer = ProviderContainer(
          overrides: [
            fileTreeProvider.overrideWith(
              () => FileTreeNotifierTest({
                'req1': RequestNode(
                  id: 'req1',
                  parentId: 'root',
                  name: 'Req',
                  config: RequestNodeConfig(queryParameters: []),
                  statusCode: 200,
                  sortOrder: 0,
                ),
              }),
            ),
          ],
        );
        final resolver = overrideContainer.read(requestResolverProvider);
        final settings = resolver.resolveRequestSettings(
          overrideContainer.read(fileTreeProvider).nodeMap['req1']!,
        );

        expect(settings.maxRedirects, 5);
        expect(settings.followRedirects, true);
        expect(settings.encodeUrl, true);
      },
    );

    test('resolveRequestSettings should inherit from Workspace', () {
      final overrideContainer = ProviderContainer(
        overrides: [
          fileTreeProvider.overrideWith(
            () => FileTreeNotifierTest({
              'ws1': WorkspaceNode(
                workspace: const WorkspaceModel(
                  id: 'ws1',
                  name: 'Workspace',
                  type: WorkspaceType.filesystem,
                  path: '/tmp',
                ),
                config: FolderNodeConfig(
                  settings: const RequestSettings(
                    maxRedirects: 10,
                    followRedirects: false,
                  ),
                ),
              ),
              'req1': RequestNode(
                id: 'req1',
                parentId: 'ws1',
                name: 'Req',
                config: RequestNodeConfig(queryParameters: []),
                statusCode: 200,
                sortOrder: 0,
              ),
            }),
          ),
        ],
      );
      final resolver = overrideContainer.read(requestResolverProvider);
      final settings = resolver.resolveRequestSettings(
        overrideContainer.read(fileTreeProvider).nodeMap['req1']!,
      );

      expect(settings.maxRedirects, 10);
      expect(settings.followRedirects, false);
      expect(settings.encodeUrl, true); // Default
    });

    test('resolveProxySettings should find workspace proxy', () {
      final overrideContainer = ProviderContainer(
        overrides: [
          fileTreeProvider.overrideWith(
            () => FileTreeNotifierTest({
              'ws1': WorkspaceNode(
                workspace: const WorkspaceModel(
                  id: 'ws1',
                  name: 'Workspace',
                  type: WorkspaceType.filesystem,
                  path: '/tmp',
                ),
                config: FolderNodeConfig(
                  proxy: const ProxySettings(
                    host: '127.0.0.1',
                    port: '8080',
                    isEnabled: true,
                  ),
                ),
              ),
              'folder1': FolderNode(
                id: 'folder1',
                parentId: 'ws1',
                name: 'Folder',
                config: FolderNodeConfig(),
                sortOrder: 0,
              ),
              'req1': RequestNode(
                id: 'req1',
                parentId: 'folder1',
                name: 'Req',
                config: RequestNodeConfig(queryParameters: []),
                statusCode: 200,
                sortOrder: 0,
              ),
            }),
          ),
        ],
      );
      final resolver = overrideContainer.read(requestResolverProvider);
      final proxy = resolver.resolveProxySettings(
        overrideContainer.read(fileTreeProvider).nodeMap['req1']!,
      );

      expect(proxy.isEnabled, true);
      expect(proxy.host, '127.0.0.1');
      expect(proxy.port, '8080');
    });

    test('resolveRequestSettingsWithSource should identify correctly', () {
      final overrideContainer = ProviderContainer(
        overrides: [
          fileTreeProvider.overrideWith(
            () => FileTreeNotifierTest({
              'ws1': WorkspaceNode(
                workspace: const WorkspaceModel(
                  id: 'ws1',
                  name: 'Workspace',
                  type: WorkspaceType.filesystem,
                  path: '/tmp',
                ),
                config: FolderNodeConfig(
                  settings: const RequestSettings(
                    maxRedirects: 10,
                    followRedirects: false,
                  ),
                ),
              ),
              'folder1': FolderNode(
                id: 'folder1',
                parentId: 'ws1',
                name: 'Folder',
                config: FolderNodeConfig(),
                sortOrder: 0,
              ),
              'req1': RequestNode(
                id: 'req1',
                parentId: 'folder1',
                name: 'Req',
                config: RequestNodeConfig(queryParameters: []),
                statusCode: 200,
                sortOrder: 0,
              ),
            }),
          ),
        ],
      );
      final resolver = overrideContainer.read(requestResolverProvider);
      final (settings, source) = resolver.resolveRequestSettingsWithSource(
        overrideContainer.read(fileTreeProvider).nodeMap['req1']!,
      );

      expect(settings.maxRedirects, 10);
      expect(source?.id, 'ws1');
      expect(source?.name, 'Workspace');
    });
  });
}

class FileTreeNotifierTest extends FileTreeNotifier {
  final Map<String, Node> _initialMap;
  FileTreeNotifierTest(this._initialMap);

  @override
  TreeData build() {
    return TreeData(_initialMap, isLoading: false);
  }
}
