import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/products_provider.dart';
import 'providers/upload_provider.dart';
import 'screens/home_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/upload_screen.dart';

void main() {
  runApp(const ArtisanApp());
}

class ArtisanApp extends StatelessWidget {
  const ArtisanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductsProvider()),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
      ],
      child: MaterialApp(
        title: 'Artisan Market',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _MainShell(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD97706), // warm amber
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tab = 0;

  static const _tabs = [
    NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Browse'),
    NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Sell'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (isWide) {
      // Tablet: persistent side rail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.handshake_outlined,
                        size: 32, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    Text('Artisan',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  label: Text('Browse'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add_box_outlined),
                  label: Text('Sell'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text('Orders'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _tabContent),
          ],
        ),
      );
    }

    // Phone: bottom navigation bar
    return Scaffold(
      body: _tabContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: _tabs,
      ),
    );
  }

  Widget get _tabContent => switch (_tab) {
        0 => const HomeScreen(),
        1 => const UploadScreen(),
        2 => const OrdersScreen(),
        _ => const HomeScreen(),
      };
}
