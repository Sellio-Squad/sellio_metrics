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

  String _selectedRepoFullName = '';
  String _selectedRepoName = '';
  String _selectedOwner = '';

  List<RepoInfo> _availableRepos = [];
  bool _isLoadingRepos = false;

  AppSettingsProvider({required MetricsRepository repository})
      : _repository = repository;

  // ─── Getters ─────────────────────────────────────────────
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  String get selectedRepoFullName => _selectedRepoFullName;
  String get selectedRepoName => _selectedRepoName;
  String get selectedOwner => _selectedOwner;
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
      if (_selectedRepoFullName.isEmpty && _availableRepos.isNotEmpty) {
        _setRepo(_availableRepos.first);
      }
    } catch (e) {
      debugPrint('Error loading repositories: $e');
    }

    _isLoadingRepos = false;
    notifyListeners();
  }

  /// Change the selected repository.
  void setSelectedRepo(RepoInfo repo) {
    _setRepo(repo);
    notifyListeners();
  }

  void _setRepo(RepoInfo repo) {
    _selectedRepoFullName = repo.fullName;
    _selectedRepoName = repo.name;
    // Extract owner from "owner/repo" format
    final parts = repo.fullName.split('/');
    _selectedOwner = parts.isNotEmpty ? parts.first : '';
  }
}
