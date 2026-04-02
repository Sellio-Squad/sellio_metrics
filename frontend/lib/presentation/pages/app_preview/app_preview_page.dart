import 'dart:convert';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

// ─── Model ────────────────────────────────────────────────────

class _AppInfo {
  final String name;
  final String label;
  final String emoji;
  final String publicKey;
  final String embedUrl;

  const _AppInfo({
    required this.name,
    required this.label,
    required this.emoji,
    required this.publicKey,
    required this.embedUrl,
  });
}

// ─── View-factory registry guard ──────────────────────────────
// platformViewRegistry.registerViewFactory panics if called twice with
// the same viewId. We track registered IDs process-wide.
final Set<String> _registeredViewIds = {};

// ─── Page ─────────────────────────────────────────────────────

class AppPreviewPage extends StatefulWidget {
  const AppPreviewPage({super.key});

  @override
  State<AppPreviewPage> createState() => _AppPreviewPageState();
}

class _AppPreviewPageState extends State<AppPreviewPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  String? _error;
  List<_AppInfo> _apps = [];

  // Single API call to api.github.com (CORS: *). JSON is embedded in release body.
  static const _releaseApiUrl =
      'https://api.github.com/repos/Sellio-Squad/sellio_mobile/releases/tags/preview-keys';

  static const _appOrder = ['customer', 'seller', 'admin'];
  static const _appMeta = {
    'customer': ('Customer', '🛒'),
    'seller': ('Seller', '🏪'),
    'admin': ('Admin', '⚙️'),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadKeys();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Single CORS-safe call — api.github.com always returns CORS: *.
      // The JSON payload is stored directly in the release body.
      final res = await http.get(
        Uri.parse(_releaseApiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (releaseRes.statusCode != 200) {
        throw Exception(
          'HTTP ${res.statusCode} — release not found.\n\n'
          'Merge a PR to develop to trigger the CD pipeline\n'
          'and generate the Appetize keys.',
        );
      }

      final releaseData = jsonDecode(res.body) as Map<String, dynamic>;
      // The CI embeds the full preview-keys JSON in the release body field.
      final body = releaseData['body'] as String? ?? '';
      if (body.isEmpty) {
        throw Exception('Release body is empty — re-run the CD workflow.');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final appsData = data['apps'] as Map<String, dynamic>;

      final apps = <_AppInfo>[];
      for (final name in _appOrder) {
        final d = appsData[name] as Map<String, dynamic>?;
        if (d == null) continue;
        final meta = _appMeta[name]!;
        apps.add(_AppInfo(
          name: name,
          label: meta.$1,
          emoji: meta.$2,
          publicKey: d['publicKey'] as String? ?? '',
          embedUrl: d['embedUrl'] as String? ?? '',
        ));
      }

      setState(() {
        _isLoading = false;
        _apps = apps;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          _AppPreviewHeader(onRefresh: _loadKeys),
          if (_isLoading)
            Expanded(child: Center(child: SLoading()))
          else if (_error != null)
            Expanded(child: _StateView.error(message: _error!, onRetry: _loadKeys))
          else if (_apps.isEmpty)
            Expanded(child: _StateView.empty(onRefresh: _loadKeys))
          else
            Expanded(
              child: Column(
                children: [
                  _AppTabBar(apps: _apps, controller: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children:
                          _apps.map((app) => _EmulatorView(app: app)).toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────

class _AppPreviewHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  const _AppPreviewHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        border: Border(bottom: BorderSide(color: scheme.stroke, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: SellioColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.smartphone, size: 18, color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Preview',
                style: AppTypography.subtitle.copyWith(
                  color: scheme.title,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                'Live Android emulator · Powered by Appetize.io',
                style: AppTypography.caption
                    .copyWith(color: scheme.hint, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(LucideIcons.refreshCw, size: 16, color: scheme.hint),
            tooltip: 'Reload preview keys',
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ─── Tab Bar ──────────────────────────────────────────────────

class _AppTabBar extends StatelessWidget {
  final List<_AppInfo> apps;
  final TabController controller;

  const _AppTabBar({required this.apps, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      color: scheme.surfaceLow,
      child: TabBar(
        controller: controller,
        tabs: apps
            .map((app) => Tab(text: '${app.emoji}  ${app.label}'))
            .toList(),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.hint,
        indicatorColor: scheme.primary,
        labelStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Emulator View ────────────────────────────────────────────

class _EmulatorView extends StatefulWidget {
  final _AppInfo app;
  const _EmulatorView({super.key, required this.app});

  @override
  State<_EmulatorView> createState() => _EmulatorViewState();
}

class _EmulatorViewState extends State<_EmulatorView>
    with AutomaticKeepAliveClientMixin {
  bool _iframeLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = context.colors;

    if (widget.app.embedUrl.isEmpty) {
      return _StateView.error(
        message: 'No embed URL for ${widget.app.label}.',
        onRetry: null,
      );
    }

    return Center(
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final maxH = (constraints.maxHeight - 60).clamp(380.0, 860.0);
          // Pixel 7 aspect ratio  ~9 : 19.5
          final phoneW = (maxH * 9 / 19.5).clamp(220.0, 360.0);
          final phoneH = phoneW * 19.5 / 9;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Device shell
              Container(
                width: phoneW + 20,
                height: phoneH + 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceLow,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: scheme.stroke, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: Stack(
                    children: [
                      _AppetizeFrame(
                        viewId: 'appetize-${widget.app.name}',
                        embedUrl: widget.app.embedUrl,
                        onLoad: () =>
                            setState(() => _iframeLoaded = true),
                      ),
                      // Loading overlay — hidden once iframe fires onLoad
                      if (!_iframeLoaded)
                        Container(
                          color: scheme.surface,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SLoading(),
                                const SizedBox(height: 14),
                                Text(
                                  'Starting ${widget.app.label}…',
                                  style: AppTypography.caption
                                      .copyWith(color: scheme.hint),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'First load may take ~20 s',
                                  style: AppTypography.caption.copyWith(
                                    color: scheme.hint,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.app.emoji}  Sellio ${widget.app.label}',
                style: AppTypography.caption.copyWith(color: scheme.hint),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Appetize iframe (HtmlElementView) ────────────────────────

class _AppetizeFrame extends StatefulWidget {
  final String viewId;
  final String embedUrl;
  final VoidCallback onLoad;

  const _AppetizeFrame({
    required this.viewId,
    required this.embedUrl,
    required this.onLoad,
  });

  @override
  State<_AppetizeFrame> createState() => _AppetizeFrameState();
}

class _AppetizeFrameState extends State<_AppetizeFrame> {
  @override
  void initState() {
    super.initState();
    // Guard: only register once per viewId (re-registration crashes)
    if (!_registeredViewIds.contains(widget.viewId)) {
      _registeredViewIds.add(widget.viewId);
      final src = widget.embedUrl;
      final onLoad = widget.onLoad;
      ui_web.platformViewRegistry.registerViewFactory(
        widget.viewId,
        (int id) {
          final iframe = web.HTMLIFrameElement()
            ..src = src
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allow = 'fullscreen';
          iframe.onLoad.listen((_) => onLoad());
          return iframe;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      HtmlElementView(viewType: widget.viewId);
}

// ─── State Views (Error / Empty) ──────────────────────────────

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  factory _StateView.error({
    required String message,
    required VoidCallback? onRetry,
  }) =>
      _StateView(
        icon: LucideIcons.alertCircle,
        title: 'Preview unavailable',
        message: message,
        onAction: onRetry,
        actionLabel: 'Try again',
      );

  factory _StateView.empty({required VoidCallback onRefresh}) => _StateView(
        icon: LucideIcons.smartphone,
        title: 'No preview available yet',
        message:
            'Merge a PR to develop to trigger the CD pipeline\n'
            'and publish the Appetize keys.',
        onAction: onRefresh,
        actionLabel: 'Refresh',
      );

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.hint),
            const SizedBox(height: 16),
            Text(title,
                style:
                    AppTypography.subtitle.copyWith(color: scheme.title)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  AppTypography.caption.copyWith(color: scheme.hint),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              SButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
