import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/formatters.dart';

/// Titled group of form fields.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: context.text.titleSmall)),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: Spacing.md),
              ..._spaced(children),
            ],
          ),
        ),
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(height: Spacing.md));
      out.add(items[i]);
    }
    return out;
  }
}

/// Two fields side by side on wider screens, stacked on narrow phones.
class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children, this.breakpoint = 360});
  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < breakpoint) {
        return Column(children: FormSection._spaced(children));
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.md),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'));

/// Numeric field (₹ prefix by default) that parses to double.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.money = true,
    this.suffix,
    this.validator,
    this.onChanged,
    this.helper,
    this.autofocus = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool money;
  final String? suffix;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;

  static double parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  /// Text for a number without trailing ".0".
  static String text(num v) => v == 0 ? '' : qty(v).replaceAll(',', '');

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimal],
      textInputAction: textInputAction ?? TextInputAction.next,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixText: money ? '₹ ' : null,
        suffixText: suffix,
      ),
    );
  }
}

/// Read-only field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = false,
    this.firstDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(2015),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_rounded),
          suffixIcon: clearable && value != null
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => onChanged(null))
              : null,
        ),
        child: Text(value == null ? 'Not set' : dateText(value),
            style: value == null ? TextStyle(color: context.colors.onSurfaceVariant) : null),
      ),
    );
  }
}

/// Field-styled tile that opens a picker (party, product…).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.subtitle,
    this.icon = Icons.search_rounded,
    this.errorText,
  });

  final String label;
  final String? value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: value == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value!, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                  if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
                ],
              ),
      ),
    );
  }
}

/// Sticky bottom bar with the primary save action (and optional summary).
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.label, required this.onPressed, this.busy = false, this.leading});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.md),
          child: Row(
            children: [
              if (leading != null) ...[Expanded(child: leading!), const SizedBox(width: Spacing.md)],
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onPressed,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a required reason (cancellations). Returns null if dismissed.
Future<String?> askReason(BuildContext context, {required String title, String confirmLabel = 'Confirm'}) {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, MediaQuery.viewInsetsOf(ctx).bottom + Spacing.xl),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ctx.text.titleMedium),
            const SizedBox(height: Spacing.lg),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Reason', hintText: 'Why is this being cancelled?'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'A reason is required' : null,
            ),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: StatusColors.danger),
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
