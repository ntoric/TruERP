import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/party.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/line_items.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../../shared/widgets/pickers.dart';
import '../../products/data/products_repository.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import 'pos_sheets.dart';
import 'scanner_screen.dart';

const posAccent = Color(0xFF0284C7);

/// POS terminal: opens a session if none is active, otherwise the counter.
class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeSessionProvider);
    return async.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('POS')), body: const SkeletonList(count: 6)),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('POS')),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(activeSessionProvider)),
      ),
      data: (s) => s == null ? const _OpenSession() : _Counter(session: s),
    );
  }
}

// ── Open a session ──────────────────────────────────────────────────────

class _OpenSession extends ConsumerStatefulWidget {
  const _OpenSession();

  @override
  ConsumerState<_OpenSession> createState() => _OpenState();
}

class _OpenState extends ConsumerState<_OpenSession> {
  final _cash = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(posRepositoryProvider).openSession(NumberField.parse(_cash));
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          IconButton(tooltip: 'Session history', icon: const Icon(Icons.history_rounded), onPressed: () => context.push('/pos/sessions')),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: IconBadge(Icons.point_of_sale_rounded, color: posAccent, size: 72)),
              const SizedBox(height: Spacing.lg),
              Text('Start a billing session', style: context.text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Spacing.xs),
              Text('Count the cash in the drawer to begin.', style: context.text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: Spacing.xl),
              if (_error != null) ErrorBanner(_error!),
              NumberField(controller: _cash, label: 'Opening cash', autofocus: true, textInputAction: TextInputAction.done),
              const SizedBox(height: Spacing.lg),
              FilledButton.icon(
                onPressed: _busy ? null : _open,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Open session'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Counter ─────────────────────────────────────────────────────────────

class _Counter extends ConsumerStatefulWidget {
  const _Counter({required this.session});
  final PosSession session;

  @override
  ConsumerState<_Counter> createState() => _CounterState();
}

class _CounterState extends ConsumerState<_Counter> {
  final _cart = <CartLine>[];
  Party? _party;
  double _discount = 0;
  String _q = '';
  String? _category;

  int get _count => _cart.length;
  double get _total => posTotals(_cart, discount: _discount).total;

  void _add(Product p, [double qty = 1]) {
    HapticFeedback.selectionClick();
    setState(() {
      final line = _cart.where((l) => l.product.id == p.id).firstOrNull;
      if (line != null) {
        line.quantity += qty;
      } else {
        _cart.add(CartLine(product: p, quantity: qty));
      }
    });
  }

  void _clear() => setState(() {
        _cart.clear();
        _party = null;
        _discount = 0;
      });

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code == null || !mounted) return;
    try {
      final p = await ref.read(posRepositoryProvider).byCode(code);
      if (!mounted) return;
      if (p == null) {
        showSnack(context, 'No product with code $code', error: true);
      } else {
        _add(p);
        showSnack(context, 'Added ${p.name}');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _hold() async {
    if (_cart.isEmpty) return;
    final title = _party?.name ?? 'Bill ${TimeOfDay.now().format(context)}';
    try {
      await ref.read(posRepositoryProvider).hold(
            title: title,
            lines: _cart,
            partyId: _party?.id,
            sessionId: widget.session.id,
            discount: _discount,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      _clear();
      if (mounted) showSnack(context, 'Bill held as "$title"');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _resume() async {
    final bill = await showHeldBillsSheet(context);
    if (bill == null || !mounted) return;
    if (_cart.isNotEmpty) {
      final ok = await confirmSheet(context, title: 'Replace the current cart?', message: 'Hold it first if you want to keep it.', confirmLabel: 'Replace');
      if (!ok) return;
    }
    try {
      await ref.read(posRepositoryProvider).deleteHeld(bill.id);
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (_) {
      // Still resume locally; the held copy can be removed later.
    }
    setState(() {
      _cart
        ..clear()
        ..addAll(bill.lines);
      _discount = bill.discount;
      _party = null;
    });
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    final sold = await showCheckoutSheet(context, session: widget.session, lines: List.of(_cart), party: _party, discount: _discount);
    if (sold != null && mounted) {
      _clear();
      await showReceiptSheet(context, sold);
    }
  }

  Future<void> _openCart() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.85,
            child: _CartPanel(
              lines: _cart,
              party: _party,
              discount: _discount,
              onChanged: () {
                setState(() {});
                setSheet(() {});
              },
              onParty: (p) {
                setState(() => _party = p);
                setSheet(() {});
              },
              onDiscount: (d) {
                setState(() => _discount = d);
                setSheet(() {});
              },
              onHold: () {
                Navigator.pop(ctx);
                _hold();
              },
              onCharge: () {
                Navigator.pop(ctx);
                _checkout();
              },
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final s = widget.session;
    final held = ref.watch(heldBillsProvider).asData?.value.length ?? 0;
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final categories = ref.watch(productCategoriesProvider).asData?.value ?? const <String>[];
    final repo = ref.read(posRepositoryProvider);

    final products = PagedListView<Product>(
      resetKey: (_q, _category, rev, store),
      fetch: (page) => repo.products(page: page, search: _q, category: _category),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: SearchField(hint: 'Search or type a code', onChanged: (v) => setState(() => _q = v))),
            const SizedBox(width: Spacing.sm),
            IconButton.filled(tooltip: 'Scan barcode', onPressed: _scan, icon: const Icon(Icons.qr_code_scanner_rounded)),
          ]),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: Spacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ChoiceChip(label: const Text('All'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                for (final c in categories) ...[
                  const SizedBox(width: Spacing.sm),
                  ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = _category == c ? null : c)),
                ],
              ]),
            ),
          ],
        ]),
      ),
      empty: EmptyState(icon: Icons.search_off_rounded, title: _q.isEmpty ? 'No products yet' : 'Nothing matches "$_q"'),
      itemBuilder: (ctx, p, _) {
        final inCart = _cart.where((l) => l.product.id == p.id).firstOrNull?.quantity ?? 0;
        return ListTile(
          onTap: () => _add(p),
          leading: inCart > 0
              ? CircleAvatar(backgroundColor: posAccent, child: Text(qty(inCart), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))
              : const IconBadge(Icons.inventory_2_rounded, color: posAccent),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            [if (p.itemCode.isNotEmpty) p.itemCode, p.isService ? 'Service' : 'Stock ${qty(p.stockQty)}'].join(' · '),
            style: TextStyle(color: !p.isService && p.stockQty <= 0 ? StatusColors.danger : null),
          ),
          trailing: Text(money(p.salePrice), style: ctx.text.labelLarge),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Spacing.lg,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('POS'),
          Text('${s.totalInvoices} sales · ${moneyShort(s.totalSales)}', style: context.text.bodySmall),
        ]),
        actions: [
          IconButton(
            tooltip: 'Held bills',
            onPressed: _resume,
            icon: Badge(isLabelVisible: held > 0, label: Text('$held'), child: const Icon(Icons.pause_circle_outline_rounded)),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'in' || v == 'out') await showCashMovementSheet(context, s, cashIn: v == 'in');
              if (v == 'close' && context.mounted) await showCloseSessionSheet(context, s);
              if (v == 'history' && context.mounted) context.push('/pos/sessions');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'in', child: ListTile(leading: Icon(Icons.south_west_rounded), title: Text('Cash in'))),
              PopupMenuItem(value: 'out', child: ListTile(leading: Icon(Icons.north_east_rounded), title: Text('Cash out'))),
              PopupMenuItem(value: 'history', child: ListTile(leading: Icon(Icons.history_rounded), title: Text('Session history'))),
              PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.lock_outline_rounded), title: Text('Close session'))),
            ],
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : _CartBar(
              count: _count,
              total: _total,
              onOpen: _cart.isEmpty ? null : _openCart,
              onCharge: _cart.isEmpty ? null : _checkout,
            ),
      body: wide
          ? Row(children: [
              Expanded(flex: 3, child: products),
              VerticalDivider(width: 1, color: context.colors.outlineVariant),
              SizedBox(
                width: 400,
                child: _CartPanel(
                  lines: _cart,
                  party: _party,
                  discount: _discount,
                  onChanged: () => setState(() {}),
                  onParty: (p) => setState(() => _party = p),
                  onDiscount: (d) => setState(() => _discount = d),
                  onHold: _hold,
                  onCharge: _checkout,
                ),
              ),
            ])
          : products,
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.count, required this.total, required this.onOpen, required this.onCharge});
  final int count;
  final double total;
  final VoidCallback? onOpen;
  final VoidCallback? onCharge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(Radii.control),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Row(children: [
                    Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined)),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(count == 0 ? 'Cart is empty' : 'View cart', style: context.text.labelSmall),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(money(total), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            FilledButton.icon(onPressed: onCharge, icon: const Icon(Icons.currency_rupee_rounded), label: const Text('Charge')),
          ]),
        ),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({
    required this.lines,
    required this.party,
    required this.discount,
    required this.onChanged,
    required this.onParty,
    required this.onDiscount,
    required this.onHold,
    required this.onCharge,
  });

  final List<CartLine> lines;
  final Party? party;
  final double discount;
  final VoidCallback onChanged;
  final ValueChanged<Party?> onParty;
  final ValueChanged<double> onDiscount;
  final VoidCallback onHold;
  final VoidCallback onCharge;

  Future<void> _editDiscount(BuildContext context) async {
    final ctrl = TextEditingController(text: NumberField.text(discount));
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill discount'),
        content: NumberField(controller: ctrl, label: 'Amount', autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 0.0), child: const Text('Remove')),
          FilledButton(onPressed: () => Navigator.pop(ctx, NumberField.parse(ctrl)), child: const Text('Apply')),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) onDiscount(v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = posTotals(lines, discount: discount);
    return Column(children: [
      ListTile(
        leading: Icon(party == null ? Icons.person_outline_rounded : Icons.person_rounded),
        title: Text(party?.name ?? 'Walk-in customer'),
        subtitle: party == null ? const Text('Tap to choose a customer') : Text(party!.phone),
        trailing: party == null ? const Icon(Icons.chevron_right_rounded) : IconButton(onPressed: () => onParty(null), icon: const Icon(Icons.close_rounded)),
        onTap: () async {
          final p = await pickParty(context, type: 'customer');
          if (p != null) onParty(p);
        },
      ),
      const Divider(height: 1),
      Expanded(
        child: lines.isEmpty
            ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'Cart is empty', message: 'Tap products or scan a barcode to add them.')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                itemCount: lines.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: Spacing.lg),
                itemBuilder: (ctx, i) {
                  final l = lines[i];
                  return Dismissible(
                    key: ObjectKey(l),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: StatusColors.danger.withValues(alpha: 0.12),
                      padding: const EdgeInsets.only(right: Spacing.lg),
                      child: const Icon(Icons.delete_outline, color: StatusColors.danger),
                    ),
                    onDismissed: (_) {
                      lines.removeAt(i);
                      onChanged();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xs, Spacing.xs, Spacing.xs),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text('${money(l.price)} · ${money(l.total)}', style: ctx.text.bodySmall),
                          ]),
                        ),
                        QtyStepper(
                          value: l.quantity,
                          min: 0,
                          onChanged: (v) {
                            if (v <= 0) {
                              lines.removeAt(i);
                            } else {
                              l.quantity = v;
                            }
                            onChanged();
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
      Material(
        color: context.colors.surfaceContainerLow,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KeyValueRow('Items', '${lines.length} · ${qty(lines.fold<double>(0, (s, l) => s + l.quantity))} units'),
              KeyValueRow('Subtotal', money(t.subTotal)),
              InkWell(
                onTap: lines.isEmpty ? null : () => _editDiscount(context),
                child: KeyValueRow('Discount', discount > 0 ? '− ${money(discount)}' : 'Add', valueColor: context.colors.primary),
              ),
              if (t.roundOff.abs() >= 0.005) KeyValueRow('Round off', money(t.roundOff)),
              KeyValueRow('Total', money(t.total), bold: true),
              const SizedBox(height: Spacing.md),
              Row(children: [
                OutlinedButton.icon(onPressed: lines.isEmpty ? null : onHold, icon: const Icon(Icons.pause_rounded), label: const Text('Hold')),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: lines.isEmpty ? null : onCharge,
                    icon: const Icon(Icons.currency_rupee_rounded),
                    label: Text('Charge ${money(t.total)}'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// Validates a positive amount (shared by the POS sheets).
String? requiredAmount(String? v) => Validators.number(v, required: true, allowZero: false, field: 'Amount');
