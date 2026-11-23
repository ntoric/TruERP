import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/products_repository.dart';

const _gstRates = [0.0, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0];

/// Create (no [productId]) or edit a product. Pops with the saved [Product].
class ProductFormScreen extends ConsumerWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productId == null) return const _ProductForm();
    return ref
        .watch(productDetailProvider(productId!))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Edit product')),
            body: const SkeletonList(count: 6),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit product')),
            body: ErrorView(
              error: e,
              onRetry: () => ref.invalidate(productDetailProvider(productId!)),
            ),
          ),
          data: (p) => _ProductForm(existing: p),
        );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.existing});
  final Product? existing;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final Product? _e = widget.existing;
  late final _name = TextEditingController(text: _e?.name);
  late final _itemCode = TextEditingController(text: _e?.itemCode);
  late final _sale = TextEditingController(
    text: NumberField.text(_e?.salePrice ?? 0),
  );
  late final _purchase = TextEditingController(
    text: NumberField.text(_e?.purchasePrice ?? 0),
  );
  late final _mrp = TextEditingController(text: NumberField.text(_e?.mrp ?? 0));
  late final _hsn = TextEditingController(text: _e?.hsnCode);
  late final _opening = TextEditingController();
  late final _minStock = TextEditingController(
    text: NumberField.text(_e?.minStock ?? 0),
  );
  late final _description = TextEditingController(text: _e?.description);
  late String _type = _e?.itemType ?? 'product';
  late String _unit = _e?.unit ?? 'PCS';
  late String _category = _e?.category ?? '';
  late double _tax = _e?.taxRate ?? 0;
  late bool _lowStockAlert = _e?.lowStockAlert ?? true;
  late bool _active = _e?.isActive ?? true;
  bool _busy = false;
  bool _genBusy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [
      _name,
      _itemCode,
      _sale,
      _purchase,
      _mrp,
      _hsn,
      _opening,
      _minStock,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() => _genBusy = true);
    try {
      _itemCode.text = await ref
          .read(productsRepositoryProvider)
          .generateItemCode();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _genBusy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_form.currentState!.validate()) return;
    final product = Product(
      id: _e?.id ?? '',
      name: _name.text,
      sku: _e?.sku ?? '',
      itemCode: _itemCode.text,
      category: _category,
      itemType: _type,
      unit: _unit,
      salePrice: NumberField.parse(_sale),
      purchasePrice: NumberField.parse(_purchase),
      mrp: NumberField.parse(_mrp),
      taxRate: _tax,
      hsnCode: _hsn.text,
      description: _description.text,
      minStock: _type == 'service' ? 0 : NumberField.parse(_minStock),
      lowStockAlert: _type != 'service' && _lowStockAlert,
      isActive: _active,
      imageUrl: _e?.imageUrl ?? '',
      enableBatching: _e?.enableBatching ?? false,
      salePriceWithTax: _e?.salePriceWithTax ?? true,
      purchasePriceWithTax: _e?.purchasePriceWithTax ?? true,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(productsRepositoryProvider);
      final saved = _e == null
          ? await repo.create(
              product,
              openingStock: _type == 'service'
                  ? 0
                  : NumberField.parse(_opening),
            )
          : await repo.update(_e.id, product);
      ref.read(dataRevisionProvider.notifier).bump();
      if (_e != null) ref.invalidate(productDetailProvider(_e.id));
      if (!mounted) return;
      showSnack(context, _e == null ? '${saved.name} added' : 'Changes saved');
      context.pop(saved);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.fields;
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final units =
        ref.watch(productUnitsProvider).asData?.value ??
        const ['PCS', 'KG', 'LTR', 'BOX'];
    final categories =
        ref.watch(productCategoriesProvider).asData?.value ?? const <String>[];
    final isService = _type == 'service';

    return Scaffold(
      appBar: AppBar(title: Text(_e == null ? 'New product' : 'Edit product')),
      bottomNavigationBar: SaveBar(
        label: _e == null ? 'Save product' : 'Save changes',
        busy: _busy,
        onPressed: _save,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ErrorBanner(_error!),
                  FormSection(
                    title: 'Basic details',
                    children: [
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'product',
                            icon: Icon(Icons.inventory_2_outlined),
                            label: Text('Product'),
                          ),
                          ButtonSegment(
                            value: 'service',
                            icon: Icon(Icons.handyman_outlined),
                            label: Text('Service'),
                          ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) =>
                            setState(() => _type = s.first),
                      ),
                      TextFormField(
                        controller: _name,
                        autofocus: _e == null,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          errorText: _fieldErrors['name'],
                        ),
                        validator: (v) => Validators.required(v, 'Name'),
                      ),
                      FieldRow(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _category.isEmpty ? '' : _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('None'),
                              ),
                              for (final c in {
                                ...categories,
                                if (_category.isNotEmpty) _category,
                              })
                                DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _category = v ?? ''),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _unit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: [
                              for (final u in {...units, _unit})
                                DropdownMenuItem(value: u, child: Text(u)),
                            ],
                            onChanged: (v) =>
                                setState(() => _unit = v ?? 'PCS'),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _itemCode,
                        decoration: InputDecoration(
                          labelText: 'Item code / barcode',
                          helperText: 'Leave blank to skip, or generate one',
                          errorText: _fieldErrors['item_code'],
                          suffixIcon: _genBusy
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Generate code',
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  onPressed: _generateCode,
                                ),
                        ),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Pricing',
                    children: [
                      FieldRow(
                        children: [
                          NumberField(
                            controller: _sale,
                            label: 'Sale price *',
                            validator: (v) => Validators.number(
                              v,
                              required: true,
                              field: 'Sale price',
                            ),
                          ),
                          NumberField(
                            controller: _purchase,
                            label: 'Purchase price',
                            validator: (v) =>
                                Validators.number(v, field: 'Purchase price'),
                          ),
                        ],
                      ),
                      FieldRow(
                        children: [
                          NumberField(
                            controller: _mrp,
                            label: 'MRP',
                            validator: (v) =>
                                Validators.number(v, field: 'MRP'),
                          ),
                          DropdownButtonFormField<double>(
                            initialValue: _gstRates.contains(_tax)
                                ? _tax
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'GST rate',
                            ),
                            items: [
                              for (final r in {..._gstRates, _tax})
                                DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r == 0
                                        ? 'None'
                                        : '${r % 1 == 0 ? r.toInt() : r}%',
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _tax = v ?? 0),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _hsn,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isService ? 'SAC code' : 'HSN code',
                        ),
                      ),
                    ],
                  ),
                  if (!isService)
                    FormSection(
                      title: 'Stock',
                      children: [
                        FieldRow(
                          children: [
                            if (_e == null)
                              NumberField(
                                controller: _opening,
                                label: 'Opening stock',
                                money: false,
                                suffix: _unit,
                                validator: (v) => Validators.number(
                                  v,
                                  field: 'Opening stock',
                                ),
                              ),
                            NumberField(
                              controller: _minStock,
                              label: 'Low stock at',
                              money: false,
                              suffix: _unit,
                              validator: (v) =>
                                  Validators.number(v, field: 'Minimum stock'),
                            ),
                          ],
                        ),
                        if (_e != null)
                          Text(
                            'Change stock levels with Adjust stock on the product page.',
                            style: context.text.bodySmall,
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Low stock alert'),
                          subtitle: const Text(
                            'Flag this item on the dashboard when stock runs low',
                          ),
                          value: _lowStockAlert,
                          onChanged: (v) => setState(() => _lowStockAlert = v),
                        ),
                      ],
                    ),
                  FormSection(
                    title: 'More',
                    children: [
                      TextFormField(
                        controller: _description,
                        maxLines: 3,
                        minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      if (_e != null)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active'),
                          subtitle: const Text(
                            'Inactive items are hidden from billing',
                          ),
                          value: _active,
                          onChanged: (v) => setState(() => _active = v),
                        ),
                    ],
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
