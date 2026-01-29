import 'dart:io';

class SystemProxyException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  SystemProxyException(this.code, this.message, [this.details]);

  @override
  String toString() => 'SystemProxyException($code): $message';
}

class SystemProxy {
  /// Get all network services (Wi-Fi, Ethernet, etc.)
  static Future<List<String>> _getNetworkServices() async {
    try {
      final result = await Process.run('networksetup', [
        '-listallnetworkservices',
      ]);

      if (result.exitCode != 0) {
        throw SystemProxyException(
          'COMMAND_ERROR',
          'Failed to list network services: ${result.stderr}',
        );
      }

      final output = result.stdout.toString();
      final services = output
          .split('\n')
          .where(
            (line) =>
                line.isNotEmpty &&
                !line.contains('An asterisk') &&
                !line.startsWith('*'),
          )
          .toList();

      return services;
    } catch (e) {
      throw SystemProxyException(
        'PROCESS_ERROR',
        'Error getting network services: $e',
      );
    }
  }

  /// Set system-wide HTTP and HTTPS proxy
  ///
  /// [host] - Proxy server hostname or IP address
  /// [port] - Proxy server port
  /// [bypass] - List of domains to bypass the proxy
  ///
  /// Returns a map with success status
  static Future<Map<String, dynamic>> setProxy({
    required String host,
    required int port,
    List<String> bypass = const ['localhost', '127.0.0.1', '*.local'],
  }) async {
    try {
      final services = await _getNetworkServices();

      if (services.isEmpty) {
        throw SystemProxyException('NO_SERVICES', 'No network services found');
      }

      int successCount = 0;
      final errors = <String>[];

      for (final service in services) {
        try {
          // Set HTTP proxy
          await Process.run('networksetup', [
            '-setwebproxy',
            service,
            host,
            port.toString(),
          ]);

          // Enable HTTP proxy
          await Process.run('networksetup', [
            '-setwebproxystate',
            service,
            'on',
          ]);

          // Set HTTPS proxy
          await Process.run('networksetup', [
            '-setsecurewebproxy',
            service,
            host,
            port.toString(),
          ]);

          // Enable HTTPS proxy
          await Process.run('networksetup', [
            '-setsecurewebproxystate',
            service,
            'on',
          ]);

          // Set bypass domains if provided
          if (bypass.isNotEmpty) {
            await Process.run('networksetup', [
              '-setproxybypassdomains',
              service,
              ...bypass,
            ]);
          }

          successCount++;
        } catch (e) {
          errors.add('$service: $e');
        }
      }

      if (successCount == 0) {
        throw SystemProxyException(
          'SET_PROXY_ERROR',
          'Failed to set proxy on any service: ${errors.join(', ')}',
        );
      }

      return {
        'success': true,
        'message': 'Proxy set on $successCount/${services.length} services',
        'services': successCount,
      };
    } catch (e) {
      if (e is SystemProxyException) rethrow;
      throw SystemProxyException('SET_PROXY_ERROR', 'Error setting proxy: $e');
    }
  }

  /// Clear system-wide proxy settings
  ///
  /// Returns a map with success status
  static Future<Map<String, dynamic>> clearProxy() async {
    try {
      final services = await _getNetworkServices();

      if (services.isEmpty) {
        throw SystemProxyException('NO_SERVICES', 'No network services found');
      }

      int successCount = 0;
      final errors = <String>[];

      for (final service in services) {
        try {
          // Disable HTTP proxy
          await Process.run('networksetup', [
            '-setwebproxystate',
            service,
            'off',
          ]);

          // Disable HTTPS proxy
          await Process.run('networksetup', [
            '-setsecurewebproxystate',
            service,
            'off',
          ]);

          successCount++;
        } catch (e) {
          errors.add('$service: $e');
        }
      }

      if (successCount == 0) {
        throw SystemProxyException(
          'CLEAR_PROXY_ERROR',
          'Failed to clear proxy on any service: ${errors.join(', ')}',
        );
      }

      return {
        'success': true,
        'message': 'Proxy cleared on $successCount/${services.length} services',
        'services': successCount,
      };
    } catch (e) {
      if (e is SystemProxyException) rethrow;
      throw SystemProxyException(
        'CLEAR_PROXY_ERROR',
        'Error clearing proxy: $e',
      );
    }
  }

  /// Get current system proxy settings
  ///
  /// Returns a map containing:
  /// - httpEnabled: bool
  /// - httpsEnabled: bool
  /// - httpHost: String
  /// - httpsHost: String
  /// - httpPort: int
  /// - httpsPort: int
  /// - bypass: List<String>
  static Future<Map<String, dynamic>> getProxySettings() async {
    try {
      final services = await _getNetworkServices();
      print("services: $services");

      if (services.isEmpty) {
        return {
          'httpEnabled': false,
          'httpsEnabled': false,
          'httpHost': '',
          'httpsHost': '',
          'httpPort': 0,
          'httpsPort': 0,
          'bypass': <String>[],
        };
      }

      // Get settings from first active service
      final service = services.first;

      // Get HTTP proxy settings
      final httpResult = await Process.run('networksetup', [
        '-getwebproxy',
        service,
      ]);

      // Get HTTPS proxy settings
      final httpsResult = await Process.run('networksetup', [
        '-getsecurewebproxy',
        service,
      ]);

      // Get bypass domains
      final bypassResult = await Process.run('networksetup', [
        '-getproxybypassdomains',
        service,
      ]);

      // Parse HTTP proxy
      final httpOutput = httpResult.stdout.toString();
      final httpEnabled = httpOutput.contains('Enabled: Yes');
      final httpHost = _extractValue(httpOutput, 'Server:');
      final httpPort = int.tryParse(_extractValue(httpOutput, 'Port:')) ?? 0;

      // Parse HTTPS proxy
      final httpsOutput = httpsResult.stdout.toString();
      final httpsEnabled = httpsOutput.contains('Enabled: Yes');
      final httpsHost = _extractValue(httpsOutput, 'Server:');
      final httpsPort = int.tryParse(_extractValue(httpsOutput, 'Port:')) ?? 0;

      // Parse bypass domains
      final bypassOutput = bypassResult.stdout.toString();
      final bypass = bypassOutput
          .split('\n')
          .where((line) => line.trim().isNotEmpty && !line.contains('There'))
          .toList();

      return {
        'httpEnabled': httpEnabled,
        'httpsEnabled': httpsEnabled,
        'httpHost': httpHost,
        'httpsHost': httpsHost,
        'httpPort': httpPort,
        'httpsPort': httpsPort,
        'bypass': bypass,
      };
    } catch (e) {
      throw SystemProxyException(
        'GET_PROXY_ERROR',
        'Error getting proxy settings: $e',
      );
    }
  }

  /// Helper to extract value from networksetup output
  static String _extractValue(String output, String key) {
    final lines = output.split('\n');
    for (final line in lines) {
      if (line.contains(key)) {
        final parts = line.split(':');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
    }
    return '';
  }

  /// Check if proxy is currently enabled
  static Future<bool> isProxyEnabled() async {
    final settings = await getProxySettings();
    return settings['httpEnabled'] == true || settings['httpsEnabled'] == true;
  }
}
