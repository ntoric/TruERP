import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/money.dart';
import '../../../core/models/payment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/doc_widgets.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../payments/data/payments_repository.dart';
import '../data/profit_repository.dart';

const profitAccent = Color(0xFF65A30D);

/// The endpoint is unpaginated, so load everything once and total it here.
final _distributionsProvider = FutureProvider.autoDispose<List<ProfitDistribution>>((ref) async {
  ref.watch(activeStoreIdProvider);
  ref.watch(dataRevisionProvider);
  return (await ref.watch(profitRepositoryProvider).distributions()).items;
});

class ProfitDistributionScreen extends ConsumerStatefulWidget {
  const ProfitDistributionScreen({super.key});

  @override
  ConsumerState<ProfitDistributionScreen> createState() => _State();
}

class _State extends ConsumerState<ProfitDistributionScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  String? _partnerFilter;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPartners = _tabs.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit distribution'),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Payouts'), Tab(text: 'Partners')]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'profit-fab',
        onPressed: () => onPartners ? showPartnerSheet(context) : context.push('/profit-distribution/new'),
        icon: Icon(onPartners ? Icons.person_add_alt_rounded : Icons.add_rounded),
        label: Text(onPartners ? 'Add partner' : 'New payout'),
      ),
      body: TabBarView(controller: _tabs, children: [
        _Payouts(filter: _partnerFilter, onFilter: (id) => setState(() => _partnerFilter = id)),
        const _Partners(),
      ]),
    );
  }
}

class _Payouts extends ConsumerWidget {
  const _Payouts({required this.filter, required this.onFilter});
  final String? filter;
  final ValueChanged<String?> onFilter;

  Future<void> _delete(BuildContext context, WidgetRef ref, ProfitDistribution d) async {
    final ok = await confirmSheet(context,
        title: 'Delete ${d.number}?',
        message: '${money(d.amount)} to ${d.partner?.name ?? 'partner'}. The money goes back to ${d.accountLabel ?? 'cash in hand'}.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(profitRepositoryProvider).delete(d.id);
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_distributionsProvider);
    final partners = ref.watch(partnersProvider).asData?.value ?? const <Partner>[];
    return async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(_distributionsProvider)),
      data: (all) {
        final list = filter == null ? all : all.where((d) => d.partner?.id == filter).toList();
        final total = list.fold<double>(0, (s, d) => s + d.amount);
        final thisYear = list.where((d) => d.date?.year == DateTime.now().year).fold<double>(0, (s, d) => s + d.amount);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_distributionsProvider),
          child: ContentWidth(
            maxWidth: 900,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SummaryStrip(cells: [
                      ('Total paid out (${list.length})', total, profitAccent),
                      ('This year', thisYear, null),
                    ]),
                    if (partners.length > 1) ...[
                      const SizedBox(height: Spacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          ChoiceChip(label: const Text('All'), selected: filter == null, onSelected: (_) => onFilter(null)),
                          for (final p in partners) ...[
                            const SizedBox(width: Spacing.sm),
                            ChoiceChip(
                              label: Text(p.name),
                              selected: filter == p.id,
                              onSelected: (_) => onFilter(filter == p.id ? null : p.id),
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ]),
                ),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Spacing.xxl),
                    child: EmptyState(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'No payouts yet',
                      message: 'Record profit paid out to partners from cash or a bank account.',
                    ),
                  ),
                for (final d in list)
                  ListTile(
                    onLongPress: () => _delete(context, ref, d),
                    leading: InitialsAvatar(d.partner?.name ?? '?'),
                    title: Text(d.partner?.name ?? 'Partner', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text([d.number, relativeDay(d.date), d.accountLabel ?? 'Cash in hand',
                      if (d.description.isNotEmpty) d.description].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(money(d.amount), style: context.text.labelLarge),
                  ),
                if (list.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Spacing.lg),
                    child: Text('Long-press a payout to delete it.', style: context.text.labelSmall, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Partners extends ConsumerWidget {
  const _Partners();

  Future<void> _delete(BuildContext context, WidgetRef ref, Partner p) async {
    final ok = await confirmSheet(context,
        title: 'Delete ${p.name}?',
        message: 'Partners with payouts can\'t be deleted — mark them inactive instead.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(profitRepositoryProvider).deletePartner(p.id);
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partners = ref.watch(partnersProvider);
    final payouts = ref.watch(_distributionsProvider).asData?.value ?? const <ProfitDistribution>[];
    final totals = <String, double>{};
    for (final d in payouts) {
      final id = d.partner?.id;
      if (id != null) totals[id] = (totals[id] ?? 0) + d.amount;
    }
    return partners.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(partnersProvider)),
      data: (list) => list.isEmpty
          ? const EmptyState(icon: Icons.handshake_outlined, title: 'No partners yet', message: 'Add the partners you share profit with.')
          : ContentWidth(
              maxWidth: 900,
              child: ListView.separated(
                padding: const EdgeInsets.only(top: Spacing.sm, bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(indent: 72),
                itemBuilder: (ctx, i) {
                  final p = list[i];
                  return ListTile(
                    onTap: () => showPartnerSheet(context, existing: p),
                    leading: InitialsAvatar(p.name, color: p.isActive ? null : StatusColors.neutral),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text([if (!p.isActive) 'Inactive', if (p.phone.isNotEmpty) p.phone, if (p.pan.isNotEmpty) 'PAN ${p.pan}']
                        .join(' · ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(money(totals[p.id] ?? 0), style: ctx.text.labelLarge),
                          Text('paid out', style: ctx.text.labelSmall),
                        ],
                      ),
                      IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, p)),
                    ]),
                  );
                },
              ),
            ),
    );
  }
}

