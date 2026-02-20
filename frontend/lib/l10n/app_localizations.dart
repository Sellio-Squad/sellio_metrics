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
  String get settingsRepository => _t('settingsRepository');
  String get settingsLoadingRepos => _t('settingsLoadingRepos');
  String get settingsNoRepos => _t('settingsNoRepos');
  String get settingsSelectRepo => _t('settingsSelectRepo');
  String get settingsCurrent => _t('settingsCurrent');

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

  // ─── About page — Hero ───────────────────────────────────
  String get aboutTagline => _t('aboutTagline');

  // ─── About page — Vision ──────────────────────────────────
  String get aboutVisionP1 => _t('aboutVisionP1');
  String get aboutVisionP2 => _t('aboutVisionP2');
  String get aboutVisionChipMena => _t('aboutVisionChipMena');
  String get aboutVisionChipSustainability => _t('aboutVisionChipSustainability');
  String get aboutVisionChipAi => _t('aboutVisionChipAi');
  String get aboutVisionChipMobile => _t('aboutVisionChipMobile');
  String get aboutSummaryBody => _t('aboutSummaryBody');

  // ─── About page — Apps ────────────────────────────────────
  String get aboutAppCustomerName => _t('aboutAppCustomerName');
  String get aboutAppCustomerDesc => _t('aboutAppCustomerDesc');
  String get aboutAppAdminName => _t('aboutAppAdminName');
  String get aboutAppAdminDesc => _t('aboutAppAdminDesc');
  String get aboutAppSellerName => _t('aboutAppSellerName');
  String get aboutAppSellerDesc => _t('aboutAppSellerDesc');
  String get aboutStatusInProgress => _t('aboutStatusInProgress');
  String get aboutStatusPlanned => _t('aboutStatusPlanned');
  String get aboutComingSoon => _t('aboutComingSoon');

  // ─── About page — Tech Stack ──────────────────────────────
  String get techFlutter => _t('techFlutter');
  String get techFlutterRole => _t('techFlutterRole');
  String get techKotlin => _t('techKotlin');
  String get techKotlinRole => _t('techKotlinRole');
  String get techGithubActions => _t('techGithubActions');
  String get techGithubActionsRole => _t('techGithubActionsRole');
  String get techFirebase => _t('techFirebase');
  String get techFirebaseRole => _t('techFirebaseRole');

  // ─── About page — How to Join ─────────────────────────────
  String get joinStep1Title => _t('joinStep1Title');
  String get joinStep1Desc => _t('joinStep1Desc');
  String get joinStep2Title => _t('joinStep2Title');
  String get joinStep2Desc => _t('joinStep2Desc');
  String get joinStep3Title => _t('joinStep3Title');
  String get joinStep3Desc => _t('joinStep3Desc');

  // ─── About page — Features ────────────────────────────────
  String get aboutKeyFeatures => _t('aboutKeyFeatures');
  String get featureMarketplace => _t('featureMarketplace');
  String get featureThrifting => _t('featureThrifting');
  String get featureAiDesign => _t('featureAiDesign');
  String get featureAnalytics => _t('featureAnalytics');
  String get featureMicroservices => _t('featureMicroservices');
  String get featureCrossplatform => _t('featureCrossplatform');

  // ─── Team Structure ───────────────────────────────────────
  String get teamPlatformName => _t('teamPlatformName');
  String get teamPlatformLeader => _t('teamPlatformLeader');
  String get teamPlatformDesc => _t('teamPlatformDesc');
  String get teamProductName => _t('teamProductName');
  String get teamProductLeader => _t('teamProductLeader');
  String get teamProductDesc => _t('teamProductDesc');
  String get teamBackendName => _t('teamBackendName');
  String get teamBackendLeader => _t('teamBackendLeader');
  String get teamBackendDesc => _t('teamBackendDesc');

  // ─── Leaderboard / Review units ──────────────────────────
  String get unitReviews => _t('unitReviews');
  String get unitPrs => _t('unitPrs');
  String get unitComments => _t('unitComments');

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
    'settingsRepository': 'Repository',
    'settingsLoadingRepos': 'Loading repositories...',
    'settingsNoRepos': 'No repositories available',
    'settingsSelectRepo': 'Select which repository to show metrics for:',
    'settingsCurrent': 'Current',
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

    // About — Hero
    'aboutTagline': 'E-Commerce • Thrifting • AI-Powered',

    // About — Vision
    'aboutVisionP1':
        'Sellio is a startup e-commerce platform that reimagines '
        'how people buy and sell online. We connect sellers and buyers '
        'in a seamless marketplace for both pre-owned and new goods, '
        'combining traditional e-commerce with modern thrifting culture.',
    'aboutVisionP2':
        'Our mission is to make online selling as easy as posting on '
        'social media while providing buyers with a curated, trustworthy '
        'shopping experience. We target the growing second-hand market '
        'in the MENA region, where sustainability meets affordability.',
    'aboutVisionChipMena': 'MENA-first approach',
    'aboutVisionChipSustainability': 'Sustainability-driven',
    'aboutVisionChipAi': 'AI-powered curation',
    'aboutVisionChipMobile': 'Mobile-first design',
    'aboutSummaryBody':
        'Sellio differentiates itself through AI-powered product recommendations, '
        'integrated design generation tools, and a streamlined seller onboarding '
        'process that reduces listing time by 70%. Our scalable microservices '
        'architecture supports rapid growth, and our cross-platform Flutter apps '
        'ensure a consistent experience across iOS, Android, and Web.',

    // About — Apps
    'aboutAppCustomerName': 'Customer App',
    'aboutAppCustomerDesc':
        'Browse, buy, and explore curated products. '
        'Smart search, wishlists, and secure checkout.',
    'aboutAppAdminName': 'Admin Panel',
    'aboutAppAdminDesc':
        'Manage platform, users, analytics, and orders. '
        'Real-time monitoring dashboard.',
    'aboutAppSellerName': 'Seller App',
    'aboutAppSellerDesc':
        'List products with AI descriptions, manage orders, '
        'track sales performance.',
    'aboutStatusInProgress': 'In Progress',
    'aboutStatusPlanned': 'Planned',
    'aboutComingSoon': 'Coming Soon',

    // About — Tech Stack
    'techFlutter': 'Flutter',
    'techFlutterRole': 'Mobile & Web',
    'techKotlin': 'Kotlin',
    'techKotlinRole': 'Backend API',
    'techGithubActions': 'GitHub Actions',
    'techGithubActionsRole': 'CI/CD Pipeline',
    'techFirebase': 'Firebase',
    'techFirebaseRole': 'Auth & Database',

    // About — How to Join
    'joinStep1Title': 'Get in Touch',
    'joinStep1Desc':
        'Reach out to us via email or LinkedIn to express '
        'your interest in joining the Sellio team.',
    'joinStep2Title': 'Share Your Work',
    'joinStep2Desc':
        'Send us your portfolio, GitHub profile, or any '
        'projects that showcase your skills.',
    'joinStep3Title': 'Start Contributing',
    'joinStep3Desc':
        'After a quick onboarding, dive straight into real '
        'features with our agile squad.',

    // About — Features
    'aboutKeyFeatures': 'Key Features',
    'featureMarketplace': 'Multi-vendor e-commerce marketplace',
    'featureThrifting': 'Thrifting & pre-owned goods',
    'featureAiDesign': 'AI-powered design generation',
    'featureAnalytics': 'Real-time analytics dashboard',
    'featureMicroservices': 'Scalable microservices backend',
    'featureCrossplatform': 'Cross-platform Flutter apps',

    // Team Structure
    'teamPlatformName': 'Platform Team',
    'teamPlatformLeader': 'Team Lead 1',
    'teamPlatformDesc': 'Core infrastructure, CI/CD, developer tools',
    'teamProductName': 'Product Team',
    'teamProductLeader': 'Team Lead 2',
    'teamProductDesc': 'Customer-facing features, UI/UX, mobile apps',
    'teamBackendName': 'Backend Team',
    'teamBackendLeader': 'Team Lead 3',
    'teamBackendDesc': 'APIs, microservices, data pipelines',

    // Leaderboard / Review units
    'unitReviews': 'reviews',
    'unitPrs': 'PRs',
    'unitComments': 'comments',
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
    'settingsRepository': 'المستودع',
    'settingsLoadingRepos': 'جارٍ تحميل المستودعات...',
    'settingsNoRepos': 'لا توجد مستودعات متاحة',
    'settingsSelectRepo': 'اختر المستودع لعرض المقاييس:',
    'settingsCurrent': 'الحالي',
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

    // About — Hero
    'aboutTagline': 'تجارة إلكترونية • ثريفتينغ • مدعوم بالذكاء الاصطناعي',

    // About — Vision
    'aboutVisionP1':
        'سيليو هي منصة تجارة إلكترونية ناشئة تعيد تصور '
        'طريقة البيع والشراء عبر الإنترنت. نربط البائعين والمشترين '
        'في سوق سلس للسلع الجديدة والمستعملة، '
        'نجمع بين التجارة الإلكترونية التقليدية وثقافة الثريفتينغ الحديثة.',
    'aboutVisionP2':
        'مهمتنا هي جعل البيع عبر الإنترنت سهلاً كالنشر على '
        'وسائل التواصل الاجتماعي مع تقديم تجربة تسوق منسقة وموثوقة '
        'للمشترين. نستهدف سوق السلع المستعملة المتنامي '
        'في منطقة الشرق الأوسط وشمال أفريقيا، حيث تلتقي الاستدامة مع القدرة على تحمل التكاليف.',
    'aboutVisionChipMena': 'أولوية الشرق الأوسط',
    'aboutVisionChipSustainability': 'مدفوع بالاستدامة',
    'aboutVisionChipAi': 'تنسيق بالذكاء الاصطناعي',
    'aboutVisionChipMobile': 'تصميم الموبايل أولاً',
    'aboutSummaryBody':
        'تتميز سيليو بتوصيات المنتجات المدعومة بالذكاء الاصطناعي، '
        'وأدوات توليد التصميم المتكاملة، وعملية تسجيل البائعين المبسطة '
        'التي تقلل وقت الإدراج بنسبة 70%. تدعم بنيتنا القابلة للتوسع '
        'النمو السريع، وتضمن تطبيقات Flutter عبر المنصات '
        'تجربة متسقة عبر iOS و Android والويب.',

    // About — Apps
    'aboutAppCustomerName': 'تطبيق العملاء',
    'aboutAppCustomerDesc':
        'تصفح واشترِ واستكشف المنتجات المنسقة. '
        'بحث ذكي وقوائم أمنيات ودفع آمن.',
    'aboutAppAdminName': 'لوحة الإدارة',
    'aboutAppAdminDesc':
        'إدارة المنصة والمستخدمين والتحليلات والطلبات. '
        'لوحة مراقبة في الوقت الفعلي.',
    'aboutAppSellerName': 'تطبيق البائع',
    'aboutAppSellerDesc':
        'أدرج المنتجات بأوصاف AI وأدر الطلبات '
        'وتتبع أداء المبيعات.',
    'aboutStatusInProgress': 'قيد التنفيذ',
    'aboutStatusPlanned': 'مخطط',
    'aboutComingSoon': 'قريباً',

    // About — Tech Stack
    'techFlutter': 'Flutter',
    'techFlutterRole': 'محمول وويب',
    'techKotlin': 'Kotlin',
    'techKotlinRole': 'واجهة برمجية خلفية',
    'techGithubActions': 'GitHub Actions',
    'techGithubActionsRole': 'خط أنابيب CI/CD',
    'techFirebase': 'Firebase',
    'techFirebaseRole': 'مصادقة وقاعدة بيانات',

    // About — How to Join
    'joinStep1Title': 'تواصل معنا',
    'joinStep1Desc':
        'تواصل معنا عبر البريد الإلكتروني أو LinkedIn للتعبير عن '
        'اهتمامك بالانضمام إلى فريق سيليو.',
    'joinStep2Title': 'شارك أعمالك',
    'joinStep2Desc':
        'أرسل لنا ملف أعمالك أو ملفك على GitHub أو أي '
        'مشاريع تعرض مهاراتك.',
    'joinStep3Title': 'ابدأ المساهمة',
    'joinStep3Desc':
        'بعد تأهيل سريع، انطلق مباشرة في ميزات حقيقية '
        'مع فريقنا الرشيق.',

    // About — Features
    'aboutKeyFeatures': 'الميزات الرئيسية',
    'featureMarketplace': 'سوق تجارة إلكترونية متعدد البائعين',
    'featureThrifting': 'ثريفتينغ وسلع مستعملة',
    'featureAiDesign': 'توليد تصميم بالذكاء الاصطناعي',
    'featureAnalytics': 'لوحة تحليلات في الوقت الفعلي',
    'featureMicroservices': 'واجهة خلفية بخدمات مصغرة قابلة للتوسع',
    'featureCrossplatform': 'تطبيقات Flutter عبر المنصات',

    // Team Structure
    'teamPlatformName': 'فريق المنصة',
    'teamPlatformLeader': 'قائد الفريق 1',
    'teamPlatformDesc': 'البنية التحتية الأساسية، CI/CD، أدوات المطورين',
    'teamProductName': 'فريق المنتج',
    'teamProductLeader': 'قائد الفريق 2',
    'teamProductDesc': 'الميزات الموجهة للعملاء، UI/UX، تطبيقات الجوال',
    'teamBackendName': 'فريق الواجهة الخلفية',
    'teamBackendLeader': 'قائد الفريق 3',
    'teamBackendDesc': 'واجهات برمجية، خدمات مصغرة، أنابيب بيانات',

    // Leaderboard / Review units
    'unitReviews': 'مراجعات',
    'unitPrs': 'طلبات',
    'unitComments': 'تعليقات',
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
