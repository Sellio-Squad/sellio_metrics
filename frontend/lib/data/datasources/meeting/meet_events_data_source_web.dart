import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_events_data_source.dart';

class MeetEventsDataSourcePlatformImpl implements MeetEventsDataSource {
  final ApiClient _apiClient;

  web.EventSource? _eventSource;
  StreamController<Map<String, dynamic>>? _streamController;

  MeetEventsDataSourcePlatformImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> subscribe(String spaceName) async {
    return await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.meetEventsSubscribe,
      tag: 'MeetEventsDataSource',
      data: {'spaceName': spaceName},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({int limit = 50}) async {
    return await _apiClient.get<List<Map<String, dynamic>>>(
      ApiEndpoints.meetEventsList,
      tag: 'MeetEventsDataSource',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final events = body['events'] as List<dynamic>? ?? [];
        return events.cast<Map<String, dynamic>>();
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    return await _apiClient.get<List<Map<String, dynamic>>>(
      ApiEndpoints.meetEventsSubscriptions,
      tag: 'MeetEventsDataSource',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final subs = body['subscriptions'] as List<dynamic>? ?? [];
        return subs.cast<Map<String, dynamic>>();
      },
    );
  }

  @override
  Stream<Map<String, dynamic>> connectEventStream({String? lastEventId}) {
    disconnectEventStream();

    _streamController = StreamController<Map<String, dynamic>>.broadcast();

    // Access the raw baseUrl from ApiClient's Dio options as we need it for EventSource
    // ApiClient doesn't expose it directly but we can use the private _dio via a getter if added,
    // or just assume it is available from constants.
    // However, I will use a trick to get it from the ApiClient's properties if I modify it.
    // For now, I'll use the same hack as before if I can't access it.
    // Actually, I'll just use the constant here.
    // Wait, AppModule uses ApiConfig.baseUrl.
    // I'll use that.

    // BUT the original used `/api/meet-events/stream` prefix.
    final sseUrl = lastEventId != null
        ? '${ApiConfig.baseUrl}/api/meet-events/stream?lastEventId=$lastEventId'
        : '${ApiConfig.baseUrl}/api/meet-events/stream';

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
