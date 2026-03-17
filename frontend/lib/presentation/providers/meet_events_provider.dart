/// Meet Events Provider — ChangeNotifier for real-time event streaming.
///
/// Manages SSE connection lifecycle, event list state, and subscriptions.
/// Uses dart:html EventSource via the data layer for real-time updates.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/meet_event_entity.dart';
import '../../domain/repositories/meet_events_repository.dart';
import '../../core/logging/app_logger.dart';

@injectable
class MeetEventsProvider extends ChangeNotifier {
  final MeetEventsRepository _repository;

  MeetEventsProvider(this._repository);

  // ─── State ──────────────────────────────────────────────

  List<MeetEventEntity> _events = [];
  List<MeetEventEntity> get events => _events;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubscribing = false;
  bool get isSubscribing => _isSubscribing;

  String? _error;
  String? get error => _error;

  String? _lastEventId;

  StreamSubscription<MeetEventEntity>? _streamSubscription;

  // ─── Load Events (REST fallback) ──────────────────────────

  Future<void> loadEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _repository.getEvents(limit: 100);
      if (_events.isNotEmpty) {
        _lastEventId = _events.first.id;
      }
    } catch (e) {
      _error = 'Failed to load events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── SSE Stream ──────────────────────────────────────────

  void startStreaming() {
    if (_isStreaming) return;

    _isStreaming = true;
    _error = null;
    notifyListeners();

    final stream = _repository.connectStream(lastEventId: _lastEventId);

    _streamSubscription = stream.listen(
      (event) {
        // Deduplicate: don't add if we already have this event
        if (_events.any((e) => e.id == event.id)) return;

        _events.insert(0, event);
        _lastEventId = event.id;

        // Cap list at 200 entries
        if (_events.length > 200) {
          _events = _events.sublist(0, 200);
        }

        notifyListeners();
      },
      onError: (error, stack) {
        appLogger.error('MeetEventsProvider', 'SSE error: $error', stack);
        // EventSource auto-reconnects, so we don't need to handle this
      },
      onDone: () {
        appLogger.info('MeetEventsProvider', 'SSE stream closed — will reconnect');
        _isStreaming = false;
        notifyListeners();
        // Auto-reconnect after a brief delay
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isStreaming) {
            startStreaming();
          }
        });
      },
    );
  }

  void stopStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _repository.disconnectStream();
    _isStreaming = false;
    notifyListeners();
  }

  // ─── Subscribe to a Space ────────────────────────────────

  Future<bool> subscribeToSpace(String spaceName) async {
    _isSubscribing = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.subscribe(spaceName);
      _isSubscribing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to subscribe: $e';
      _isSubscribing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Clear ────────────────────────────────────────────────

  void clearEvents() {
    _events = [];
    _lastEventId = null;
    notifyListeners();
  }

  // ─── Cleanup ──────────────────────────────────────────────

  @override
  void dispose() {
    stopStreaming();
    super.dispose();
  }
}
