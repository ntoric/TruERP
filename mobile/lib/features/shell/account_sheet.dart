import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/common.dart';
import '../auth/ui/auth_layout.dart';

/// Profile avatar button for app bars; opens [showAccountSheet].
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: IconButton(
        tooltip: 'Account',
        onPressed: () => showAccountSheet(context),
        icon: InitialsAvatar(
          user?.name ?? '?',
          size: 34,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

Future<void> showAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AccountSheet(),
    );

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final themeMode = ref.watch(themeModeProvider);
    if (session == null) return const SizedBox.shrink();
    final user = session.user;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.lg,
          ),
          children: [
            Row(
              children: [
                InitialsAvatar(
                  user.name,
                  size: 52,
                  color: context.colors.primary,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: context.text.titleMedium),
                      Text(user.email, style: context.text.bodySmall),
                      const SizedBox(height: 4),
                      StatusChip('active', label: user.roleLabel),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xl),
            if (!session.canSwitchStores && session.activeStore != null) ...[
              Text('STORE', style: context.text.labelSmall),
              const SizedBox(height: Spacing.sm),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: Text(session.activeStore!.name),
                  subtitle: session.activeStore!.city.isEmpty
                      ? null
                      : Text(session.activeStore!.city),
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],
            if (session.canSwitchStores) ...[
              Text('SWITCH STORE', style: context.text.labelSmall),
              const SizedBox(height: Spacing.sm),
              Card(
                child: Column(
                  children: [
                    for (final s in session.stores)
                      ListTile(
                        leading: Icon(
                          Icons.storefront_rounded,
                          color: s.id == session.activeStoreId
                              ? context.colors.primary
                              : null,
                        ),
                        title: Text(s.name),
                        subtitle: s.city.isNotEmpty || s.code.isNotEmpty
                            ? Text(
                                [
                                  s.code,
                                  s.city,
                                ].where((e) => e.isNotEmpty).join(' · '),
                              )
                            : null,
                        trailing: s.id == session.activeStoreId
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.colors.primary,
                              )
                            : null,
                        onTap: () async {
                          await ref
                              .read(sessionProvider.notifier)
                              .switchStore(s.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            showSnack(context, 'Switched to ${s.name}');
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],
            Text('APPEARANCE', style: context.text.labelSmall),
            const SizedBox(height: Spacing.sm),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
            const SizedBox(height: Spacing.lg),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('Server'),
                    subtitle: Text(
                      ref.read(appConfigProvider).serverUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => showServerSheet(context, ref),
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: StatusColors.danger,
                    ),
                    title: const Text(
                      'Sign out',
                      style: TextStyle(color: StatusColors.danger),
                    ),
                    onTap: () async {
                      final ok = await confirmSheet(
                        context,
                        title: 'Sign out?',
                        message: 'You\'ll need your password to sign back in.',
                        confirmLabel: 'Sign out',
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;
                      Navigator.pop(context);
                      await ref.read(sessionProvider.notifier).logout();
                    },
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
