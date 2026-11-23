import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/data/indian_states.dart';
import '../../../core/models/party.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/parties_repository.dart';

/// Create (no [partyId]) or edit a party. Pops with the saved [Party].
class PartyFormScreen extends ConsumerWidget {
  const PartyFormScreen({super.key, this.partyId, this.initialType});
  final String? partyId;
  final String? initialType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (partyId == null) return _PartyForm(initialType: initialType);
    return ref
        .watch(partyProvider(partyId!))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Edit party')),
            body: const SkeletonList(count: 6),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit party')),
            body: ErrorView(
              error: e,
              onRetry: () => ref.invalidate(partyProvider(partyId!)),
            ),
          ),
          data: (p) => _PartyForm(existing: p),
        );
  }
}

class _PartyForm extends ConsumerStatefulWidget {
  const _PartyForm({this.existing, this.initialType});
  final Party? existing;
  final String? initialType;

  @override
  ConsumerState<_PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends ConsumerState<_PartyForm> {
  final _form = GlobalKey<FormState>();
  late final Party? _e = widget.existing;
  late String _type =
      _e?.partyType ?? (widget.initialType == 'vendor' ? 'vendor' : 'customer');
  late final _name = TextEditingController(text: _e?.name);
  late final _phone = TextEditingController(text: _e?.phone);
  late final _email = TextEditingController(text: _e?.email);
  late final _gstin = TextEditingController(text: _e?.gstin);
  late final _pan = TextEditingController(text: _e?.pan);
  late final _address = TextEditingController(text: _e?.address);
  late final _city = TextEditingController(text: _e?.city);
  late final _pincode = TextEditingController(text: _e?.pincode);
  late final _notes = TextEditingController(text: _e?.notes);
  late final _opening = TextEditingController(
    text: NumberField.text((_e?.openingBalance ?? 0).abs()),
  );
  late final _creditLimit = TextEditingController(
    text: NumberField.text(_e?.creditLimit ?? 0),
  );
  late String? _state = (_e?.state.isEmpty ?? true) ? null : _e!.state;
  late String _category = _e?.category ?? '';

  /// true = they owe us (positive balance).
  late bool _theyOwe = (_e?.openingBalance ?? 0) >= 0;
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _gstin,
      _pan,
      _address,
      _city,
      _pincode,
      _notes,
      _opening,
      _creditLimit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _fieldErrors = const {});
    if (!_form.currentState!.validate()) return;
    final opening = NumberField.parse(_opening);
    final party = Party(
      id: _e?.id ?? '',
      name: _name.text,
      partyType: _type,
      phone: _phone.text,
      email: _email.text,
      gstin: _gstin.text,
      pan: _pan.text,
      tan: _e?.tan ?? '',
      address: _address.text,
      city: _city.text,
      state: _state ?? '',
      stateCode: _state == null ? '' : stateCodeFor(_state!) ?? '',
      pincode: _pincode.text,
      category: _category,
      openingBalance: _theyOwe ? opening : -opening,
      creditLimit: NumberField.parse(_creditLimit),
      notes: _notes.text,
      isActive: _e?.isActive ?? true,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(partiesRepositoryProvider);
      final saved = _e == null
          ? await repo.create(party)
          : await repo.update(_e.id, party);
      ref.read(dataRevisionProvider.notifier).bump();
      if (_e != null) ref.invalidate(partyProvider(_e.id));
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
    final categories =
        ref.watch(partyCategoriesProvider).asData?.value ??
        const ['Retail', 'Wholesale'];
    return Scaffold(
      appBar: AppBar(title: Text(_e == null ? 'New party' : 'Edit party')),
      bottomNavigationBar: SaveBar(
        label: _e == null ? 'Save party' : 'Save changes',
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
                            value: 'customer',
                            icon: Icon(Icons.person_rounded),
                            label: Text('Customer'),
                          ),
                          ButtonSegment(
                            value: 'vendor',
                            icon: Icon(Icons.factory_rounded),
                            label: Text('Vendor'),
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
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              errorText: _fieldErrors['phone'],
                            ),
                            validator: Validators.optionalPhone,
                          ),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              errorText: _fieldErrors['email'],
                            ),
                            validator: Validators.optionalEmail,
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        // Items always include the current category, so it can be preselected.
                        initialValue: _category.isEmpty ? null : _category,
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
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _category = v ?? ''),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Balance',
                    children: [
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: true,
                            label: Text(
                              _type == 'vendor' ? 'They owe you' : 'To collect',
                            ),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text(
                              _type == 'vendor' ? 'To pay' : 'You owe them',
                            ),
                          ),
                        ],
                        selected: {_theyOwe},
                        onSelectionChanged: (s) =>
                            setState(() => _theyOwe = s.first),
                      ),
                      FieldRow(
                        children: [
                          NumberField(
                            controller: _opening,
                            label: 'Opening balance',
                            validator: (v) =>
                                Validators.number(v, field: 'Opening balance'),
                          ),
                          NumberField(
                            controller: _creditLimit,
                            label: 'Credit limit',
                            validator: (v) =>
                                Validators.number(v, field: 'Credit limit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Tax details',
                    children: [
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _gstin,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 15,
                            decoration: InputDecoration(
                              labelText: 'GSTIN',
                              counterText: '',
                              errorText: _fieldErrors['gstin'],
                            ),
                            validator: Validators.optionalGstin,
                            onChanged: (v) {
                              // GSTIN starts with the state code; prefill state when empty.
                              if (v.length >= 2 && _state == null) {
                                final code = v.substring(0, 2);
                                for (final s in indianStates) {
                                  if (s.code == code) {
                                    setState(() => _state = s.name);
                                  }
                                }
                              }
                            },
                          ),
                          TextFormField(
                            controller: _pan,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'PAN',
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Address',
                    children: [
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Street address',
                        ),
                      ),
                      FieldRow(
                        children: [
                          TextFormField(
                            controller: _city,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'City',
                            ),
                          ),
                          TextFormField(
                            controller: _pincode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Pincode',
                              counterText: '',
                            ),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _state,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'State'),
                        items: [
                          // Keep a legacy/free-text state selectable instead of crashing the dropdown.
                          if (_state != null &&
                              indianStates.every((s) => s.name != _state))
                            DropdownMenuItem(
                              value: _state,
                              child: Text(_state!),
                            ),
                          for (final s in indianStates)
                            DropdownMenuItem(
                              value: s.name,
                              child: Text('${s.name} (${s.code})'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _state = v),
                      ),
                    ],
                  ),
                  FormSection(
                    title: 'Notes',
                    children: [
                      TextFormField(
                        controller: _notes,
                        maxLines: 3,
                        minLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText:
                              'Anything worth remembering about this party',
                        ),
                      ),
                    ],
                  ),
                  Text('* Required', style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