/// Add or edit a partner.
Future<void> showPartnerSheet(BuildContext context, {Partner? existing}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PartnerSheet(existing: existing),
    );

class _PartnerSheet extends ConsumerStatefulWidget {
  const _PartnerSheet({this.existing});
  final Partner? existing;

  @override
  ConsumerState<_PartnerSheet> createState() => _PartnerSheetState();
}

class _PartnerSheetState extends ConsumerState<_PartnerSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _pan = TextEditingController(text: widget.existing?.pan);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late bool _active = widget.existing?.isActive ?? true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pan, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final p = Partner(
      id: widget.existing?.id ?? '',
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      pan: _pan.text,
      address: _address.text,
      notes: _notes.text,
      isActive: _active,
    );
    setState(() => _busy = true);
    try {
      final repo = ref.read(profitRepositoryProvider);
      widget.existing == null ? await repo.createPartner(p) : await repo.updatePartner(widget.existing!.id, p);
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(context).bottom + Spacing.xl),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.existing == null ? 'New partner' : 'Edit partner', style: context.text.titleMedium),
            const SizedBox(height: Spacing.lg),
            if (_error != null) ErrorBanner(_error!),
            TextFormField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => Validators.required(v, 'Name'),
            ),
            const SizedBox(height: Spacing.md),
            FieldRow(children: [
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: Validators.optionalPhone,
              ),
              TextFormField(
                controller: _pan,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'PAN', counterText: ''),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.optionalEmail,
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: Spacing.md),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
            if (widget.existing != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: Spacing.lg),
            FilledButton(onPressed: _busy ? null : _save, child: Text(widget.existing == null ? 'Add partner' : 'Save')),
          ]),
        ),
      ),
    );
  }
}

/// Record a payout to a partner.
class ProfitPayoutFormScreen extends ConsumerStatefulWidget {
  const ProfitPayoutFormScreen({super.key});

  @override
  ConsumerState<ProfitPayoutFormScreen> createState() => _PayoutState();
}

const _cash = '__cash__';

class _PayoutState extends ConsumerState<ProfitPayoutFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _partnerId;
  String _account = _cash;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_amount, _description, _reference, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await ref.read(profitRepositoryProvider).create(
            partnerId: _partnerId!,
            amount: NumberField.parse(_amount),
            date: _date,
            accountId: _account == _cash ? null : _account,
            description: _description.text,
            reference: _reference.text,
            notes: _notes.text,
          );
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, '${d.number.isEmpty ? 'Payout' : d.number} of ${money(d.amount)} saved');
      context.pop();
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(partnersProvider).asData?.value.where((p) => p.isActive).toList() ?? const <Partner>[];
    final banks = ref.watch(bankAccountsProvider).asData?.value ?? const <BankAccount>[];
    final bank = banks.where((b) => b.id == _account).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('New payout')),
      bottomNavigationBar: SaveBar(label: 'Save payout', busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) ErrorBanner(_error!),
                FormSection(title: 'Payout', children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _partnerId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Partner *'),
                        items: [for (final p in partners) DropdownMenuItem(value: p.id, child: Text(p.name))],
                        onChanged: (v) => setState(() => _partnerId = v),
                        validator: (v) => v == null ? 'Choose a partner' : null,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    IconButton.filledTonal(
                      tooltip: 'New partner',
                      onPressed: () => showPartnerSheet(context),
                      icon: const Icon(Icons.person_add_alt_rounded),
                    ),
                  ]),
                  FieldRow(children: [
                    NumberField(
                      controller: _amount,
                      label: 'Amount *',
                      validator: (v) {
                        final e = Validators.number(v, required: true, allowZero: false, field: 'Amount');
                        if (e != null) return e;
                        // The server refuses payouts above a bank account's balance.
                        if (bank != null && (double.tryParse(v!) ?? 0) > bank.balance) return 'Only ${money(bank.balance)} available';
                        return null;
                      },
                    ),
                    DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
                  ]),
                  DropdownButtonFormField<String>(
                    initialValue: _account,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Paid from',
                      helperText: bank == null ? null : 'Balance ${money(bank.balance)}',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: _cash, child: Text('Cash in hand')),
                      for (final b in banks) DropdownMenuItem(value: b.id, child: Text(b.label)),
                    ],
                    onChanged: (v) => setState(() => _account = v ?? _cash),
                  ),
                ]),
                FormSection(title: 'More', children: [
                  TextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Q3 profit share'),
                  ),
                  TextFormField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference')),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
