import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/router/modules.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';
import '../../more/more_screen.dart';
import '../../shell/account_sheet.dart';

/// Home tab. Phase 0 shows the greeting, active store and quick actions;
/// Phase 1 adds the live KPI dashboard.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).asData?.value;
    final user = session?.user;
    final store = session?.activeStore;
    final canSwitch = session?.canSwitchStores ?? false;
    final quick = ['invoices', 'payment-in', 'parties', 'products', 'purchase-bills', 'expenses', 'pos', 'reports']
        .map(moduleById)
        .whereType<AppModule>()
        .toList();
    final cols = Breakpoints.columns(context, compactCols: 4, mediumCols: 4, expandedCols: 8);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Spacing.lg,
        title: InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: canSwitch ? () => showAccountSheet(context) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()}, ${user?.name.split(' ').first ?? ''}', style: context.text.titleMedium),
              if (store != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, size: 14, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(child: Text(store.name, style: context.text.bodySmall, overflow: TextOverflow.ellipsis)),
                    if (canSwitch)
                      Icon(Icons.expand_more_rounded, size: 16, color: context.colors.onSurfaceVariant),
                  ],
                ),
            ],
          ),
        ),
        actions: const [AccountButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          ContentWidth(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Quick actions',
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    mainAxisSpacing: Spacing.md,
                    childAspectRatio: 0.9,
                    children: [
                      for (final m in quick)
                        InkWell(
                          borderRadius: BorderRadius.circular(Radii.control),
                          onTap: () => openModule(context, m),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconBadge(m.icon, color: groupOf(m.id)!.accent, size: 46),
                              const SizedBox(height: 6),
                              Text(m.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurface)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
