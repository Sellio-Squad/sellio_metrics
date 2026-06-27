import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/chat_message_entity.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/presentation/pages/ai_chat/providers/ai_chat_provider.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    context.read<AiChatProvider>().sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final provider = context.watch<AiChatProvider>();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.stroke)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.bot, color: scheme.primary),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Sellio Bot',
                style: AppTypography.title.copyWith(color: scheme.title),
              ),
              const Spacer(),
              if (provider.availableRepos.isNotEmpty)
                _buildRepoSelector(context, provider),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                icon: Icon(LucideIcons.trash2, color: scheme.hint),
                tooltip: 'Clear Chat',
                onPressed: provider.messages.isEmpty
                    ? null
                    : () {
                        provider.clearChat();
                      },
              ),
            ],
          ),
        ),

        // Chat List
        Expanded(
          child: provider.messages.isEmpty
              ? _buildEmptyState(context, provider)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: provider.messages.length + (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.messages.length) {
                      return _buildTypingIndicator(context);
                    }
                    return _buildMessage(context, provider.messages[index]);
                  },
                ),
        ),

        // Error message if any
        if (provider.error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: scheme.red.withOpacity(0.1),
            width: double.infinity,
            child: Text(
              provider.error!,
              style: AppTypography.caption.copyWith(color: scheme.red),
              textAlign: TextAlign.center,
            ),
          ),

        // Input Area
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.stroke)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !provider.isLoading,
                  onSubmitted: _handleSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Ask anything about your repo or give me a task...',
                    filled: true,
                    fillColor: scheme.surfaceLow,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: scheme.stroke),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SButton(
                variant: SButtonVariant.primary,
                onPressed: provider.isLoading
                    ? null
                    : () => _handleSubmitted(_textController.text),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else ...[
                      const Icon(LucideIcons.send, size: 16),
                      const SizedBox(width: AppSpacing.xs),
                      const Text('Send'),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRepoSelector(BuildContext context, AiChatProvider provider) {
    return const _AiChatRepoDropdown();
  }

  Widget _buildEmptyState(BuildContext context, AiChatProvider provider) {
    final scheme = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.messageSquareCode, size: 64, color: scheme.stroke),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'How can I help you today?',
            style: AppTypography.headline.copyWith(color: scheme.title),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Explain the architecture'),
              _buildSuggestionChip('List open tickets'),
              _buildSuggestionChip('Create 3 auth tickets'),
              _buildSuggestionChip('Review PR #42'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _textController.text = text;
        _handleSubmitted(text);
      },
    );
  }

  Widget _buildMessage(BuildContext context, ChatMessageEntity message) {
    final isUser = message.role == MessageRole.user;
    final scheme = context.colors;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary.withOpacity(0.1) : scheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12).copyWith(
            bottomRight: isUser ? Radius.zero : const Radius.circular(12),
            bottomLeft: !isUser ? Radius.zero : const Radius.circular(12),
          ),
          border: Border.all(
            color: isUser ? scheme.primary.withOpacity(0.2) : scheme.stroke,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? LucideIcons.user : LucideIcons.bot,
                  size: 16,
                  color: scheme.hint,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isUser ? 'You' : 'Sellio Bot',
                  style: AppTypography.subtitle.copyWith(color: scheme.hint),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: AppTypography.body.copyWith(color: scheme.title),
                code: AppTypography.caption.copyWith(
                  backgroundColor: scheme.surfaceLow,
                ),
                codeblockDecoration: BoxDecoration(
                  color: scheme.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.stroke),
                ),
              ),
            ),
            if (message.toolCallsMade.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _buildToolCalls(context, message.toolCallsMade),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildToolCalls(BuildContext context, List<ToolCallRecord> toolCalls) {
    final scheme = context.colors;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          '🔧 Actions taken (${toolCalls.length})',
          style: AppTypography.subtitle.copyWith(color: scheme.hint),
        ),
        childrenPadding: EdgeInsets.zero,
        tilePadding: EdgeInsets.zero,
        children: toolCalls.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: AppSpacing.lg),
          child: Row(
            children: [
              Icon(LucideIcons.checkCircle, size: 14, color: scheme.green),
              const SizedBox(width: AppSpacing.sm),
              Text(
                t.name,
                style: AppTypography.caption.copyWith(
                  color: scheme.hint,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final scheme = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12).copyWith(
            bottomLeft: Radius.zero,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('Thinking...', style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

// ─── AI Chat Repo Dropdown ───────────────────────────────────────────────────

class _AiChatRepoDropdown extends StatefulWidget {
  const _AiChatRepoDropdown();

  @override
  State<_AiChatRepoDropdown> createState() => _AiChatRepoDropdownState();
}

class _AiChatRepoDropdownState extends State<_AiChatRepoDropdown> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  void _open(BuildContext context) {
    if (_overlay != null) {
      _close();
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final provider = context.read<AiChatProvider>();

    _overlay = OverlayEntry(
      builder: (_) => ChangeNotifierProvider<AiChatProvider>.value(
        value: provider,
        child: _AiChatRepoDropdownOverlay(
          layerLink: _layerLink,
          anchorSize: size,
          onClose: _close,
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final provider = context.watch<AiChatProvider>();
    final label = provider.selectedRepo?.name ?? 'All Repos';

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          _open(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceHigh,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: scheme.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.gitBranch, size: 14, color: scheme.hint),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: scheme.title,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.chevronDown, size: 14, color: scheme.hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiChatRepoDropdownOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final Size anchorSize;
  final VoidCallback onClose;

  const _AiChatRepoDropdownOverlay({
    required this.layerLink,
    required this.anchorSize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          offset: Offset(0, anchorSize.height + 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Consumer<AiChatProvider>(
              builder: (context, provider, _) {
                final scheme = context.colors;
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 240,
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: scheme.stroke),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs,
                          ),
                          child: Text(
                            'Filter by Repo',
                            style: AppTypography.caption.copyWith(
                              color: scheme.hint,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Divider(color: scheme.stroke, height: 1),
                        if (provider.availableRepos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'No synced repos found',
                              style: AppTypography.caption.copyWith(color: scheme.hint),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: provider.availableRepos
                                    .map((repo) => _AiChatRepoCheckboxTile(
                                          repo: repo,
                                          onClose: onClose,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AiChatRepoCheckboxTile extends StatelessWidget {
  final RepoInfo repo;
  final VoidCallback onClose;
  const _AiChatRepoCheckboxTile({required this.repo, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        final selected = provider.selectedRepo?.id == repo.id;
        return InkWell(
          onTap: () {
            provider.selectRepo(repo);
            onClose();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.stroke,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 11, color: scheme.onPrimary)
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repo.name,
                        style: AppTypography.body.copyWith(
                          color: scheme.title,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${repo.id}',
                        style: AppTypography.caption.copyWith(
                          color: scheme.hint,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
