/// Meetings Provider — ChangeNotifier for meeting state management.
///
/// Manages meetings list, selected meeting details, attendance data,
/// analytics, rate limit status, and loading/error states.
library;

import 'package:flutter/material.dart';
import '../../domain/entities/meeting_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../../domain/entities/attendance_analytics_entity.dart';
import '../../domain/repositories/meetings_repository.dart';

class MeetingsProvider extends ChangeNotifier {
  final MeetingsRepository _repository;

  MeetingsProvider({required MeetingsRepository repository})
    : _repository = repository;

  // ─── State ──────────────────────────────────────────────

  List<MeetingEntity> _meetings = [];
  List<MeetingEntity> get meetings => _meetings;

  MeetingEntity? _selectedMeeting;
  MeetingEntity? get selectedMeeting => _selectedMeeting;

  List<ParticipantEntity> _participants = [];
  List<ParticipantEntity> get participants => _participants;

  AttendanceResult? _attendance;
  AttendanceResult? get attendance => _attendance;

  AttendanceAnalyticsEntity _analytics = AttendanceAnalyticsEntity.empty;
  AttendanceAnalyticsEntity get analytics => _analytics;

  RateLimitEntity _rateLimit = RateLimitEntity.empty;
  RateLimitEntity get rateLimit => _rateLimit;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCreating = false;
  bool get isCreating => _isCreating;

  String? _error;
  String? get error => _error;

  String? _authUrl;
  String? get authUrl => _authUrl;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  // ─── Tab Index ────────────────────────────────────────────

  int _tabIndex = 0;
  int get tabIndex => _tabIndex;

  void setTabIndex(int index) {
    _tabIndex = index;
    notifyListeners();
  }

  // ─── Load Meetings ────────────────────────────────────────

  Future<void> loadMeetings() async {
    _isLoading = true;
    _error = null;
    _authUrl = null;
    notifyListeners();

    try {
      await checkAuthStatus();
      if (_isAuthenticated) {
        _meetings = await _repository.getMeetings();
        _loadRateLimit();
      }
    } catch (e) {
      _error = 'Failed to load meetings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Create Meeting ───────────────────────────────────────

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
      if (e.toString().contains('AuthRequiredException') ||
          e.toString().contains('authUrl')) {
        // Poor man's type check since AuthRequiredException is deep in data layer
        // Better: Export AuthRequiredException from core/error or check type properly
      }
      _error = 'Failed to create meeting: $e';

      // If the error object literally contains the URL, we parse it,
      // But actually, we should just import it. Let's make it clean:
      if (e.runtimeType.toString() == 'AuthRequiredException') {
        dynamic authErr = e;
        try {
          _authUrl = authErr.authUrl;
          _error = authErr.message;
        } catch (_) {}
      }

      _isCreating = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Select Meeting ───────────────────────────────────────

  Future<void> selectMeeting(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final detail = await _repository.getMeetingDetail(id);
      _selectedMeeting = detail.meeting;
      _participants = detail.participants;
    } catch (e) {
      _error = 'Failed to load meeting details: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelection() {
    _selectedMeeting = null;
    _participants = [];
    notifyListeners();
  }

  // ─── Attendance ───────────────────────────────────────────

  Future<void> loadAttendance(String meetingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _attendance = await _repository.getAttendance(meetingId);
    } catch (e) {
      _error = 'Failed to load attendance: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Analytics ────────────────────────────────────────────

  Future<void> loadAnalytics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _analytics = await _repository.getAnalytics();
    } catch (e) {
      _error = 'Failed to load analytics: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Rate Limit ───────────────────────────────────────────

  Future<void> _loadRateLimit() async {
    try {
      _rateLimit = await _repository.getRateLimitStatus();
      notifyListeners();
    } catch (_) {
      // Silently fail — rate limit is informational
    }
  }

  // ─── Auth ───────────────────────────────────────────

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
      if (url != null) {
        _authUrl = url;
      } else {
        _error = 'Failed to get sign-in URL from backend.';
      }
    } catch (e) {
      _error = 'Failed to prepare login: $e';
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

  // ─── End Meeting ────────────────────────────────────

  Future<bool> endMeeting(String meetingId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.endMeeting(meetingId);
      // Remove the meeting locally or refresh
      _meetings.removeWhere((m) => m.id == meetingId);
      if (_selectedMeeting?.id == meetingId) {
        clearSelection();
      }
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
