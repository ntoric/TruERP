import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/party.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/master_detail.dart';
import '../../../shared/widgets/paged_list.dart';
import '../../shell/account_sheet.dart';
import '../data/parties_repository.dart';
import 'party_detail_screen.dart';

const partiesAccent = Color(0xFF7C3AED);

class PartiesScreen extends ConsumerStatefulWidget {
  const PartiesScreen({super.key, this.initialType, this.initialBalance, this.isTab = false});

  /// customer | vendor | null (all)
  final String? initialType;

  /// to_collect | to_pay | null
  final String? initialBalance;
  final bool isTab;

  @override
  ConsumerState<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends ConsumerState<PartiesScreen> {
  late String? _type = widget.initialType;
  late String? _balance = widget.initialBalance;
  String _q = '';
  String? _selected;

  void _open(Party p) {
    if (MasterDetail.isSplit(context)) {
      setState(() => _selected = p.id);
    } else {
      context.push('/parties/${p.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rev = ref.watch(dataRevisionProvider);
    final store = ref.watch(activeStoreIdProvider);
    final repo = ref.read(partiesRepositoryProvider);
    final title = switch (_type) { 'customer' => 'Customers', 'vendor' => 'Vendors', _ => 'Parties' };

    final list = PagedListView<Party>(
      resetKey: (_type, _balance, _q, rev, store),
      fetch: (page) => repo.list(page: page, search: _q, type: _type, balance: _balance),
      header: _Header(
        type: _type,
        balance: _balance,
        onType: (t) => setState(() => _type = t),
        onBalance: (b) => setState(() => _balance = b),
        onSearch: (q) => setState(() => _q = q),
      ),
      empty: EmptyState(
        icon: Icons.groups_rounded,
        title: _q.isNotEmpty || _balance != null ? 'No matching parties' : 'No parties yet',
        message: _q.isEmpty && _balance == null ? 'Add your customers and vendors to start billing.' : null,
        action: _q.isEmpty && _balance == null
            ? FilledButton.icon(
                onPressed: () => context.push('/parties/new${_type == null ? '' : '?type=$_type'}'),
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Add party'),
              )
            : null,
      ),
      itemBuilder: (ctx, p, _) => PartyTile(party: p, selected: p.id == _selected, onTap: () => _open(p)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: !widget.isTab,
        actions: [if (widget.isTab) const AccountButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-party',
        onPressed: () => context.push('/parties/new${_type == null ? '' : '?type=$_type'}'),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Add party'),
      ),
      body: MasterDetail(
        list: list,
        detail: _selected == null
            ? null
            : PartyDetailScreen(
                key: ValueKey(_selected),
                partyId: _selected!,
                embedded: true,
                onDeleted: () => setState(() => _selected = null),
              ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.type,
    required this.balance,
    required this.onType,
    required this.onBalance,
    required this.onSearch,
  });

  final String? type;
  final String? balance;
  final ValueChanged<String?> onType;
  final ValueChanged<String?> onBalance;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final stats = ref.watch(partyStatsProvider).asData?.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _BalanceCard(
                  label: 'To collect',
                  amount: stats?.toCollect,
                  color: StatusColors.success,
                  icon: Icons.south_west_rounded,
                  selected: balance == 'to_collect',
                  onTap: () => onBalance(balance == 'to_collect' ? null : 'to_collect'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _BalanceCard(
                  label: 'To pay',
                  amount: stats?.toPay,
                  color: StatusColors.danger,
                  icon: Icons.north_east_rounded,
                  selected: balance == 'to_pay',
                  onTap: () => onBalance(balance == 'to_pay' ? null : 'to_pay'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: 'customer', label: Text('Customers')),
              ButtonSegment(value: 'vendor', label: Text('Vendors')),
            ],
            selected: {type},
            onSelectionChanged: (s) => onType(s.first),
          ),
          const SizedBox(height: Spacing.md),
          SearchField(hint: 'Search name, phone, GSTIN', onChanged: onSearch),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double? amount;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: selected ? color : context.colors.outlineVariant, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              IconBadge(icon, color: color, size: 34),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.text.bodySmall),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(amount == null ? '—' : moneyShort(amount),
                          style: context.text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row used by party lists and the dashboard.
class PartyTile extends StatelessWidget {
  const PartyTile({super.key, required this.party, required this.onTap, this.selected = false});
  final Party party;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = party;
    final sub = [
      if (p.isVendor) 'Vendor' else 'Customer',
      if (p.phone.isNotEmpty) p.phone,
      if (p.city.isNotEmpty) p.city,
    ].join(' · ');
    return ListTile(
      selected: selected,
      selectedTileColor: context.colors.primaryContainer.withValues(alpha: 0.5),
      onTap: onTap,
      leading: InitialsAvatar(p.name),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: p.balance.abs() < 0.005
          ? Text('Settled', style: context.text.labelSmall)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(p.balance.abs()),
                    style: context.text.labelLarge?.copyWith(
                      color: p.toCollect ? StatusColors.success : StatusColors.danger,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
                Text(p.toCollect ? 'to collect' : 'to pay', style: context.text.labelSmall),
              ],
            ),
    );
  }
}
