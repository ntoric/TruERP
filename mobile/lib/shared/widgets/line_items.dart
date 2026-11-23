import 'package:flutter/material.dart';

import '../../core/models/line_item.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import 'common.dart';
import 'form_widgets.dart';

/// Editable list of line items with swipe-to-delete, quantity stepper and
/// add buttons. Used by invoices, purchase bills and purchase orders.
class LineItemsEditor extends StatelessWidget {
  const LineItemsEditor({
    super.key,
    required this.lines,
    required this.onChanged,
    required this.onAddProduct,
    this.onAddCustom,
    this.showTax = false,
    this.showDiscount = true,
    this.priceLabel = 'Price',
    this.emptyText = 'No items yet. Add products from your catalogue.',
  });

  final List<LineItem> lines;

  /// Called after any edit so the parent can recompute totals.
  final VoidCallback onChanged;
  final VoidCallback onAddProduct;
  final VoidCallback? onAddCustom;
  final bool showTax;
  final bool showDiscount;
  final String priceLabel;
  final String emptyText;

  Future<void> _edit(BuildContext context, LineItem line) async {
    final ok = await showLineEditor(
      context,
      line,
      showTax: showTax,
      showDiscount: showDiscount,
      priceLabel: priceLabel,
    );
    if (ok == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Text(emptyText, style: context.text.bodySmall),
          ),
        for (final (i, l) in lines.indexed)
          Dismissible(
            key: ObjectKey(l),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              padding: const EdgeInsets.only(right: Spacing.lg),
              decoration: BoxDecoration(
                color: StatusColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: StatusColors.danger,
              ),
            ),
            onDismissed: (_) {
              lines.removeAt(i);
              onChanged();
            },
            child: LineItemTile(
              line: l,
              showTax: showTax,
              onTap: () => _edit(context, l),
              onQty: (q) {
                l.quantity = q;
                onChanged();
              },
            ),
          ),
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Text(
              'Tap an item to edit · swipe left to remove',
              style: context.text.labelSmall,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Add item'),
              ),
            ),
            if (onAddCustom != null) ...[
              const SizedBox(width: Spacing.sm),
              OutlinedButton(
                onPressed: onAddCustom,
                child: const Text('Custom'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class LineItemTile extends StatelessWidget {
  const LineItemTile({
    super.key,
    required this.line,
    required this.onTap,
    required this.onQty,
    this.showTax = false,
  });
  final LineItem line;
  final VoidCallback onTap;
  final ValueChanged<double> onQty;
  final bool showTax;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final short = l.stockQty != null && l.quantity > l.stockQty!;
    final total = showTax ? l.net + l.taxAmount() : l.net;
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      color: context.colors.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.xs,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.description.isEmpty ? 'Item' : l.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      [
                        '${money(l.unitPrice)}${l.unit.isEmpty ? '' : ' / ${l.unit}'}',
                        if (l.discountPct > 0) '${qty(l.discountPct)}% off',
                        if (showTax && l.taxRate > 0) 'GST ${qty(l.taxRate)}%',
                      ].join(' · '),
                      style: context.text.bodySmall,
                    ),
                    if (short)
                      Text(
                        'Only ${qty(l.stockQty)} in stock',
                        style: context.text.labelSmall?.copyWith(
                          color: StatusColors.warning,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(money(total), style: context.text.titleSmall),
                  ],
                ),
              ),
              QtyStepper(value: l.quantity, onChanged: onQty),
            ],
          ),
        ),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
  });
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double? max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Decrease',
          onPressed: value - 1 >= min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Text(
            qty(value),
            textAlign: TextAlign.center,
            style: context.text.titleSmall,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Increase',
          onPressed: max == null || value + 1 <= max!
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}

const gstRates = [0.0, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0];

String gstLabel(double r) => r == 0 ? 'None' : '${r % 1 == 0 ? r.toInt() : r}%';

