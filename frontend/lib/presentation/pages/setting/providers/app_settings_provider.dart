/// Presentation — AppSettingsProvider
///
/// Manages app-wide settings: theme, locale, and selected repositories.
/// Depends on [ReposRepository] (interface) for repo loading — NOT on
/// MetricsRepository or any concrete class.

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/repositories/repos_repository.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

@injectable
class AppSettingsProvider extends ChangeNotifier {
  final ReposRepository _repository;

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');
  List<RepoInfo> _selectedRepos = [];
  List<RepoInfo> _availableRepos = [];
  bool _isLoadingRepos = false;
  String? _errorRepoLoad;

  AppSettingsProvider(this._repository);

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  List<RepoInfo> get selectedRepos => _selectedRepos;
  List<RepoInfo> get availableRepos => _availableRepos;
  bool get isLoadingRepos => _isLoadingRepos;
  String? get errorRepoLoad => _errorRepoLoad;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

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

  Future<void> loadRepositories() async {
    _isLoadingRepos = true;
    _errorRepoLoad = null;
    notifyListeners();

    try {
      _availableRepos = await _repository.getRepositories();
      if (_selectedRepos.isEmpty && _availableRepos.isNotEmpty) {
        _selectedRepos = List.from(_availableRepos);
      }
    } catch (e, stack) {
      _errorRepoLoad = e.toString();
      appLogger.error('AppSettingsProvider', 'Error loading repos: $e', stack);
    }

    _isLoadingRepos = false;
    notifyListeners();
  }

  void toggleRepoSelection(RepoInfo repo) {
    if (_selectedRepos.any((r) => r.fullName == repo.fullName)) {
      _selectedRepos = _selectedRepos
          .where((r) => r.fullName != repo.fullName)
          .toList();
    } else {
      _selectedRepos = [..._selectedRepos, repo];
    }
    notifyListeners();
  }
}
