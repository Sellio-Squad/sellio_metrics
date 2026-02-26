/// Sellio Metrics — App Settings Provider
///
/// Manages theme mode, locale, and selected repository.
library;

import 'package:flutter/material.dart';
import '../../domain/repositories/metrics_repository.dart';

class AppSettingsProvider extends ChangeNotifier {
  final MetricsRepository _repository;

  ThemeMode _themeMode = ThemeMode.dark;
  Locale _locale = const Locale('en');

  List<RepoInfo> _selectedRepos = [];

  List<RepoInfo> _availableRepos = [];
  bool _isLoadingRepos = false;

  AppSettingsProvider({required MetricsRepository repository})
      : _repository = repository;

  // ─── Getters ─────────────────────────────────────────────
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  List<RepoInfo> get selectedRepos => _selectedRepos;
  List<RepoInfo> get availableRepos => _availableRepos;
  bool get isLoadingRepos => _isLoadingRepos;

  // ─── Theme ───────────────────────────────────────────────
  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // ─── Locale ──────────────────────────────────────────────
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
    notifyListeners();
  }

  // ─── Repository Selection ────────────────────────────────
  /// Load the list of available repositories from the backend.
  Future<void> loadRepositories() async {
    _isLoadingRepos = true;
    notifyListeners();

    try {
      _availableRepos = await _repository.getRepositories();

      // Auto-select the first repo if none selected
      if (_selectedRepos.isEmpty && _availableRepos.isNotEmpty) {
        _selectedRepos = [_availableRepos.first];
      }
    } catch (e) {
      debugPrint('Error loading repositories: $e');
    }

    _isLoadingRepos = false;
    notifyListeners();
  }

  /// Toggle a repository selection.
  void toggleRepoSelection(RepoInfo repo) {
    if (_selectedRepos.any((r) => r.fullName == repo.fullName)) {
      _selectedRepos = _selectedRepos.where((r) => r.fullName != repo.fullName).toList();
    } else {
      _selectedRepos = [..._selectedRepos, repo];
    }
    notifyListeners();
  }
}
