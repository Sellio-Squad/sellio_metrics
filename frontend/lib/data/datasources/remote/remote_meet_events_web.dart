import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:dio/dio.dart';
import '../../../core/logging/app_logger.dart';
import '../meet_events_data_source.dart';

class RemoteMeetEventsDataSourceImpl implements MeetEventsDataSource {
  final Dio _dio;

  web.EventSource? _eventSource;
  StreamController<Map<String, dynamic>>? _streamController;

  RemoteMeetEventsDataSourceImpl(this._dio);

  @override
  Future<Map<String, dynamic>> subscribe(String spaceName) async {
    final url = '/api/meet-events/subscribe';
    appLogger.network('MeetEventsDataSource', 'POST', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.post(
      url,
      data: {'spaceName': spaceName},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to subscribe: ${response.statusCode} ${response.data}',
      );
    }

    return response.data as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({int limit = 50}) async {
    final url = '/api/meet-events/events?limit=$limit';
    appLogger.network('MeetEventsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch events: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data as Map<String, dynamic>;
    final events = body['events'] as List<dynamic>? ?? [];
    return events.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    final url = '/api/meet-events/subscriptions';
    appLogger.network('MeetEventsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch subscriptions: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data as Map<String, dynamic>;
    final subs = body['subscriptions'] as List<dynamic>? ?? [];
    return subs.cast<Map<String, dynamic>>();
  }

  @override
  Stream<Map<String, dynamic>> connectEventStream({String? lastEventId}) {
    disconnectEventStream();

    _streamController = StreamController<Map<String, dynamic>>.broadcast();

    final sseUrl = lastEventId != null
        ? '${_dio.options.baseUrl}/api/meet-events/stream?lastEventId=$lastEventId'
        : '${_dio.options.baseUrl}/api/meet-events/stream';

    appLogger.network('MeetEventsDataSource', 'SSE-CONNECT', Uri.parse(sseUrl));

    _eventSource = web.EventSource(sseUrl);

    _eventSource!.addEventListener(
      'meet-event',
      ((web.Event event) {
        final messageEvent = event as web.MessageEvent;
        try {
          final dataStr = (messageEvent.data as JSString).toDart;
          final data = json.decode(dataStr) as Map<String, dynamic>;
          _streamController?.add(data);
        } catch (e, stack) {
          appLogger.error('MeetEventsDataSource', 'SSE parse error: $e', stack);
        }
      }).toJS,
    );

    _eventSource!.onOpen.listen((_) {
      appLogger.info('MeetEventsDataSource', 'SSE connected');
    });

    _eventSource!.onError.listen((event) {
      appLogger.info('MeetEventsDataSource', 'SSE error — will auto-reconnect');
    });

    return _streamController!.stream;
  }

  @override
  void disconnectEventStream() {
    _eventSource?.close();
    _eventSource = null;
    _streamController?.close();
    _streamController = null;
  }
}
