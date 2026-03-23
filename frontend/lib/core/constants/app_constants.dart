
import 'package:intl/intl.dart';

class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  static const bool useFakeData = bool.fromEnvironment(
    'USE_FAKE_DATA',
    defaultValue: false,
  );

  static const String defaultOrg = 'Sellio-Squad';
  static const String defaultRepo = 'sellio_mobile';
}

class BottleneckConfig {
  const BottleneckConfig._();

  static const double defaultThresholdHours = 48;
  static const int maxDisplayCount = 10;
  static const double severityHighMultiplier = 3.0;
  static const double severityMediumMultiplier = 1.5;
}

class PrTypePatterns {
  const PrTypePatterns._();

  static final Map<String, RegExp> patterns = {
    'feature': RegExp(r'feat(ure)?[:\/(]', caseSensitive: false),
    'fix': RegExp(r'fix[:\/(]|bug', caseSensitive: false),
    'refactor': RegExp(r'refactor[:\/(]', caseSensitive: false),
    'chore': RegExp(r'chore[:\/(]', caseSensitive: false),
    'docs': RegExp(r'docs?[:\/(]', caseSensitive: false),
    'ci': RegExp(r'ci[:\/(]', caseSensitive: false),
    'test': RegExp(r'test[:\/(]', caseSensitive: false),
    'style': RegExp(r'style[:\/(]', caseSensitive: false),
  };
}

class StorageKeys {
  const StorageKeys._();

  static const String theme = 'sellio_theme';
  static const String settings = 'sellio_settings';
  static const String filters = 'sellio_filters';
}

class PrStatus {
  const PrStatus._();

  static const String merged = 'merged';
  static const String closed = 'closed';
  static const String pending = 'pending';
  static const String approved = 'approved';
}

class FilterOptions {
  const FilterOptions._();

  static const String all = 'all';
}


class DateFormats {
  const DateFormats._();

  static final full = DateFormat('MMM d, yyyy');
  static final short = DateFormat('MMM d');
  static final iso = DateFormat('yyyy-MM-dd');
}
