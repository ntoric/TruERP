import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';

/// Shared frame for auth screens: brand panel beside the form on tablets,
/// logo above the form on phones.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final form = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xl,
            vertical: Spacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!wide) ...[
                  Center(child: Image.asset('assets/logo.png', height: 64)),
                  const SizedBox(height: Spacing.xl),
                ],
                Text(
                  title,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                child,
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: wide
          ? Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: form),
              ],
            )
          : form,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Brand.crimson600, Brand.crimson900],
        ),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset('assets/logo.png', height: 56),
          ),
          const SizedBox(height: 32),
          Text(
            'Run your business\nfrom anywhere.',
            style: context.text.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GST billing, inventory, payments and reports — synced with your TruERP account.',
            style: context.text.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user point the app at their own TruERP server.
Future<void> showServerSheet(BuildContext context, WidgetRef ref) async {
  final config = ref.read(appConfigProvider);
  final ctrl = TextEditingController(text: config.serverUrl);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.xl,
        0,
        Spacing.xl,
        MediaQuery.viewInsetsOf(ctx).bottom + Spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Server address', style: ctx.text.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            'The TruERP backend this app talks to. Example: https://erp.mybusiness.in',
            style: ctx.text.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              prefixIcon: Icon(Icons.dns_rounded),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ctrl.text = AppConfig.defaultServerUrl,
              child: const Text('Reset to default'),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          FilledButton(
            onPressed: () async {
              await config.setServerUrl(ctrl.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                showSnack(context, 'Server set to ${config.serverUrl}');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
}
