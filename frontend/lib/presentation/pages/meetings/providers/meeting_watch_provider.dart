import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

class MeetingWatchProvider extends ChangeNotifier {
  final MeetingsRepository _repository;
  final String meetingId;

  bool _isInitialized = false;

  MeetingWatchProvider({
    required MeetingsRepository repository,
    required this.meetingId,
  }) : _repository = repository {
    _connect();
  }
  void _updateFromRestData(List<ParticipantEntity> participants) {
    _active = participants.where((p) => p.endTime == null).toList();
    _history = List.from(participants);
    notifyListeners();
  }

  /// Called when the REST API has finished fetching the meeting details initially
  void initializeWithRestData(List<ParticipantEntity> participants) {
    if (_isInitialized) return;
    _updateFromRestData(participants);
    _isInitialized = true;
  }

  // ─── State ────────────────────────────────────────────────────────────────

  /// Active participants currently in the meeting.
  List<ParticipantEntity> _active = [];
  List<ParticipantEntity> get active => _active;

  /// All participants (including those who left).
  List<ParticipantEntity> _history = [];
  List<ParticipantEntity> get history => _history;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _meetingEnded = false;
  bool get meetingEnded => _meetingEnded;

  String? _error;
  String? get error => _error;

  StreamSubscription<MeetingWsEvent>? _subscription;

  // ─── Connection ───────────────────────────────────────────────────────────

  void _connect() {
    _subscription = _repository.watchMeeting(meetingId).listen(
          (event) {
        _isConnected = true;
        _error = null;
        _handleEvent(event);
        notifyListeners();
      },
      onError: (err) {
        appLogger.error('MeetingWatchProvider', 'WebSocket error: $err');
        _isConnected = false;
        _error = 'Connection lost — reconnecting…';
        notifyListeners();
        // Auto-reconnect after 2s
        Future.delayed(const Duration(seconds: 2), () {
          if (!_meetingEnded) _reconnect();
        });
      },
      onDone: () {
        _isConnected = false;
        notifyListeners();
      },
    );
  }

  void _reconnect() {
    _subscription?.cancel();
    _connect();
  }

  // ─── Event Handling ───────────────────────────────────────────────────────

  void _handleEvent(MeetingWsEvent event) {
    switch (event.type) {
      case MeetingWsEventType.participantJoined:
        if (event.participantKey == null) return;
        final participant = ParticipantEntity(
          participantKey:       event.participantKey!,
          displayName:          event.displayName ?? 'Unknown',
          startTime:            event.timestamp,
          totalDurationMinutes: 0,
        );
        // Add to active (and history)
        _active.removeWhere((p) => p.participantKey == event.participantKey);
        _active.add(participant);
        if (!_history.any((p) => p.participantKey == event.participantKey && p.endTime == null)) {
          _history.add(participant);
        }

      case MeetingWsEventType.participantLeft:
        if (event.participantKey == null) return;
        final duration = _calcDuration(event.participantKey!, event.timestamp);
        // Move from active → ended in history
        _active.removeWhere((p) => p.participantKey == event.participantKey);
        _history = _history.map((p) {
          if (p.participantKey == event.participantKey && p.endTime == null) {
            return ParticipantEntity(
              participantKey:       p.participantKey,
              displayName:          p.displayName,
              startTime:            p.startTime,
              endTime:              event.timestamp,
              totalDurationMinutes: duration,
            );
          }
          return p;
        }).toList();

      case MeetingWsEventType.meetingEnded:
        _active = [];
        _meetingEnded = true;
        _isConnected   = false;
    }
  }

  int _calcDuration(String participantKey, DateTime endTime) {
    final entry = _active.where((p) => p.participantKey == participantKey).firstOrNull;
    if (entry == null) return 0;
    return endTime.difference(entry.startTime).inMinutes.clamp(0, 9999);
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _subscription?.cancel();
    _repository.unwatchMeeting(meetingId);
    super.dispose();
  }
}
