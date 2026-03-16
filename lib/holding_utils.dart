import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'provider.dart';

Widget sheetHandle(ThemeData theme) => Center(
  child: Container(
    margin: const EdgeInsets.only(bottom: 12),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: theme.colorScheme.outlineVariant,
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

InputDecoration inputDeco(String label, String hint, IconData icon) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    );

void showBuyHoldingSheet(BuildContext context, Stock stock) {
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController(
    text: stock.currentPrice.toStringAsFixed(2),
  );
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sc) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(sc).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sheetHandle(theme),
          const SizedBox(height: 20),
          Text(
            'Buy ${stock.symbol}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add shares to move to your portfolio',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  decoration: inputDeco('Shares', '0', Icons.tag_rounded),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: priceCtrl,
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
              final price = double.tryParse(priceCtrl.text) ?? 0.0;
              if (qty > 0) {
                context.read<PortfolioProvider>().addSymbol(
                  stock.symbol,
                  quantity: qty,
                  purchasePrice: price,
                );
              }
              Navigator.pop(sc);
            },
            icon: const Icon(Icons.shopping_cart_rounded),
            label: const Text('Add to Portfolio'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showEditHoldingSheet(BuildContext context, Stock stock) {
  final qtyCtrl = TextEditingController(
    text: stock.quantity > 0 ? stock.quantity.toString() : '',
  );
  final priceCtrl = TextEditingController(
    text: stock.purchasePrice > 0 ? stock.purchasePrice.toStringAsFixed(2) : '',
  );
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sc) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(sc).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sheetHandle(theme),
          const SizedBox(height: 20),
          Text(
            'Edit ${stock.symbol}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (stock.companyName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stock.companyName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  decoration: inputDeco('Shares', '0', Icons.tag_rounded),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: priceCtrl,
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.read<PortfolioProvider>().editStock(
                stock.symbol,
                quantity: double.tryParse(qtyCtrl.text) ?? 0.0,
                purchasePrice: double.tryParse(priceCtrl.text) ?? 0.0,
              );
              Navigator.pop(sc);
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save Changes'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