/// Bottom sheet to edit one line in place. Returns true when applied.
Future<bool?> showLineEditor(
  BuildContext context,
  LineItem line, {
  bool isNew = false,
  bool showTax = false,
  bool showDiscount = true,
  String priceLabel = 'Price',
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _LineEditor(
    line: line,
    isNew: isNew,
    showTax: showTax,
    showDiscount: showDiscount,
    priceLabel: priceLabel,
  ),
);

class _LineEditor extends StatefulWidget {
  const _LineEditor({
    required this.line,
    required this.isNew,
    required this.showTax,
    required this.showDiscount,
    required this.priceLabel,
  });

  final LineItem line;
  final bool isNew;
  final bool showTax;
  final bool showDiscount;
  final String priceLabel;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  final _form = GlobalKey<FormState>();
  late final _desc = TextEditingController(text: widget.line.description);
  late final _qty = TextEditingController(
    text: NumberField.text(widget.line.quantity),
  );
  late final _price = TextEditingController(
    text: NumberField.text(widget.line.unitPrice),
  );
  late final _disc = TextEditingController(
    text: NumberField.text(widget.line.discountPct),
  );
  late double _tax = widget.line.taxRate;

  @override
  void dispose() {
    for (final c in [_desc, _qty, _price, _disc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    widget.line
      ..description = _desc.text.trim()
      ..quantity = NumberField.parse(_qty)
      ..unitPrice = NumberField.parse(_price)
      ..discountPct = widget.showDiscount ? NumberField.parse(_disc) : 0
      ..taxRate = _tax;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final preview = LineItem(
      description: '',
      quantity: NumberField.parse(_qty),
      unitPrice: NumberField.parse(_price),
      discountPct: widget.showDiscount ? NumberField.parse(_disc) : 0,
      taxRate: _tax,
    );
    final total = widget.showTax
        ? preview.net + preview.taxAmount()
        : preview.net;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.xl,
        0,
        Spacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + Spacing.xl,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isNew ? 'Custom line' : 'Edit item',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                controller: _desc,
                autofocus: widget.isNew,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => Validators.required(v, 'Description'),
              ),
              const SizedBox(height: Spacing.md),
              FieldRow(
                breakpoint: 300,
                children: [
                  NumberField(
                    controller: _qty,
                    label: 'Quantity',
                    money: false,
                    suffix: widget.line.unit.isEmpty ? null : widget.line.unit,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => Validators.number(
                      v,
                      required: true,
                      allowZero: false,
                      field: 'Quantity',
                    ),
                  ),
                  NumberField(
                    controller: _price,
                    label: widget.priceLabel,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        Validators.number(v, required: true, field: 'Price'),
                  ),
                ],
              ),
              if (widget.showDiscount || widget.showTax)
                const SizedBox(height: Spacing.md),
              FieldRow(
                breakpoint: 300,
                children: [
                  if (widget.showDiscount)
                    NumberField(
                      controller: _disc,
                      label: 'Discount',
                      money: false,
                      suffix: '%',
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final e = Validators.number(v, field: 'Discount');
                        if (e != null) return e;
                        return (double.tryParse(v ?? '') ?? 0) > 100
                            ? 'Can\'t exceed 100%'
                            : null;
                      },
                    ),
                  if (widget.showTax)
                    DropdownButtonFormField<double>(
                      initialValue: _tax,
                      decoration: const InputDecoration(labelText: 'GST'),
                      items: [
                        for (final r in {...gstRates, _tax})
                          DropdownMenuItem(value: r, child: Text(gstLabel(r))),
                      ],
                      onChanged: (v) => setState(() => _tax = v ?? 0),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              KeyValueRow(
                widget.showTax ? 'Line total (incl. GST)' : 'Line total',
                money(total),
                bold: true,
              ),
              const SizedBox(height: Spacing.md),
              FilledButton(
                onPressed: _apply,
                child: Text(widget.isNew ? 'Add line' : 'Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
