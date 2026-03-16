import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'provider.dart';
import 'stock_detail_screen.dart';
import 'models.dart';
import 'holding_utils.dart';
import 'format_utils.dart';

// ─── Sort Bar ───────────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  const _SortBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) {
        return Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const _FilterButton(),
              const SizedBox(width: 8),
              VerticalDivider(
                width: 1,
                indent: 12,
                endIndent: 12,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              ...SortField.values.map((opt) {
                final isSelected = provider.sortField == opt;
                String labelText = opt.label;
                if (isSelected && opt != SortField.custom) {
                  labelText += provider.sortAscending ? ' ↑' : ' ↓';
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(labelText, style: TextStyle(fontSize: 12)),
                    onSelected: (_) => provider.setSortField(opt),
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) {
        final selectedFilters = provider.selectedTypeFilters;
        final isActive = !selectedFilters.contains('All');
        
        return PopupMenuButton<String>(
          tooltip: 'Filter Assets',
          offset: const Offset(0, 48),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive 
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: isActive 
                  ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 16,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? '${selectedFilters.length} Types' : 'Filter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          onSelected: (type) => provider.toggleTypeFilter(type),
          itemBuilder: (context) {
            final types = provider.availableTypes;
            return types.map((type) {
              final isSelected = selectedFilters.contains(type);
              return CheckedPopupMenuItem<String>(
                value: type,
                checked: isSelected,
                child: Text(type),
              );
            }).toList();
          },
        );
      },
    );
  }
}


