import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/ai_chat/ai_chat_data_source.dart';
import 'package:sellio_metrics/domain/entities/chat_message_entity.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';

@injectable
class AiChatProvider extends ChangeNotifier {
  final AiChatDataSource _dataSource;

  bool _isLoading = false;
  String? _error;
  List<ChatMessageEntity> _messages = [];
  String? _sessionId;
  RepoInfo? _selectedRepo;
  List<RepoInfo> _availableRepos = [];

  AiChatProvider(this._dataSource) {
    _loadRepos();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ChatMessageEntity> get messages => _messages;
  RepoInfo? get selectedRepo => _selectedRepo;
  List<RepoInfo> get availableRepos => _availableRepos;

  Future<void> _loadRepos() async {
    try {
      _availableRepos = await _dataSource.getAvailableRepos();
      if (_availableRepos.isNotEmpty && _selectedRepo == null) {
        _selectedRepo = _availableRepos.first;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void selectRepo(RepoInfo repo) {
    if (_selectedRepo?.fullName == repo.fullName) return;
    _selectedRepo = repo;
    _messages = [];
    _sessionId = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _selectedRepo == null) return;

    final repoParts = _selectedRepo!.fullName.split('/');
    if (repoParts.length != 2) return;

    final userMessage = ChatMessageEntity(
      role: MessageRole.user,
      content: text,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dataSource.sendMessage(
        owner: repoParts[0],
        repo: repoParts[1],
        message: text,
        sessionId: _sessionId,
      );

      _sessionId = response.sessionId;

      final botMessage = ChatMessageEntity(
        role: MessageRole.assistant,
        content: response.message,
        timestamp: DateTime.now(),
        toolCallsMade: response.toolCallsMade,
      );

      _messages.add(botMessage);
    } catch (e) {
      _error = 'Failed to send message: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearChat() async {
    if (_sessionId != null) {
      try {
        await _dataSource.clearSession(_sessionId!);
      } catch (_) {}
    }
    _messages = [];
    _sessionId = null;
    _error = null;
    notifyListeners();
  }
}
