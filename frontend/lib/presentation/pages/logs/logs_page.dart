import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/domain/entities/log_entry_entity.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/logs/providers/logs_provider.dart';
import 'package:provider/provider.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  LogCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LogsProvider>().fetchLogs();
    });
  }

  List<LogEntry> _getFilteredLogs(List<LogEntry> logs) {
    if (_selectedCategory == null) return logs;
    return logs.where((log) => log.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final provider = context.watch<LogsProvider>();
    final filteredLogs = _getFilteredLogs(provider.logs);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Text(l10n.navLogs, style: context.textTheme.headlineSmall),
        backgroundColor: context.colors.surface,
        elevation: 0,
        actions: [
          if (provider.logs.isNotEmpty)
            IconButton(
              icon: Icon(LucideIcons.trash2, color: context.colors.semanticError),
              onPressed: () => provider.clearLogs(),
              tooltip: 'Clear Logs',
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(context),
          Expanded(
            child: provider.isLoading && provider.logs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? _buildErrorState(context, provider)
                    : filteredLogs.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            itemCount: filteredLogs.length,
                            itemBuilder: (context, index) {
                              final log = filteredLogs[index];
                              return _buildLogItem(context, log, isDesktop);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LogsProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 64, color: context.colors.errorVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Failed to fetch logs',
            style: context.textTheme.titleMedium?.copyWith(color: context.colors.title),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            provider.error ?? 'Unknown error',
            style: context.textTheme.bodyMedium?.copyWith(color: context.colors.semanticError),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => provider.fetchLogs(),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _buildFilterChip('All Events', null),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Frontend', LogCategory.frontend),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('GitHub & PRs', LogCategory.github),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('Google Meet', LogCategory.googleMeet),
          const SizedBox(width: AppSpacing.sm),
          _buildFilterChip('System & API', LogCategory.system),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, LogCategory? category) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedCategory = category);
        }
      },
      selectedColor: context.colors.primary,
      labelStyle: TextStyle(
        color: isSelected ? context.colors.onPrimary : context.colors.body,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: context.colors.surfaceHigh,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    );
  }

  Widget _buildLogItem(BuildContext context, LogEntry log, bool isDesktop) {
    final timeFormat = DateFormat('MMM dd, HH:mm:ss');
    final formattedTime = timeFormat.format(log.timestamp);
    
    final (IconData icon, Color iconColor, Color bgColor) = switch (log.severity) {
      LogSeverity.success => (
          LucideIcons.checkCircle2,
          context.colors.green,
          context.colors.greenSubtle
        ),
      LogSeverity.error => (
          LucideIcons.alertOctagon,
          SellioColors.red,
          context.colors.redSubtle
        ),
      LogSeverity.warning => (
          LucideIcons.alertTriangle,
          SellioColors.amber,
          SellioColors.amber.withValues(alpha: 0.15)
        ),
      LogSeverity.info => (
          LucideIcons.info,
          SellioColors.blue,
          SellioColors.blue.withValues(alpha: 0.15)
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.stroke),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: isDesktop 
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIconRef(icon, iconColor, bgColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.message,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.title,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatMetadata(log.metadata!),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.hint,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              formattedTime,
              style: context.textTheme.bodySmall?.copyWith(color: context.colors.hint),
            ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 _buildIconRef(icon, iconColor, bgColor),
                 const SizedBox(width: AppSpacing.sm),
                 Expanded(
                   child: Text(
                     formattedTime,
                     style: context.textTheme.bodySmall?.copyWith(color: context.colors.hint),
                   ),
                 ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              log.message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.title,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (log.metadata != null && log.metadata!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _formatMetadata(log.metadata!),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.hint,
                  fontFamily: 'monospace',
                ),
              ),
            ]
          ],
      ),
    );
  }

  Widget _buildIconRef(IconData icon, Color iconColor, Color bgColor) {
      return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: iconColor),
      );
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    return metadata.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.fileText, size: 64, color: context.colors.body),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No logs available',
            style: context.textTheme.titleMedium?.copyWith(color: context.colors.body),
          ),
        ],
      ),
    );
  }
}
