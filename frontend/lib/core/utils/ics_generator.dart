/// Sellio Metrics — ICS Calendar Generator
///
/// Pure Dart utility to generate RFC 5545 compliant `.ics` content.
library;

import 'package:intl/intl.dart';

class IcsGenerator {
  /// Returns an ICS file content string for an event.
  static String generate({
    required String title,
    required String description,
    required DateTime startTime,
    required Duration duration,
    String? location,
    String? recurrenceRule,
  }) {
    final endTime = startTime.add(duration);
    final now = DateTime.now().toUtc();
    final tz = startTime.timeZoneName;

    // Use a clean custom format for ICS dates (YYYYMMDDTHHMMSS)
    final format = DateFormat("yyyyMMdd'T'HHmmss");
    final dtStart = '${format.format(startTime.toUtc())}Z';
    final dtEnd = '${format.format(endTime.toUtc())}Z';
    final dtStamp = '${format.format(now)}Z';

    // Unique ID for the event based on timestamp and name
    final uid = '${now.millisecondsSinceEpoch}-${title.replaceAll(' ', '')}@sellio.sqaud';

    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Sellio Squad//Metrics Dashboard//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:$uid');
    buffer.writeln('DTSTAMP:$dtStamp');
    buffer.writeln('DTSTART:$dtStart');
    buffer.writeln('DTEND:$dtEnd');
    buffer.writeln('SUMMARY:$title');
    buffer.writeln('DESCRIPTION:${_escapeText(description)}');

    if (location != null) {
      buffer.writeln('LOCATION:${_escapeText(location)}');
    }
    
    if (recurrenceRule != null) {
      buffer.writeln('RRULE:$recurrenceRule');
    }

    buffer.writeln('END:VEVENT');
    buffer.writeln('END:VCALENDAR');

    return buffer.toString();
  }

  /// Escapes special characters for ICS format
  static String _escapeText(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }
}
