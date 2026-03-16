import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models.dart';
import 'provider.dart';
import 'holding_utils.dart';
import 'format_utils.dart';

class StockDetailScreen extends StatefulWidget {
  final Stock stock;

  const StockDetailScreen({super.key, required this.stock});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortfolioProvider>().refreshPrices(
        symbols: [widget.stock.symbol],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PortfolioProvider>();
    // Use the stock from the provider if possible to get fresh data
    final stock = provider.stocks.firstWhere(
      (s) => s.symbol == widget.stock.symbol,
      orElse: () => widget.stock,
    );
    final isPositive = stock.change >= 0;
    final changeColor = isPositive
        ? Colors.green.shade600
        : Colors.red.shade600;
    final cs = provider.displayCurrencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          stock.symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (stock.quantity == 0)
            IconButton(
              icon: Icon(
                stock.isWatchlisted
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: stock.isWatchlisted ? theme.colorScheme.primary : null,
              ),
              tooltip: stock.isWatchlisted
                  ? 'Remove from Watchlist'
                  : 'Add to Watchlist',
              onPressed: () => provider.toggleWatchlist(stock.symbol),
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showEditHoldingSheet(context, stock),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.red,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove Stock'),
                  content: Text(
                    'Are you sure you want to remove ${stock.symbol}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                provider.removeSymbol(stock.symbol);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stock.companyName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(stock.currentPrice, stock.currency))}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${stock.change >= 0 ? "+" : ""}${FormatUtils.formatNumber(stock.percentChange, decimalPlaces: 2)}%',
                    style: TextStyle(
                      color: changeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SimpleSection(
              title: 'Stats',
              children: [
                _StatRow('Sector', stock.sectorLabel),
                _StatRow('Industry', stock.industryLabel),
                _StatRow(
                  'Day High',
                  '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(stock.dayHigh, stock.currency))}',
                ),
                _StatRow(
                  'Day Low',
                  '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(stock.dayLow, stock.currency))}',
                ),
                _StatRow('Volume', stock.formattedVolume),
                _StatRow(
                  'Avg Volume',
                  Stock.formatLargeNumber(stock.averageVolume.toDouble()),
                ),
                _StatRow(
                  'Bid / Ask',
                  (stock.bid == 0 && stock.ask == 0)
                      ? 'N/A'
                      : '${FormatUtils.formatCurrency(stock.bid)} x ${FormatUtils.formatCurrency(stock.ask)}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SimpleSection(
              title: 'Advanced Stats',
              children: [
                _StatRow(
                  'Beta',
                  FormatUtils.formatNumber(stock.beta, decimalPlaces: 2),
                ),
                _StatRow(
                  'P/E Ratio',
                  FormatUtils.formatNumber(stock.peRatio, decimalPlaces: 2),
                ),
                _StatRow(
                  'Yield',
                  '${FormatUtils.formatNumber(stock.yieldPct, decimalPlaces: 2)}%',
                ),
                if (stock.instrumentType == 'ETF' ||
                    stock.instrumentType == 'MUTUALFUND') ...[
                  _StatRow(
                    'YTD Return',
                    '${FormatUtils.formatNumber(stock.ytdReturn, decimalPlaces: 2)}%',
                  ),
                  _StatRow(
                    'Expense Ratio',
                    '${FormatUtils.formatNumber(stock.expenseRatio, decimalPlaces: 2)}%',
                  ),
                  _StatRow(
                    'Net Assets',
                    Stock.formatLargeNumber(stock.netAssets),
                  ),
                  _StatRow('NAV', FormatUtils.formatCurrency(stock.nav)),
                ],
              ],
            ),
            if (stock.instrumentType == 'ETF' &&
                (stock.etfTopHoldings.isNotEmpty ||
                    stock.etfSectorWeights.isNotEmpty)) ...[
              const SizedBox(height: 24),
              if (stock.etfTopHoldings.isNotEmpty)
                _SimpleSection(
                  title: 'Top Holdings',
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: stock.etfTopHoldings.entries.take(10).map((
                            e,
                          ) {
                            final index = stock.etfTopHoldings.keys
                                .toList()
                                .indexOf(e.key);
                            return PieChartSectionData(
                              color: Colors
                                  .primaries[index % Colors.primaries.length],
                              value: e.value * 100,
                              title: e.key,
                              radius: 50,
                              titleStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...stock.etfTopHoldings.entries
                        .take(10)
                        .map(
                          (e) => _StatRow(
                            e.key,
                            '${FormatUtils.formatNumber(e.value * 100, decimalPlaces: 2)}%',
                          ),
                        ),
                  ],
                ),
              if (stock.etfSectorWeights.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SimpleSection(
                  title: 'Sector Exposure',
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: stock.etfSectorWeights.entries.map((e) {
                            final index = stock.etfSectorWeights.keys
                                .toList()
                                .indexOf(e.key);
                            return PieChartSectionData(
                              color:
                                  Colors.accents[index % Colors.accents.length],
                              value: e.value * 100,
                              title: '', // Keep clean, use legend below
                              radius: 50,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...stock.etfSectorWeights.entries.map(
                      (e) => _StatRow(
                        Stock.prettySectorName(e.key),
                        '${FormatUtils.formatNumber(e.value * 100, decimalPlaces: 2)}%',
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (stock.quantity > 0) ...[
              const SizedBox(height: 24),
              _SimpleSection(
                title: 'Your Holdings',
                children: [
                  _StatRow('Quantity', stock.quantity.toString()),
                  _StatRow(
                    'Avg Cost',
                    '${stock.currencySymbol}${FormatUtils.formatCurrency(stock.purchasePrice)}',
                  ),
                  _StatRow(
                    'Total Cost',
                    '${stock.currencySymbol}${FormatUtils.formatCurrency(stock.totalCost)}',
                  ),
                  _StatRow(
                    'Market Value',
                    '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(stock.totalValue, stock.currency))}',
                  ),
                  _StatRow(
                    'Total Return',
                    '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(stock.totalGainLoss, stock.currency))} (${FormatUtils.formatNumber(stock.totalGainLossPct, decimalPlaces: 1)}%)',
                    color: stock.totalGainLoss >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SimpleSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SimpleSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
