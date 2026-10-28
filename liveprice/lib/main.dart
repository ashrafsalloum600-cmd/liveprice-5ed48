import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder, CupertinoScrollBehavior;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'theme/app_colors.dart';
import 'theme/theme_controller.dart';
import 'theme/theme_reveal.dart';
import 'currency_rates_screen.dart';
import 'firebase_options.dart';
import 'models/nav_item_data.dart';
import 'splash_screen.dart';
import 'product_card.dart';
import 'screens/staff_gate_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/fcm_service.dart';
import 'services/notification_center.dart';
import 'services/pricing.dart';
import 'widgets/app_drawer.dart';
import 'widgets/pill_nav_bar.dart';
import 'widgets/top_search_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LdBlOUtAAAAAKbDa0P4Jod7WO1wSHnC0cZ550S6'),
  );
  await ThemeController.instance.init();
  Pricing.instance.start();
  registerFcmBackgroundHandler();
  runApp(const MyApp());
  initFcm();
}

class _AppScroll extends CupertinoScrollBehavior {
  const _AppScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _theme(bool dark) {
    final c = AppColors.current;
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,
      colorSchemeSeed: c.accent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 0.5, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        final icons = dark ? Brightness.light : Brightness.dark;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scrollBehavior: const _AppScroll(),
          theme: _theme(dark),
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: icons,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: icons,
            ),
            child: ThemeReveal(key: ThemeReveal.revealKey, child: child ?? const SizedBox.shrink()),
          ),
          home: const SplashScreen(next: ThemeScope(child: DemoPage())),
        );
      },
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 1;
  bool _searchVisible = true;
  String _query = '';

  static const List<NavItemData> _items = <NavItemData>[
    NavItemData(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'التنبيهات'),
    NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الصفحة الرئيسية'),
    NavItemData(icon: Icons.attach_money_outlined, activeIcon: Icons.attach_money_rounded, label: 'اسعار الدولار'),
  ];

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.start();
  }

  bool _onScroll(ScrollNotification n) {
    if (_index != 1) return false;
    if (n is! ScrollUpdateNotification || n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final p = n.metrics.pixels;
    if (_searchVisible && p > 56 && _query.isEmpty) {
      setState(() => _searchVisible = false);
    } else if (!_searchVisible && p <= 0) {
      setState(() => _searchVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final int alertsIndex = _items.indexWhere((item) => item.label == 'التنبيهات');
    final int homeIndex = _items.indexWhere((item) => item.label == 'الصفحة الرئيسية');

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: _searchVisible ? 68 : 0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TopSearchBar(
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onChanged: (query) => setState(() => _query = query),
                    onAdminLongPress: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StaffGateScreen())),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: AnimatedBuilder(
                animation: NotificationCenter.instance,
                builder: (context, _) => PillNavBar(
                  items: _items,
                  currentIndex: _index,
                  badgeIndices: NotificationCenter.instance.hasUnread ? {alertsIndex} : const {},
                  onTap: (index) {
                    setState(() {
                      _index = index;
                      _searchVisible = true;
                    });
                    if (index == alertsIndex) NotificationCenter.instance.markAllRead();
                  },
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: _index == homeIndex
                    ? ProductsGrid(searchQuery: _query)
                    : _index == alertsIndex
                    ? const NotificationsScreen()
                    : const CurrencyRatesScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
