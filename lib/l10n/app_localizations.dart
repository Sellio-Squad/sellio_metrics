/// Sellio Metrics — Localization System
///
/// Provides EN and AR translations with a Flutter LocalizationsDelegate.
library;

import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  String get languageCode => locale.languageCode;
  bool get isArabic => locale.languageCode == 'ar';

  // ─── Strings ─────────────────────────────────────────────
  String get appTitle => _t('appTitle');
  String get appSubtitle => _t('appSubtitle');

  // Navigation
  String get navAnalytics => _t('navAnalytics');
  String get navOpenPrs => _t('navOpenPrs');
  String get navTeam => _t('navTeam');
  String get navCharts => _t('navCharts');
  String get navAbout => _t('navAbout');
  String get navSettings => _t('navSettings');

  // KPI
  String get kpiTotalPrs => _t('kpiTotalPrs');
  String get kpiMergedPrs => _t('kpiMergedPrs');
  String get kpiClosedPrs => _t('kpiClosedPrs');
  String get kpiAvgPrSize => _t('kpiAvgPrSize');
  String get kpiTotalComments => _t('kpiTotalComments');
  String get kpiAvgComments => _t('kpiAvgComments');
  String get kpiAvgApproval => _t('kpiAvgApproval');
  String get kpiAvgLifespan => _t('kpiAvgLifespan');
  String get kpiMergeRate => _t('kpiMergeRate');

  // Filters
  String get filterAllTime => _t('filterAllTime');
  String get filterAllTeam => _t('filterAllTeam');
  String get filterStartDate => _t('filterStartDate');
  String get filterEndDate => _t('filterEndDate');
  String get filterDeveloper => _t('filterDeveloper');

  // Sections
  String get sectionBottlenecks => _t('sectionBottlenecks');
  String get sectionOpenPrs => _t('sectionOpenPrs');
  String get sectionLeaderboard => _t('sectionLeaderboard');
  String get sectionReviewLoad => _t('sectionReviewLoad');
  String get sectionCollaboration => _t('sectionCollaboration');
  String get sectionSpotlight => _t('sectionSpotlight');
  String get sectionPrActivity => _t('sectionPrActivity');
  String get sectionPrTypes => _t('sectionPrTypes');
  String get sectionReviewTime => _t('sectionReviewTime');
  String get sectionCodeVolume => _t('sectionCodeVolume');
  String get sectionTeamStructure => _t('sectionTeamStructure');

  // Spotlight
  String get spotlightHotStreak => _t('spotlightHotStreak');
  String get spotlightFastestReviewer => _t('spotlightFastestReviewer');
  String get spotlightTopCommenter => _t('spotlightTopCommenter');

  // Bottleneck
  String get bottleneckSeverityHigh => _t('bottleneckSeverityHigh');
  String get bottleneckSeverityMedium => _t('bottleneckSeverityMedium');
  String get bottleneckSeverityLow => _t('bottleneckSeverityLow');
  String get bottleneckWaiting => _t('bottleneckWaiting');

  // Settings
  String get settingsTheme => _t('settingsTheme');
  String get settingsLanguage => _t('settingsLanguage');
  String get settingsThreshold => _t('settingsThreshold');
  String get settingsAbout => _t('settingsAbout');

  // Language
  String get languageArabic => _t('languageArabic');
  String get languageEnglish => _t('languageEnglish');

  // Theme labels
  String get themeDark => _t('themeDark');
  String get themeLight => _t('themeLight');

  // Date range
  String get filterFrom => _t('filterFrom');
  String get filterUntil => _t('filterUntil');

  // Search
  String get searchPlaceholder => _t('searchPlaceholder');
  String get searchNoResults => _t('searchNoResults');

  // Status
  String get statusMerged => _t('statusMerged');
  String get statusPending => _t('statusPending');
  String get statusClosed => _t('statusClosed');
  String get statusApproved => _t('statusApproved');
  String get statusAll => _t('statusAll');

  // States
  String get loadingData => _t('loadingData');
  String get errorLoadingData => _t('errorLoadingData');
  String get retry => _t('retry');
  String get emptyData => _t('emptyData');

  // About
  String get aboutSellio => _t('aboutSellio');
  String get aboutExecutiveSummary => _t('aboutExecutiveSummary');
  String get aboutApps => _t('aboutApps');
  String get aboutTechStack => _t('aboutTechStack');

  // Tooltips
  String get tooltipKpi => _t('tooltipKpi');
  String get tooltipBottleneck => _t('tooltipBottleneck');
  String get tooltipLeaderboard => _t('tooltipLeaderboard');
  String get tooltipChart => _t('tooltipChart');

  // New strings
  String get filterCurrentSprint => _t('filterCurrentSprint');
  String get aboutHowToJoin => _t('aboutHowToJoin');
  String get aboutTryLive => _t('aboutTryLive');
  String get aboutVision => _t('aboutVision');
  String get teamLeader => _t('teamLeader');

  String _t(String key) => _localizedValues[locale.languageCode]?[key] ?? key;

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': _en,
    'ar': _ar,
  };

  static const Map<String, String> _en = {
    'appTitle': 'Sellio Squad Dashboard',
    'appSubtitle': 'Team Metrics & Analytics',
    'navAnalytics': 'Analytics',
    'navOpenPrs': 'Open PRs',
    'navTeam': 'Team',
    'navCharts': 'Charts',
    'navAbout': 'About',
    'navSettings': 'Settings',
    'kpiTotalPrs': 'Total PRs',
    'kpiMergedPrs': 'Merged PRs',
    'kpiClosedPrs': 'Closed PRs',
    'kpiAvgPrSize': 'Avg. PR Size',
    'kpiTotalComments': 'Total Comments',
    'kpiAvgComments': 'Avg. Comments / PR',
    'kpiAvgApproval': 'Avg. Time to Approval',
    'kpiAvgLifespan': 'Avg. PR Lifespan',
    'kpiMergeRate': 'Merge Rate',
    'filterAllTime': 'All Time',
    'filterAllTeam': 'All Team',
    'filterStartDate': 'Start Date',
    'filterEndDate': 'End Date',
    'filterDeveloper': 'Developer',
    'sectionBottlenecks': 'Slow PRs',
    'sectionOpenPrs': 'Open Pull Requests',
    'sectionLeaderboard': 'Leaderboard',
    'sectionReviewLoad': 'Review Load',
    'sectionCollaboration': 'Top Collaboration Pairs',
    'sectionSpotlight': 'Spotlight',
    'sectionPrActivity': 'PR Activity Over Time',
    'sectionPrTypes': 'PR Type Distribution',
    'sectionReviewTime': 'Avg. Review Time by Developer',
    'sectionCodeVolume': 'Code Volume',
    'sectionTeamStructure': 'Team Structure',
    'spotlightHotStreak': 'Hot Streak',
    'spotlightFastestReviewer': 'Fastest Reviewer',
    'spotlightTopCommenter': 'Top Commenter',
    'languageArabic': 'العربية',
    'languageEnglish': 'English',
    'themeDark': 'Dark',
    'themeLight': 'Light',
    'filterFrom': 'From',
    'filterUntil': 'Until',
    'bottleneckSeverityHigh': 'High',
    'bottleneckSeverityMedium': 'Medium',
    'bottleneckSeverityLow': 'Low',
    'bottleneckWaiting': 'waiting',
    'settingsTheme': 'Dark Mode',
    'settingsLanguage': 'Language',
    'settingsThreshold': 'Bottleneck Threshold (hours)',
    'settingsAbout': 'About Sellio Metrics',
    'searchPlaceholder': 'Search PRs by title, author…',
    'searchNoResults': 'No pull requests match your filters.',
    'statusMerged': 'Merged',
    'statusPending': 'Pending',
    'statusClosed': 'Closed',
    'statusApproved': 'Approved',
    'statusAll': 'All',
    'loadingData': 'Loading dashboard data…',
    'errorLoadingData': 'Failed to load data',
    'retry': 'Retry',
    'emptyData': 'No data available',
    'aboutSellio': 'About Sellio',
    'aboutExecutiveSummary': 'Executive Summary',
    'aboutApps': 'Our Apps',
    'aboutTechStack': 'Tech Stack',
    'tooltipKpi': 'Key performance indicators computed from your PR data',
    'tooltipBottleneck': 'PRs stuck in review longer than the threshold',
    'tooltipLeaderboard': 'Scored by: PRs created ×3, merged ×2, reviews ×2, comments ×1',
    'tooltipChart': 'Click on a segment for details',
    'filterCurrentSprint': 'Current Sprint',
    'aboutHowToJoin': 'How to Join Us',
    'aboutTryLive': 'Try Live',
    'aboutVision': 'Our Vision',
    'teamLeader': 'Team Lead',
  };

  static const Map<String, String> _ar = {
    'appTitle': 'لوحة سيليو',
    'appSubtitle': 'مقاييس الفريق والتحليلات',
    'navAnalytics': 'التحليلات',
    'navOpenPrs': 'الطلبات المفتوحة',
    'navTeam': 'الفريق',
    'navCharts': 'الرسوم',
    'navAbout': 'حول',
    'navSettings': 'الإعدادات',
    'kpiTotalPrs': 'إجمالي الطلبات',
    'kpiMergedPrs': 'الطلبات المدمجة',
    'kpiClosedPrs': 'الطلبات المغلقة',
    'kpiAvgPrSize': 'متوسط حجم الطلب',
    'kpiTotalComments': 'إجمالي التعليقات',
    'kpiAvgComments': 'متوسط التعليقات / طلب',
    'kpiAvgApproval': 'متوسط وقت الموافقة',
    'kpiAvgLifespan': 'متوسط عمر الطلب',
    'kpiMergeRate': 'معدل الدمج',
    'filterAllTime': 'كل الوقت',
    'filterAllTeam': 'كل الفريق',
    'filterStartDate': 'تاريخ البداية',
    'filterEndDate': 'تاريخ النهاية',
    'filterDeveloper': 'المطور',
    'sectionBottlenecks': 'طلبات بطيئة',
    'sectionOpenPrs': 'الطلبات المفتوحة',
    'sectionLeaderboard': 'لوحة المتصدرين',
    'sectionReviewLoad': 'حمل المراجعة',
    'sectionCollaboration': 'أفضل أزواج التعاون',
    'sectionSpotlight': 'تحت الأضواء',
    'sectionPrActivity': 'نشاط الطلبات بمرور الوقت',
    'sectionPrTypes': 'توزيع أنواع الطلبات',
    'sectionReviewTime': 'متوسط وقت المراجعة حسب المطور',
    'sectionCodeVolume': 'حجم الكود',
    'sectionTeamStructure': 'هيكل الفريق',
    'spotlightHotStreak': 'سلسلة نارية',
    'spotlightFastestReviewer': 'أسرع مراجع',
    'spotlightTopCommenter': 'أكثر تعليقاً',
    'languageArabic': 'العربية',
    'languageEnglish': 'English',
    'themeDark': 'داكن',
    'themeLight': 'فاتح',
    'filterFrom': 'من',
    'filterUntil': 'حتى',
    'bottleneckSeverityHigh': 'عالي',
    'bottleneckSeverityMedium': 'متوسط',
    'bottleneckSeverityLow': 'منخفض',
    'bottleneckWaiting': 'في الانتظار',
    'settingsTheme': 'الوضع الداكن',
    'settingsLanguage': 'اللغة',
    'settingsThreshold': 'حد الاختناق (ساعات)',
    'settingsAbout': 'حول سيليو ميتركس',
    'searchPlaceholder': 'ابحث في الطلبات بالعنوان أو المؤلف…',
    'searchNoResults': 'لا توجد طلبات تطابق بحثك.',
    'statusMerged': 'مدمج',
    'statusPending': 'معلق',
    'statusClosed': 'مغلق',
    'statusApproved': 'موافق عليه',
    'statusAll': 'الكل',
    'loadingData': 'جارٍ تحميل بيانات اللوحة…',
    'errorLoadingData': 'فشل تحميل البيانات',
    'retry': 'إعادة المحاولة',
    'emptyData': 'لا توجد بيانات',
    'aboutSellio': 'حول سيليو',
    'aboutExecutiveSummary': 'ملخص تنفيذي',
    'aboutApps': 'تطبيقاتنا',
    'aboutTechStack': 'التقنيات',
    'tooltipKpi': 'مؤشرات الأداء الرئيسية المحسوبة من بيانات الطلبات',
    'tooltipBottleneck': 'الطلبات العالقة في المراجعة أطول من الحد',
    'tooltipLeaderboard': 'التقييم: طلبات ×3، دمج ×2، مراجعات ×2، تعليقات ×1',
    'tooltipChart': 'انقر على شريحة للتفاصيل',
    'filterCurrentSprint': 'السبرنت الحالي',
    'aboutHowToJoin': 'كيفية الانضمام إلينا',
    'aboutTryLive': 'جرّب مباشرة',
    'aboutVision': 'رؤيتنا',
    'teamLeader': 'قائد الفريق',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
