import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'theme/app_colors.dart';
import 'currency_rates_screen.dart';
import 'firebase_options.dart';
import 'models/nav_item_data.dart';
import 'splash_screen.dart';
import 'product_card.dart';
import 'screens/admin_price_upload_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/fcm_service.dart';
import 'services/notification_center.dart';
import 'services/pricing.dart';
import 'widgets/app_drawer.dart';
import 'widgets/flipping_header_bar.dart';
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
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LdBlOUtAAAAAKbDa0P4Jod7WO1wSHnC0cZ550S6'),
  );
  Pricing.instance.start();
  registerFcmBackgroundHandler();
  runApp(const MyApp());
  initFcm();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorSchemeSeed: AppColors.accent,
      ),
      home: const SplashScreen(next: DemoPage()),
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
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPriceUploadScreen())),
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
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.doc('settings/pricing').snapshots(),
              builder: (context, snapshot) {
                final exchangeRate = (snapshot.data?.data()?['usdToSyp'] as num?)?.toDouble() ?? 0.0;
                final lastUpdatedText = snapshot.hasData ? 'تم التحديث الآن' : 'في انتظار التحديث';
                final isOnline = snapshot.connectionState == ConnectionState.active && !snapshot.hasError;

                return FlippingHeaderBar(
                  exchangeRate: exchangeRate,
                  lastUpdatedText: lastUpdatedText,
                  isOnline: isOnline,
                );
              },
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
