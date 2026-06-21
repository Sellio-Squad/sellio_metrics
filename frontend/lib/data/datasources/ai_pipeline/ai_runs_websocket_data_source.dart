import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Three-state connection status for the WebSocket.
enum WsConnectionStatus {
  connecting,
  connected,
  disconnected,
}

abstract class AiRunsWebSocketDataSource {
  Stream<Map<String, dynamic>> get runsStream;
  Stream<WsConnectionStatus> get connectionStatusStream;
  void connect();
  void disconnect();
}

@LazySingleton(as: AiRunsWebSocketDataSource)
class AiRunsWebSocketDataSourceImpl implements AiRunsWebSocketDataSource {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _runsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WsConnectionStatus> _statusController =
      StreamController<WsConnectionStatus>.broadcast();

  bool _isStopped = false;
  WsConnectionStatus _currentStatus = WsConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnecting = false;

  @override
  Stream<Map<String, dynamic>> get runsStream => _runsController.stream;

  @override
  Stream<WsConnectionStatus> get connectionStatusStream =>
      _statusController.stream;

  void _setStatus(WsConnectionStatus status) {
    if (_currentStatus == status) return;
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  @override
  void connect() {
    if (_isStopped || _isConnecting) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    // Close old channel cleanly before opening a new one
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _setStatus(WsConnectionStatus.connecting);

    final wsUrl = ApiEndpoints.aiPipelineWs();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (raw) {
          _isConnecting = false;
          _reconnectAttempts = 0;
          _setStatus(WsConnectionStatus.connected);
          _resetPingTimer();

          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            if (!_runsController.isClosed) {
              _runsController.add(json);
            }
          } catch (_) {
            // ignore malformed JSON
          }
        },
        onError: (error) {
          _isConnecting = false;
          _pingTimer?.cancel();
          _setStatus(WsConnectionStatus.disconnected);
          _scheduleReconnect();
        },
        onDone: () {
          _isConnecting = false;
          _pingTimer?.cancel();
          _setStatus(WsConnectionStatus.disconnected);
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnecting = false;
      _setStatus(WsConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Send a ping every 30s to keep the WebSocket alive.
  void _resetPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        // If sending fails, the onError/onDone will handle reconnect
      }
    });
  }

  void _scheduleReconnect() {
    if (_isStopped) return;
    _reconnectTimer?.cancel();

    // Exponential backoff capped at 30 seconds
    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 30);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  @override
  void disconnect() {
    _isStopped = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    if (!_runsController.isClosed) _runsController.close();
    if (!_statusController.isClosed) _statusController.close();
  }
}
