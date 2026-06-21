import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class AiRunsWebSocketDataSource {
  Stream<Map<String, dynamic>> get runsStream;
  Stream<bool> get connectionStatusStream;
  void connect();
  void disconnect();
}

@LazySingleton(as: AiRunsWebSocketDataSource)
class AiRunsWebSocketDataSourceImpl implements AiRunsWebSocketDataSource {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _runsController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  
  bool _isDisposed = false;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  @override
  Stream<Map<String, dynamic>> get runsStream => _runsController.stream;

  @override
  Stream<bool> get connectionStatusStream => _statusController.stream;

  @override
  void connect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    
    final wsUrl = ApiEndpoints.aiPipelineWs();
    _isConnected = false;
    _statusController.add(false);
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _reconnectAttempts = 0;

      // Note: we can send a subscription ping or similar if needed,
      // but the DO automatically registers client and pushes on connection.
      
      _channel!.stream.listen(
        (raw) {
          if (!_isConnected) {
            _isConnected = true;
            _statusController.add(true);
          }
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            if (!_runsController.isClosed) {
              _runsController.add(json);
            }
          } catch (_) {
            // ignore malformed
          }
        },
        onError: (error) {
          _isConnected = false;
          _statusController.add(false);
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _statusController.add(false);
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _isConnected = false;
      _statusController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    
    final delaySeconds = min(pow(2, _reconnectAttempts).toInt(), 30);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  @override
  void disconnect() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _runsController.close();
    _statusController.close();
  }
}
