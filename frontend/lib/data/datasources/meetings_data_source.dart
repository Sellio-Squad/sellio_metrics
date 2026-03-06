/// Meetings Data Source — Abstract Interface + Remote Implementation
///
/// Handles HTTP communication with the backend meetings API.
/// Completely separate from MetricsDataSource (Single Responsibility).
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─── Abstract Interface ─────────────────────────────────────

abstract class MeetingsDataSource {
  Future<Map<String, dynamic>> createMeeting(String title);

  Future<List<Map<String, dynamic>>> fetchMeetings();

  Future<Map<String, dynamic>> fetchMeetingDetail(String id);

  Future<Map<String, dynamic>> fetchAttendance(String meetingId);

  Future<Map<String, dynamic>> fetchAnalytics();

  Future<Map<String, dynamic>> fetchRateLimitStatus();
}

class AuthRequiredException implements Exception {
  final String authUrl;
  final String message;

  AuthRequiredException(this.authUrl, this.message);

  @override
  String toString() => message;
}

// ─── Remote Implementation ──────────────────────────────────

class RemoteMeetingsDataSource implements MeetingsDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteMeetingsDataSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> createMeeting(String title) async {
    final url = Uri.parse('$baseUrl/api/meetings');
    debugPrint('[MeetingsDataSource] POST $url');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'title': title}),
    );

    if (response.statusCode == 401) {
      final body = json.decode(response.body);
      if (body['authUrl'] != null) {
        throw AuthRequiredException(body['authUrl'], body['message'] ?? 'Authentication required');
      }
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create meeting: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMeetings() async {
    final url = Uri.parse('$baseUrl/api/meetings');
    debugPrint('[MeetingsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch meetings: ${response.statusCode} ${response.body}',
      );
    }

    final List<dynamic> list = json.decode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    final url = Uri.parse('$baseUrl/api/meetings/$id');
    debugPrint('[MeetingsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch meeting detail: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchAttendance(String meetingId) async {
    final url = Uri.parse('$baseUrl/api/meetings/$meetingId/attendance');
    debugPrint('[MeetingsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch attendance: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchAnalytics() async {
    final url = Uri.parse('$baseUrl/api/meetings/analytics');
    debugPrint('[MeetingsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch analytics: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchRateLimitStatus() async {
    final url = Uri.parse('$baseUrl/api/meetings/rate-limit');
    debugPrint('[MeetingsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rate limit: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }
}
