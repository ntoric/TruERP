import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/inventory.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/inventory_repository.dart';

const warehouseAccent = Color(0xFF64748B);

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(warehousesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Warehouses')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-warehouse',
        onPressed: () => context.push('/warehouses/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add warehouse'),
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(warehousesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.domain_rounded, title: 'No warehouses yet', message: 'Add the places where you keep stock.')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(warehousesProvider),
                child: ContentWidth(
                  maxWidth: 900,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: Spacing.sm, bottom: 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(indent: 72),
                    itemBuilder: (ctx, i) {
                      final w = list[i];
                      return ListTile(
                        onTap: () => context.push('/warehouses/${w.id}'),
                        leading: IconBadge(Icons.domain_rounded, color: w.isActive ? warehouseAccent : StatusColors.neutral),
                        title: Row(children: [
                          Flexible(child: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
                          if (w.isDefault) ...[const SizedBox(width: 6), const StatusChip('active', label: 'Default')],
                          if (!w.isActive) ...[const SizedBox(width: 6), const StatusChip('inactive', label: 'Inactive')],
                        ]),
                        subtitle: Text([w.code, if (w.place.isNotEmpty) w.place].join(' · ')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

final _warehouseStockProvider = FutureProvider.autoDispose.family<(List<WarehouseStockItem>, double), String>((ref, id) {
  ref.watch(dataRevisionProvider);
  return ref.watch(inventoryRepositoryProvider).warehouseStock(id);
});

class WarehouseDetailScreen extends ConsumerWidget {
  const WarehouseDetailScreen({super.key, required this.warehouseId});
  final String warehouseId;

  Future<void> _delete(BuildContext context, WidgetRef ref, Warehouse w) async {
    final ok = await confirmSheet(context,
        title: 'Delete ${w.name}?', message: 'Stock records for this warehouse stay in your history.', confirmLabel: 'Delete', destructive: true);
    if (!ok) return;
    try {
      await ref.read(inventoryRepositoryProvider).deleteWarehouse(w.id);
      ref.read(dataRevisionProvider.notifier).bump();
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(warehousesProvider).asData?.value.where((w) => w.id == warehouseId).firstOrNull;
    final stock = ref.watch(_warehouseStockProvider(warehouseId));
    return Scaffold(
      appBar: AppBar(
        title: Text(w?.name ?? 'Warehouse'),
        actions: [
          if (w != null) ...[
            IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/warehouses/${w.id}/edit')),
            if (!w.isDefault)
              IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, w)),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.xxl),
        children: [
          ContentWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (w != null)
                SectionCard(
                  title: 'Details',
                  child: Column(children: [
                    for (final r in <(String, String)>[
                      ('Code', w.code),
                      ('Address', [w.address, w.place, w.pincode].where((s) => s.isNotEmpty).join(', ')),
                      ('Contact', [w.contactPerson, w.contactPhone].where((s) => s.isNotEmpty).join(' · ')),
                      ('Email', w.contactEmail),
                      ('Notes', w.notes),
                    ].where((r) => r.$2.isNotEmpty))
                      KeyValueRow(r.$1, r.$2),
                  ]),
                ),
              const SizedBox(height: Spacing.lg),
              stock.when(
                loading: () => const SizedBox(height: 200, child: SkeletonList(count: 3)),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(_warehouseStockProvider(warehouseId))),
                data: (d) {
                  final (items, total) = d;
                  return SectionCard(
                    title: 'Stock (${items.length})',
                    trailing: Text(money(total), style: context.text.labelLarge),
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: items.isEmpty
                        ? const Padding(padding: EdgeInsets.all(Spacing.lg), child: Text('No stock in this warehouse.'))
                        : Column(children: [
                            for (final it in items.take(200))
                              ListTile(
                                dense: true,
                                title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('Cost ${money(it.cost)}'),
                                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(qty(it.qty), style: context.text.labelLarge),
                                  Text(moneyShort(it.value), style: context.text.labelSmall),
                                ]),
                              ),
                          ]),
                  );
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Create (no [warehouseId]) or edit a warehouse.
class WarehouseFormScreen extends ConsumerWidget {
  const WarehouseFormScreen({super.key, this.warehouseId});
  final String? warehouseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (warehouseId == null) return const _Form();
    return ref.watch(warehousesProvider).when(
          loading: () => Scaffold(appBar: AppBar(), body: const SkeletonList(count: 5)),
          error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e)),
          data: (list) {
            final w = list.where((w) => w.id == warehouseId).firstOrNull;
            return w == null
                ? Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off_rounded, title: 'Warehouse not found'))
                : _Form(existing: w);
          },
        );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({this.existing});
  final Warehouse? existing;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late final Warehouse? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.name);
  late final _code = TextEditingController(text: _e?.code);
  late final _address = TextEditingController(text: _e?.address);
  late final _city = TextEditingController(text: _e?.city);
  late final _state = TextEditingController(text: _e?.state);
  late final _pincode = TextEditingController(text: _e?.pincode);
  late final _person = TextEditingController(text: _e?.contactPerson);
  late final _phone = TextEditingController(text: _e?.contactPhone);
  late final _email = TextEditingController(text: _e?.contactEmail);
  late final _notes = TextEditingController(text: _e?.notes);
  late bool _active = _e?.isActive ?? true;
  late bool _default = _e?.isDefault ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _code, _address, _city, _state, _pincode, _person, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final w = Warehouse(
      id: _e?.id ?? '',
      name: _name.text,
      code: _code.text,
      address: _address.text,
      city: _city.text,
      state: _state.text,
      pincode: _pincode.text,
      contactPerson: _person.text,
      contactPhone: _phone.text,
      contactEmail: _email.text,
      notes: _notes.text,
      isActive: _active,
      isDefault: _default,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      _e == null ? await repo.createWarehouse(w) : await repo.updateWarehouse(_e.id, w);
      ref.read(dataRevisionProvider.notifier).bump();
      if (!mounted) return;
      showSnack(context, _e == null ? '${w.name} added' : 'Changes saved');
      context.pop();
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_e == null ? 'New warehouse' : 'Edit warehouse')),
      bottomNavigationBar: SaveBar(label: _e == null ? 'Add warehouse' : 'Save changes', busy: _busy, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) ErrorBanner(_error!),
                FormSection(title: 'Warehouse', children: [
                  FieldRow(children: [
                    TextFormField(
                      controller: _name,
                      autofocus: _e == null,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) => Validators.required(v, 'Name'),
                    ),
                    TextFormField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Code *', hintText: 'MAIN'),
                      validator: (v) => Validators.required(v, 'Code'),
                    ),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default warehouse'),
                    subtitle: const Text('Used when no warehouse is chosen'),
                    value: _default,
                    onChanged: (v) => setState(() => _default = v),
                  ),
                  if (_e != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                ]),
                FormSection(title: 'Address', children: [
                  TextFormField(controller: _address, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Address')),
                  FieldRow(children: [
                    TextFormField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City')),
                    TextFormField(controller: _state, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'State')),
                  ]),
                  TextFormField(controller: _pincode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode')),
                ]),
                FormSection(title: 'Contact', children: [
                  TextFormField(controller: _person, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Contact person')),
                  FieldRow(children: [
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: Validators.optionalPhone,
                    ),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: Validators.optionalEmail,
                    ),
                  ]),
                  TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
