import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'provider.dart';
import 'models.dart';
import 'settings_provider.dart';
import 'services/storage_service.dart';
import 'services/yahoo_finance_service.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final storage = StorageService();
  final yahoo = YahooFinanceService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProxyProvider<SettingsProvider, PortfolioProvider>(
          create: (_) => PortfolioProvider(storage, yahoo),
          update: (_, settings, portfolio) =>
              portfolio!..setDisplayCurrency(settings.displayCurrency),
        ),
      ],
      child: const StocksApp(),
    ),
  );
}

class StocksApp extends StatelessWidget {
  const StocksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightScheme;
            ColorScheme darkScheme;

            if (lightDynamic != null && darkDynamic != null) {
              lightScheme = lightDynamic.harmonized();
              darkScheme = darkDynamic.harmonized();
            } else {
              lightScheme = ColorScheme.fromSeed(
                seedColor: Colors.blueAccent,
                brightness: Brightness.light,
              );
              darkScheme = ColorScheme.fromSeed(
                seedColor: Colors.blueAccent,
                brightness: Brightness.dark,
              );
            }

            return MaterialApp(
              title: 'Stocks',
              debugShowCheckedModeBanner: false,
              themeMode: ThemeMode.system,
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: darkScheme,
                scaffoldBackgroundColor: const Color(0xFF0D1117),
                cardColor: const Color(0xFF161B22),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF161B22),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                ),
              ),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: lightScheme,
                scaffoldBackgroundColor: const Color(0xFFF6F8FA),
                cardColor: Colors.white,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                ),
              ),
              home: const MainShell(),
            );
          },
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1;
  static const _titles = ['Watchlist', 'Portfolio', 'Insights'];
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100, // Increased to fit "Total" nicely
        title: Consumer<PortfolioProvider>(
          builder: (context, provider, child) {
            return Text(
              _titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            );
          },
        ),
        leading: _buildTermButton(context),
        actions: [_buildCurrencyButton(context)],
      ),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (idx) => setState(() => _currentIndex = idx),
        children: const [WatchlistPage(), PortfolioPage(), InsightsPage()],
      ),
      floatingActionButton: Consumer<PortfolioProvider>(
        builder: (context, provider, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _currentIndex < 2
                ? FloatingActionButton.extended(
                    key: const ValueKey('fab'),
                    onPressed: () => showAddStockSheet(
                      context,
                      isWatchlist: _currentIndex == 0,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      _currentIndex == 1 ? 'Add Holding' : 'Add to Watchlist',
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty_fab')),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          _pageController.animateToPage(
            idx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility_rounded),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyButton(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) => PopupMenuButton<String>(
        tooltip: 'Display Currency',
        offset: const Offset(0, 48),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            settings.displayCurrency,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        onSelected: (currency) => settings.setDisplayCurrency(currency),
        itemBuilder: (context) =>
            [
                  'USD',
                  'CAD',
                  'EUR',
                  'GBP',
                  'JPY',
                  'AUD',
                  'CHF',
                  'HKD',
                  'INR',
                  'KRW',
                ]
                .map(
                  (c) => PopupMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Text(
                          Stock.currencySymbolFor(c),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Text(c),
                        if (c == settings.displayCurrency)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.check, size: 18),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildTermButton(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) => PopupMenuButton<DisplayTerm>(
        tooltip: 'Return Term',
        offset: const Offset(0, 48),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(left: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.selectedTerm.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
        onSelected: (term) {
          provider.setSelectedTerm(term);
          FocusScope.of(context).unfocus();
        },
        itemBuilder: (context) => DisplayTerm.values.map((term) {
          return PopupMenuItem(
            value: term,
            child: Row(
              children: [
                Text(term.label),
                if (term == provider.selectedTerm)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check, size: 18),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
