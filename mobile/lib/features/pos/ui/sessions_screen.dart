import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../data/pos_models.dart';
import '../data/pos_repository.dart';
import 'pos_screen.dart';

final _sessionsProvider = FutureProvider.autoDispose<List<PosSession>>((ref) {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return ref.watch(posRepositoryProvider).sessions();
});

final _movementsProvider = FutureProvider.autoDispose.family<List<CashMovement>, String>(
    (ref, id) => ref.watch(posRepositoryProvider).movements(id));

class PosSessionsScreen extends ConsumerWidget {
  const PosSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('POS sessions')),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(_sessionsProvider)),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.history_rounded, title: 'No sessions yet')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(_sessionsProvider),
                child: ContentWidth(
                  maxWidth: 900,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(indent: 72),
                    itemBuilder: (ctx, i) {
                      final s = list[i];
                      final diff = s.isOpen ? 0.0 : s.closingCash - s.expectedCash;
                      return ListTile(
                        onTap: () => _show(context, s),
                        leading: IconBadge(s.isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: s.isOpen ? StatusColors.success : posAccent),
                        title: Text(dateTimeText(s.openedAt)),
                        subtitle: Text([
                          '${s.totalInvoices} sales',
                          if (!s.isOpen && s.closedAt != null) 'closed ${dateTimeText(s.closedAt)}',
                          if (diff.abs() >= 0.5) '${diff > 0 ? 'over' : 'short'} ${moneyShort(diff.abs())}',
                        ].join(' · ')),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(money(s.totalSales), style: ctx.text.labelLarge),
                          StatusChip(s.isOpen ? 'active' : 'closed', label: s.isOpen ? 'Open' : 'Closed'),
                        ]),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  void _show(BuildContext context, PosSession s) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Consumer(
          builder: (ctx, ref, _) {
            final moves = ref.watch(_movementsProvider(s.id));
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
                  children: [
                    Text('Session ${dateTimeText(s.openedAt)}', style: ctx.text.titleMedium),
                    const SizedBox(height: Spacing.md),
                    KeyValueRow('Opening cash', money(s.openingCash)),
                    KeyValueRow('Sales (${s.totalInvoices})', money(s.totalSales)),
                    if (s.totalReturns > 0) KeyValueRow('Returns', '− ${money(s.totalReturns)}'),
                    KeyValueRow('Cash in', money(s.cashIn)),
                    KeyValueRow('Cash out', '− ${money(s.cashOut)}'),
                    KeyValueRow('Expected (all cash)', money(s.expectedCash)),
                    if (!s.isOpen) KeyValueRow('Closing cash', money(s.closingCash), bold: true),
                    if (s.notes.isNotEmpty) KeyValueRow('Notes', s.notes),
                    const Divider(height: Spacing.xl),
                    Text('Cash movements', style: ctx.text.titleSmall),
                    moves.when(
                      loading: () => const Padding(padding: EdgeInsets.all(Spacing.md), child: LinearProgressIndicator()),
                      error: (e, _) => Text(errorMessage(e)),
                      data: (list) => list.isEmpty
                          ? const Padding(padding: EdgeInsets.only(top: Spacing.sm), child: Text('None.'))
                          : Column(children: [
                              for (final m in list)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(m.isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
                                      color: m.isIn ? StatusColors.success : StatusColors.danger),
                                  title: Text(m.reason.isEmpty ? (m.isIn ? 'Cash in' : 'Cash out') : m.reason),
                                  subtitle: Text(dateTimeText(m.at)),
                                  trailing: Text(money(m.amount)),
                                ),
                            ]),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
