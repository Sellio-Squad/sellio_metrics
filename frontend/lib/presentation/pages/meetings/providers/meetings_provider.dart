// Meetings Provider
//
// Single responsibility: manages meeting list + CRUD state.
// Real-time participant updates are handled by a separate MeetingWatchProvider.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';

@injectable
class MeetingsProvider extends ChangeNotifier {
  final MeetingsRepository _repository;

  MeetingsProvider(this._repository);

  // ─── State ───────────────────────────────────────────────────────────────

  List<MeetingEntity> _meetings = [];
  List<MeetingEntity> get meetings => _meetings;

  MeetingEntity? _selectedMeeting;
  MeetingEntity? get selectedMeeting => _selectedMeeting;

  List<ParticipantEntity> _participants = [];
  List<ParticipantEntity> get participants => _participants;

  List<RegularMeetingSchedule> _regularMeetings = [];
  List<RegularMeetingSchedule> get regularMeetings => _regularMeetings;

  bool _isLoading  = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  String? _error;
  String? get error => _error;

  String? _authUrl;
  String? get authUrl => _authUrl;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<void> checkAuthStatus() async {
    try {
      _isAuthenticated = await _repository.getAuthStatus();
      notifyListeners();
    } catch (_) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<void> login() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final url = await _repository.getAuthUrl();
      _authUrl = url;
    } catch (e) {
      _error = 'Failed to get sign-in URL: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.logout();
      _isAuthenticated = false;
      _meetings = [];
    } catch (e) {
      _error = 'Failed to sign out: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Load Meetings ────────────────────────────────────────────────────────

  Future<void> loadMeetings() async {
    _isLoading = true;
    _error = null;
    _authUrl = null;
    notifyListeners();

    try {
      await checkAuthStatus();
      if (_isAuthenticated) {
        _meetings = await _repository.getMeetings();
      }
      // Load schedule data from data layer
      _regularMeetings = await _repository.getRegularMeetings();
    } catch (e) {
      _error = 'Failed to load meetings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Create Meeting ───────────────────────────────────────────────────────

  Future<bool> createMeeting(String title) async {
    _isCreating = true;
    _error = null;
    _authUrl = null;
    notifyListeners();

    try {
      final created = await _repository.createMeeting(title);
      _meetings = [created, ..._meetings];
      _isCreating = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('AUTH_REQUIRED')) {
        final url = await _repository.getAuthUrl();
        _authUrl = url;
        _error   = 'Sign in with Google to create a meeting.';
      } else {
        _error = 'Failed to create meeting: $e';
      }
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Regular Meeting Schedule CRUD ──────────────────────────────────────────

  bool _isScheduleLoading = false;
  bool get isScheduleLoading => _isScheduleLoading;

  Future<bool> createRegularMeeting(RegularMeetingSchedule schedule) async {
    _isScheduleLoading = true;
    notifyListeners();
    try {
      final created = await _repository.createRegularMeeting(schedule);
      _regularMeetings = [..._regularMeetings, created];
      return true;
    } catch (e) {
      _error = 'Failed to create schedule: $e';
      return false;
    } finally {
      _isScheduleLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRegularMeeting(String id) async {
    _isScheduleLoading = true;
    notifyListeners();
    try {
      await _repository.deleteRegularMeeting(id);
      _regularMeetings = _regularMeetings.where((s) => s.id != id).toList();
      return true;
    } catch (e) {
      _error = 'Failed to delete schedule: $e';
      return false;
    } finally {
      _isScheduleLoading = false;
      notifyListeners();
    }
  }

  // ─── Select / Detail ──────────────────────────────────────────────────────

  Future<void> selectMeeting(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final detail = await _repository.getMeetingDetail(id);
      _selectedMeeting = detail.meeting;
      _participants    = detail.participants;
    } catch (e) {
      _error = 'Failed to load meeting details: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedMeeting = null;
    _participants    = [];
    notifyListeners();
  }

  // ─── End Meeting ──────────────────────────────────────────────────────────

  Future<bool> endMeeting(String meetingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.endMeeting(meetingId);
      _meetings.removeWhere((m) => m.id == meetingId);
      if (_selectedMeeting?.id == meetingId) clearSelection();
      return true;
    } catch (e) {
      _error = 'Failed to end meeting: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
