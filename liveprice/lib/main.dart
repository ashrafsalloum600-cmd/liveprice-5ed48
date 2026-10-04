import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'currency_rates_screen.dart';
import 'firebase_options.dart';
import 'models/nav_item_data.dart';
import 'splash_screen.dart';
import 'product_card.dart';
import 'screens/admin_price_upload_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/notification_center.dart';
import 'user_profile_screen.dart';
import 'widgets/pill_nav_bar.dart';
import 'widgets/search_pill.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  }

  @override
  Widget build(BuildContext context) {
    final int alertsIndex = _items.indexWhere((item) => item.label == 'التنبيهات');

    return Scaffold(
      backgroundColor: const Color(0xFFE4E4E4),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: () =>
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => const AdminPriceUploadScreen())),
                            child: const Text(
                              'My Price',
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SearchPill(onChanged: (String value) {}),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _index == 0
                        ? const ProductsGrid()
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
