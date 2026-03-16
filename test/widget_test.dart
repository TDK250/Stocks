import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stock_tracker/main.dart';
import 'package:stock_tracker/provider.dart';
import 'package:stock_tracker/settings_provider.dart';
import 'package:stock_tracker/services/storage_service.dart';
import 'package:stock_tracker/services/yahoo_finance_service.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    final storage = StorageService();
    final yahoo = YahooFinanceService();

    await tester.pumpWidget(
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

    expect(find.text('Portfolio'), findsAtLeastNWidgets(1));
  });
}
