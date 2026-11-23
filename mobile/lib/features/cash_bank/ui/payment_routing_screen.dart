import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/cash_bank_repository.dart';

const _cash = '__cash__';

/// Which account each payment mode deposits into (Settings tab on the web).
class PaymentRoutingScreen extends ConsumerStatefulWidget {
  const PaymentRoutingScreen({super.key});

  @override
  ConsumerState<PaymentRoutingScreen> createState() => _State();
}

class _State extends ConsumerState<PaymentRoutingScreen> {
  Map<String, String>? _selected;
  bool _busy = false;

  Future<void> _save(List<PaymentRouting> rows) async {
    setState(() => _busy = true);
    try {
      await ref.read(cashBankRepositoryProvider).saveRouting({
        for (final r in rows.where((r) => !r.isOwnerEquity))
          r.method: _selected![r.method] == _cash ? null : _selected![r.method],
      });
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, 'Payment routing saved');
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routing = ref.watch(paymentRoutingProvider);
    final summary = ref.watch(cashBankSummaryProvider);
    final accounts =
        summary.asData?.value.accounts.where((a) => a.isActive).toList() ??
        const [];
    final rows = routing.asData?.value;
    if (rows != null && _selected == null) {
      _selected = {for (final r in rows) r.method: r.bankAccountId ?? _cash};
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Payment routing')),
      bottomNavigationBar: rows == null
          ? null
          : SaveBar(label: 'Save', busy: _busy, onPressed: () => _save(rows)),
      body: routing.when(
        loading: () => const SkeletonList(count: 5),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(paymentRoutingProvider),
        ),
        data: (rows) => ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose where money lands for each payment mode when no account is picked on the invoice or bill.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: r.isOwnerEquity
                          ? InputDecorator(
                              decoration: InputDecoration(
                                labelText: r.label,
                                helperText:
                                    'Opening stock and capital — no cash movement',
                              ),
                              child: const Text('Owner\'s equity'),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue:
                                  accounts.any(
                                        (a) => a.id == _selected![r.method],
                                      ) ||
                                      _selected![r.method] == _cash
                                  ? _selected![r.method]
                                  : _cash,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: r.label),
                              items: [
                                const DropdownMenuItem(
                                  value: _cash,
                                  child: Text('Cash in hand'),
                                ),
                                for (final a in accounts)
                                  DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.label),
                                  ),
                              ],
                              onChanged: (v) => setState(
                                () => _selected![r.method] = v ?? _cash,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