// ─── Portfolio Page ──────────────────────────────────────────────────────

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) {
        final stocks = provider.portfolioStocks;

        if (provider.isLoading && stocks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (stocks.isEmpty) {
          return _EmptyState(
            icon: Icons.pie_chart_outline_rounded,
            title: 'No holdings yet',
            subtitle: 'Add stocks with a quantity to build your portfolio',
          );
        }

        return Column(
          children: [
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.error.isNotEmpty) _ErrorBanner(provider: provider),
            _PortfolioSummary(provider: provider),
            const _SortBar(),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.refreshPrices(),
                child: provider.sortField == SortField.custom
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        buildDefaultDragHandles: false,
                        itemCount: stocks.length,
                        proxyDecorator: (child, index, animation) => Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          shadowColor: Colors.black26,
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final stock = stocks[index];
                          return StockCard(
                            key: ValueKey(stock.symbol),
                            stock: stock,
                            index: index,
                            showHoldings: true,
                            showDragHandle: true,
                            onDelete: () => provider.removeSymbol(stock.symbol),
                            onEdit: () => showEditHoldingSheet(context, stock),
                          );
                        },
                        onReorder: (o, n) =>
                            provider.reorder(o, n, isPortfolio: true),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: stocks.length,
                        itemBuilder: (context, index) {
                          final stock = stocks[index];
                          return StockCard(
                            key: ValueKey(stock.symbol),
                            stock: stock,
                            index: index,
                            showHoldings: true,
                            showDragHandle: false,
                            onDelete: () => provider.removeSymbol(stock.symbol),
                            onEdit: () => showEditHoldingSheet(context, stock),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Watchlist Page ──────────────────────────────────────────────────────

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) {
        final stocks = provider.watchlistStocks;

        if (provider.isLoading && stocks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (stocks.isEmpty) {
          return _EmptyState(
            icon: Icons.visibility_outlined,
            title: 'Watchlist is empty',
            subtitle: 'Add stocks to track without buying',
          );
        }

        return Column(
          children: [
            if (provider.isLoading) const LinearProgressIndicator(),
            if (provider.error.isNotEmpty) _ErrorBanner(provider: provider),
            const _SortBar(),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.refreshPrices(),
                child: provider.sortField == SortField.custom
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        buildDefaultDragHandles: false,
                        itemCount: stocks.length,
                        proxyDecorator: (child, index, animation) => Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          shadowColor: Colors.black26,
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final stock = stocks[index];
                          return StockCard(
                            key: ValueKey(stock.symbol),
                            stock: stock,
                            index: index,
                            showHoldings: false,
                            showDragHandle: true,
                            onDelete: () => provider.removeSymbol(stock.symbol),
                            onEdit: () => showBuyHoldingSheet(context, stock),
                          );
                        },
                        onReorder: (o, n) =>
                            provider.reorder(o, n, isPortfolio: false),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: stocks.length,
                        itemBuilder: (context, index) {
                          final stock = stocks[index];
                          return StockCard(
                            key: ValueKey(stock.symbol),
                            stock: stock,
                            index: index,
                            showHoldings: false,
                            showDragHandle: false,
                            onDelete: () => provider.removeSymbol(stock.symbol),
                            onEdit: () => showBuyHoldingSheet(context, stock),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Insights Page ───────────────────────────────────────────────────────

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PortfolioProvider>(
      builder: (context, provider, child) {
        final portfolio = provider.portfolioStocks;
        final cs = provider.displayCurrencySymbol;

        if (portfolio.isEmpty) {
          return _EmptyState(
            icon: Icons.insights_outlined,
            title: 'No insights yet',
            subtitle: 'Add holdings to see portfolio breakdowns',
          );
        }

        final totalVal = provider.totalPortfolioValue;
        final items = [
          _overviewSection(provider, cs),
          _portfolioStatsSection(context, provider),
          _topHoldingsSection(provider, cs, totalVal),
          _allocationBySectorSection(provider, totalVal, cs),
          if (provider.allocationByType.length > 1)
            _allocationByTypeSection(provider, totalVal, cs),
          _allocationByCountrySection(provider, totalVal, cs),
          _allocationByExchangeSection(provider, totalVal, cs),
          _allocationByCurrencySection(provider, totalVal, cs),
        ];

        final isWide = MediaQuery.of(context).size.width > 900;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (isWide)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: items
                    .map(
                      (w) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 48) / 2,
                        child: w,
                      ),
                    )
                    .toList(),
              )
            else
              ...items.expand((w) => [w, const SizedBox(height: 12)]),
          ],
        );
      },
    );
  }

  Widget _overviewSection(PortfolioProvider provider, String cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'Overview'),
        _OverviewCard(provider: provider, cs: cs),
      ],
    );
  }

  Widget _topHoldingsSection(
    PortfolioProvider provider,
    String cs,
    double totalVal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'Top Holdings'),
        _TopHoldingsCard(provider: provider, cs: cs, totalVal: totalVal),
      ],
    );
  }

  Widget _allocationBySectorSection(
    PortfolioProvider provider,
    double totalVal,
    String cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'Sectors'),
        _BreakdownCard(
          data: provider.allocationBySector,
          totalVal: totalVal,
          cs: cs,
        ),
      ],
    );
  }

  Widget _allocationByTypeSection(
    PortfolioProvider provider,
    double totalVal,
    String cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'By Type'),
        _BreakdownCard(
          data: provider.allocationByType,
          totalVal: totalVal,
          cs: cs,
        ),
      ],
    );
  }

  Widget _portfolioStatsSection(
    BuildContext context,
    PortfolioProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'Portfolio Statistics'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _weightedStat(
                  context,
                  'Weighted Beta',
                  FormatUtils.formatNumber(
                    provider.weightedBeta,
                    decimalPlaces: 2,
                  ),
                  provider.weightedBeta > 1.1
                      ? Colors.orange.shade600
                      : provider.weightedBeta < 0.9
                      ? Colors.blue.shade600
                      : null,
                ),
                _weightedStat(
                  context,
                  'Weighted P/E',
                  FormatUtils.formatNumber(
                    provider.weightedPE,
                    decimalPlaces: 1,
                  ),
                  null,
                ),
                _weightedStat(
                  context,
                  'Weighted Yield',
                  '${FormatUtils.formatNumber(provider.weightedYield, decimalPlaces: 2)}%',
                  Colors.green.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _weightedStat(
    BuildContext context,
    String label,
    String value,
    Color? color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _allocationByCountrySection(
    PortfolioProvider provider,
    double totalVal,
    String cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'By Country'),
        _BreakdownCard(
          data: provider.allocationByCountry,
          totalVal: totalVal,
          cs: cs,
          useFlags: true,
        ),
      ],
    );
  }

  Widget _allocationByExchangeSection(
    PortfolioProvider provider,
    double totalVal,
    String cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'By Exchange'),
        _BreakdownCard(
          data: provider.allocationByExchange,
          totalVal: totalVal,
          cs: cs,
        ),
      ],
    );
  }

  Widget _allocationByCurrencySection(
    PortfolioProvider provider,
    double totalVal,
    String cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: 'By Currency'),
        _BreakdownCard(
          data: provider.allocationByCurrency,
          totalVal: totalVal,
          cs: cs,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final PortfolioProvider provider;
  final String cs;
  const _OverviewCard({required this.provider, required this.cs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final val = provider.totalPortfolioValue;
    final cost = provider.totalPortfolioCost;
    final gl = provider.totalPortfolioGainLoss;
    final pct = provider.totalPortfolioGainLossPct;
    final isPos = gl >= 0;
    final color = isPos ? Colors.green.shade600 : Colors.red.shade600;
    final sign = isPos ? '+' : '';

    final term = provider.selectedTerm;
    final termReturn = provider.selectedTermReturn;
    final termPct = provider.selectedTermReturnPct;
    final termPos = termReturn >= 0;
    final termColor = termPos ? Colors.green.shade600 : Colors.red.shade600;
    final termSign = termPos ? '+' : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _overviewRow(
              theme,
              'Total Value',
              '$cs${FormatUtils.formatCurrency(val)}',
            ),
            _overviewRow(
              theme,
              'Total Cost',
              '$cs${FormatUtils.formatCurrency(cost)}',
            ),
            _overviewRow(
              theme,
              'Total P&L',
              '$sign$cs${FormatUtils.formatCurrency(gl.abs())} ($sign${FormatUtils.formatNumber(pct, decimalPlaces: 2)}%)',
              valueColor: color,
            ),
            _overviewRow(
              theme,
              '${term.label} Return',
              '$termSign$cs${FormatUtils.formatCurrency(termReturn.abs())} ($termSign${FormatUtils.formatNumber(termPct, decimalPlaces: 2)}%)',
              valueColor: termColor,
            ),
            _overviewRow(
              theme,
              'Holdings',
              '${provider.holdingsCount} positions',
            ),
            _overviewRow(theme, 'Display Currency', provider.displayCurrency),
          ],
        ),
      ),
    );
  }

  Widget _overviewRow(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHoldingsCard extends StatelessWidget {
  final PortfolioProvider provider;
  final String cs;
  final double totalVal;
  const _TopHoldingsCard({
    required this.provider,
    required this.cs,
    required this.totalVal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...provider.portfolioStocks]
      ..sort((a, b) {
        final va = provider.convertToDisplay(a.totalValue, a.currency);
        final vb = provider.convertToDisplay(b.totalValue, b.currency);
        return vb.compareTo(va);
      });
    final top = sorted.take(10).toList(); // Show top 10

    final colors = _vibrantPalette(theme);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portfolio Concentration',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _InteractiveStackedBar(
              items: top.map((s) {
                final val = provider.convertToDisplay(s.totalValue, s.currency);
                return _BarItem(label: s.symbol, value: val);
              }).toList(),
              totalValue: totalVal,
              colors: colors,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: List.generate(top.length, (i) {
                final s = top[i];
                final val = provider.convertToDisplay(s.totalValue, s.currency);
                final pct = totalVal > 0 ? (val / totalVal * 100) : 0.0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors[i % colors.length],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${s.symbol} ${FormatUtils.formatNumber(pct, decimalPlaces: 1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  _BarItem({required this.label, required this.value});
}

class _InteractiveStackedBar extends StatefulWidget {
  final List<_BarItem> items;
  final double totalValue;
  final List<Color> colors;

  const _InteractiveStackedBar({
    required this.items,
    required this.totalValue,
    required this.colors,
  });

  @override
  State<_InteractiveStackedBar> createState() => _InteractiveStackedBarState();
}

class _InteractiveStackedBarState extends State<_InteractiveStackedBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 28, // Slightly taller for better interaction
        child: Row(
          children: List.generate(widget.items.length, (i) {
            final item = widget.items[i];
            final pct = widget.totalValue > 0
                ? (item.value / widget.totalValue)
                : 0.0;
            if (pct < 0.005) return const SizedBox.shrink();

            final isHovered = _hoveredIndex == i;
            final baseColor = widget.colors[i % widget.colors.length];

            return Expanded(
              flex: (pct * 1000).toInt(),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = i),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: Tooltip(
                  message:
                      '${item.label}: ${FormatUtils.formatNumber(pct * 100, decimalPlaces: 1)}%',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.symmetric(horizontal: isHovered ? 1 : 0),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? Color.lerp(baseColor, Colors.white, 0.2)
                          : baseColor,
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: baseColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BreakdownCard extends StatefulWidget {
  final Map<String, double> data;
  final double totalVal;
  final String cs;
  final bool useFlags;

  const _BreakdownCard({
    required this.data,
    required this.totalVal,
    required this.cs,
    this.useFlags = false,
  });

  @override
  State<_BreakdownCard> createState() => _BreakdownCardState();
}

class _BreakdownCardState extends State<_BreakdownCard> {
  int touchedIndex = -1;

  static const _flagEmoji = {
    'US': '\u{1F1FA}\u{1F1F8}',
    'CA': '\u{1F1E8}\u{1F1E6}',
    'GB': '\u{1F1EC}\u{1F1E7}',
    'DE': '\u{1F1E9}\u{1F1EA}',
    'FR': '\u{1F1EB}\u{1F1F7}',
    'JP': '\u{1F1EF}\u{1F1F5}',
    'HK': '\u{1F1ED}\u{1F1F0}',
    'CN': '\u{1F1E8}\u{1F1F3}',
    'IN': '\u{1F1EE}\u{1F1F3}',
    'AU': '\u{1F1E6}\u{1F1FA}',
    'SE': '\u{1F1F8}\u{1F1EA}',
    'KR': '\u{1F1F0}\u{1F1F7}',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Colors mapping
    final colors = _vibrantPalette(theme);
    if (sorted.isEmpty || widget.totalVal <= 0) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 24,
          runSpacing: 24,
          children: [
            SizedBox(
              height: 280,
              width: 280,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null ||
                            event is FlLongPressEnd ||
                            event is FlPanEndEvent) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!
                            .touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: List.generate(sorted.length, (i) {
                    final isTouched = i == touchedIndex;
                    final fontSize = isTouched ? 16.0 : 0.0;
                    final radius = isTouched ? 75.0 : 60.0;
                    final val = sorted[i].value;
                    final pct = val / widget.totalVal * 100;
                    final color = colors[i % colors.length];

                    return PieChartSectionData(
                      color: color,
                      value: val,
                      title:
                          '${FormatUtils.formatNumber(pct, decimalPlaces: 1)}%',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xffffffff),
                      ),
                      showTitle: isTouched,
                    );
                  }),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sorted.asMap().entries.map((em) {
                  final i = em.key;
                  final entry = em.value;
                  final color = colors[i % colors.length];
                  final isTouched = i == touchedIndex;
                  final pct = widget.totalVal > 0
                      ? (entry.value / widget.totalVal * 100)
                      : 0.0;
                  final label = widget.useFlags
                      ? '${_flagEmoji[entry.key] ?? ''} ${entry.key}'
                      : entry.key;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isTouched
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isTouched
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.8,
                                    ),
                            ),
                          ),
                        ),
                        Text(
                          '${FormatUtils.formatNumber(pct, decimalPlaces: 1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isTouched
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isTouched
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Stock Bottom Sheet with Autofill ─────────────────────────────

void showAddStockSheet(BuildContext context, {required bool isWatchlist}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sc) =>
        _AddStockSheetContent(sheetContext: sc, isWatchlist: isWatchlist),
  );
}

class _AddStockSheetContent extends StatefulWidget {
  final BuildContext sheetContext;
  final bool isWatchlist;

  const _AddStockSheetContent({
    required this.sheetContext,
    required this.isWatchlist,
  });

  @override
  State<_AddStockSheetContent> createState() => _AddStockSheetContentState();
}

class _AddStockSheetContentState extends State<_AddStockSheetContent> {
  final _symbolCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  List<TickerSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _symbolCtrl.addListener(_onSymbolChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _symbolCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onSymbolChanged() {
    _debounce?.cancel();
    final text = _symbolCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      final results = await context.read<PortfolioProvider>().searchTickers(
        text,
      );
      if (mounted) {
        setState(() {
          _suggestions = results;
          _searching = false;
        });
      }
    });
  }

  void _selectSuggestion(TickerSuggestion s) {
    _symbolCtrl.removeListener(_onSymbolChanged);
    _symbolCtrl.text = s.symbol;
    setState(() => _suggestions = []);
    _symbolCtrl.addListener(_onSymbolChanged);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(widget.sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sheetHandle(theme),
          const SizedBox(height: 20),
          Text(
            widget.isWatchlist ? 'Add to Watchlist' : 'Add Holding',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _symbolCtrl,
            decoration: InputDecoration(
              labelText: 'Ticker Symbol',
              hintText: 'Search e.g. AAPL, MSFT, VEQT.TO',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
          ),
          // Suggestions dropdown
          if (_suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final s = _suggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      s.symbol,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${s.name}${s.exchange.isNotEmpty ? ' \u2022 ${s.exchange}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: s.type.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.type,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _selectSuggestion(s),
                  );
                },
              ),
            ),
          if (!widget.isWatchlist) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    decoration: inputDeco('Shares', '0', Icons.tag_rounded),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    decoration: inputDeco(
                      'Avg. Cost',
                      '0.00',
                      Icons.attach_money_rounded,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final symbol = _symbolCtrl.text.trim();
              if (symbol.isNotEmpty) {
                final qty = widget.isWatchlist
                    ? 0.0
                    : (double.tryParse(_qtyCtrl.text) ?? 0.0);
                final price = widget.isWatchlist
                    ? 0.0
                    : (double.tryParse(_priceCtrl.text) ?? 0.0);
                context.read<PortfolioProvider>().addSymbol(
                  symbol,
                  quantity: qty,
                  purchasePrice: price,
                  watchlist: widget.isWatchlist,
                );
                Navigator.pop(widget.sheetContext);
              }
            },
            icon: Icon(
              widget.isWatchlist ? Icons.visibility_rounded : Icons.add_rounded,
            ),
            label: Text(widget.isWatchlist ? 'Watch' : 'Add to Portfolio'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final PortfolioProvider provider;
  const _ErrorBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.redAccent.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => provider.clearError(),
          ),
        ],
      ),
    );
  }
}

class _PortfolioSummary extends StatelessWidget {
  final PortfolioProvider provider;
  const _PortfolioSummary({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalVal = provider.totalPortfolioValue;
    final term = provider.selectedTerm;
    final showAllTime = provider.showAllTime;

    // Choose which return to show
    final displayReturn = showAllTime ? provider.totalPortfolioGainLoss : provider.selectedTermReturn;
    final displayPct = showAllTime ? provider.totalPortfolioGainLossPct : provider.selectedTermReturnPct;
    final label = showAllTime ? 'All Time' : term.label;

    if (totalVal <= 0) return const SizedBox.shrink();

    final isPos = displayReturn >= 0;
    final color = isPos ? Colors.green.shade600 : Colors.red.shade600;
    final sign = isPos ? '+' : '';
    final cs = provider.displayCurrencySymbol;

    return GestureDetector(
      onTap: () => provider.toggleShowAllTime(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Total Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Value',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$cs${FormatUtils.formatCurrency(totalVal)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            // Right: Return (Togglable)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 14,
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$sign$cs${FormatUtils.formatCurrency(displayReturn.abs())}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '$sign${FormatUtils.formatNumber(displayPct, decimalPlaces: 2)}%',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stock Card ──────────────────────────────────────────────────────────

class StockCard extends StatefulWidget {
  final Stock stock;
  final int index;
  final bool showHoldings;
  final bool showDragHandle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const StockCard({
    super.key,
    required this.stock,
    required this.index,
    required this.showHoldings,
    this.showDragHandle = true,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<PortfolioProvider>();
    final showAllTime = provider.showAllTime;
    final term = provider.selectedTerm;
    final displayReturnPct = showAllTime ? widget.stock.totalGainLossPct : widget.stock.getReturnPercent(term);
    final displayReturnValue = showAllTime ? widget.stock.totalGainLoss : widget.stock.getReturnValue(term);
    
    final isPositive = displayReturnPct >= 0;
    final changeColor = isPositive ? Colors.green.shade600 : Colors.red.shade600;
    final sign = isPositive ? '+' : '';
    final cs = provider.displayCurrencySymbol;
    final showH = widget.showHoldings && widget.stock.quantity > 0;
    final holdingValue = widget.stock.currentPrice * widget.stock.quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      color: theme.cardColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Info Area (Taps to Detail)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StockDetailScreen(stock: widget.stock),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Row(
                  children: [
                    if (widget.showDragHandle)
                      ReorderableDragStartListener(
                        index: widget.index,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: theme.colorScheme.outlineVariant,
                            size: 20,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.stock.symbol,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.stock.typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.stock.companyName.isNotEmpty
                                ? widget.stock.companyName
                                : widget.stock.symbol,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showH) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_formatQty(widget.stock.quantity)} @ ${widget.stock.currencySymbol}${FormatUtils.formatCurrency(widget.stock.purchasePrice)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Right: Value/Return Area (Taps to Toggle)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.toggleShowAllTime(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    showH 
                      ? '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(holdingValue, widget.stock.currency))}'
                      : '$cs${FormatUtils.formatCurrency(provider.convertToDisplay(widget.stock.currentPrice, widget.stock.currency))}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$sign${FormatUtils.formatNumber(displayReturnPct, decimalPlaces: 2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        if (showH)
                          Text(
                            '$sign$cs${FormatUtils.formatCurrency(provider.convertToDisplay(displayReturnValue, widget.stock.currency).abs())}',
                            style: TextStyle(
                              color: changeColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2);
  }
}

List<Color> _vibrantPalette(ThemeData theme) {
  return [
    theme.colorScheme.primary,
    Colors.green.shade500,
    Colors.indigo.shade500,
    Colors.orange.shade500,
    Colors.purple.shade500,
    Colors.red.shade400,
    Colors.teal.shade500,
    Colors.amber.shade500,
    Colors.cyan.shade500,
    Colors.pink.shade400,
    Colors.deepPurple.shade400,
    Colors.deepOrange.shade400,
  ];
}
