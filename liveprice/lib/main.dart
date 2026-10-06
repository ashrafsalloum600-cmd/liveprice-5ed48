import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'user_profile_screen.dart';
import 'widgets/currency_toggle.dart';
import 'widgets/pill_nav_bar.dart';
import 'widgets/rate_banner.dart';
import 'widgets/search_pill.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1E88E5)),
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
  int _index = 0;
  String _searchQuery = '';
  List<String> _searchHistory = [];

  static const List<NavItemData> _items = <NavItemData>[
    NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'الصفحة الرئيسية'),
    NavItemData(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'التنبيهات'),
    NavItemData(icon: Icons.attach_money_outlined, activeIcon: Icons.attach_money_rounded, label: 'اسعار الدولار'),
    NavItemData(icon: Icons.people_outline_rounded, activeIcon: Icons.people_alt_rounded, label: 'الملف الشخصي'),
  ];

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.start();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _searchHistory = preferences.getStringList('search_history') ?? []);
  }

  Future<void> _saveSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final history = [
      query,
      ...?preferences.getStringList('search_history'),
    ].where((entry) => entry.toLowerCase() != query.toLowerCase()).take(8).toList();
    await preferences.setStringList('search_history', history);
    if (mounted) setState(() => _searchHistory = history);
  }

  @override
  Widget build(BuildContext context) {
    final int alertsIndex = _items.indexWhere((item) => item.label == 'التنبيهات');

    return Scaffold(
      backgroundColor: const Color(0xFFE4E4E4),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: _index == 3
            ? const UserProfileScreen()
            : _index == 2
            ? const CurrencyRatesScreen()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            GestureDetector(
                              onLongPress: () =>
                                  Navigator.of(context)
                                      .push(MaterialPageRoute(builder: (_) => const AdminPriceUploadScreen())),
                              child: const Text(
                                'My Price',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black),
                              ),
                            ),
                            const CurrencyToggle(),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SearchPill(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          onSearchSubmitted: _saveSearch,
                          onHistorySelected: (value) {
                            setState(() => _searchQuery = value);
                            _saveSearch(value);
                          },
                          history: _searchHistory,
                        ),
                        const SizedBox(height: 12),
                        const RateBanner(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _index == 0
                        ? ProductsGrid(searchQuery: _searchQuery)
                        : _index == 1
                        ? const NotificationsScreen()
                        : Center(
                            child: Text(
                              _items[_index].label,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                            ),
                          ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: AnimatedBuilder(
            animation: NotificationCenter.instance,
            builder: (context, _) => PillNavBar(
              items: _items,
              currentIndex: _index,
              badgeIndices: NotificationCenter.instance.hasUnread ? {alertsIndex} : const {},
              onTap: (index) {
                setState(() => _index = index);
                if (index == alertsIndex) NotificationCenter.instance.markAllRead();
              },
            ),
          ),
        ),
      ),
    );
  }
}
