import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../core/router/modules.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/paged_list.dart';
import '../shell/account_sheet.dart';

/// Opens a module: its real route once built, otherwise the placeholder.
void openModule(BuildContext context, AppModule m) {
  if (m.phase <= builtPhase) {
    context.push(m.route);
  } else {
    context.push('/m/${m.id}');
  }
}

/// Every module, grouped like the web sidebar, with search.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final q = _q.toLowerCase();
    final groups = <(ModuleGroup, List<AppModule>)>[];
    for (final g in moduleGroups) {
      final mods = g.modules
          .where((m) => m.visibleTo(user))
          .where((m) =>
              q.isEmpty ||
              m.name.toLowerCase().contains(q) ||
              g.name.toLowerCase().contains(q) ||
              m.keywords.contains(q))
          .toList();
      if (mods.isNotEmpty) groups.add((g, mods));
    }
    final cols = Breakpoints.columns(context, compactCols: 3, mediumCols: 5, expandedCols: 6);

    return Scaffold(
      appBar: AppBar(title: const Text('All modules'), actions: const [AccountButton()]),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, Spacing.sm),
            sliver: SliverToBoxAdapter(
              child: SearchField(hint: 'Search modules', onChanged: (v) => setState(() => _q = v)),
            ),
          ),
          if (groups.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: Icons.search_off_rounded, title: 'No matching modules'),
            ),
          for (final (g, mods) in groups) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Icon(g.icon, size: 18, color: g.accent),
                    const SizedBox(width: Spacing.sm),
                    Text(g.name.toUpperCase(), style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              sliver: SliverGrid.count(
                crossAxisCount: cols,
                mainAxisSpacing: Spacing.sm,
                crossAxisSpacing: Spacing.sm,
                childAspectRatio: 0.98,
                children: [for (final m in mods) _ModuleTile(module: m, accent: g.accent)],
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.xxl)),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module, required this.accent});
  final AppModule module;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final soon = module.phase > builtPhase;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openModule(context, module),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconBadge(module.icon, color: soon ? accent.withValues(alpha: 0.55) : accent, size: 42),
              const SizedBox(height: Spacing.sm),
              Text(
                module.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: soon ? context.colors.onSurfaceVariant : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder for modules scheduled in a later roadmap phase.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  Widget build(BuildContext context) {
    final m = moduleById(moduleId);
    return Scaffold(
      appBar: AppBar(title: Text(m?.name ?? 'Coming soon')),
      body: EmptyState(
        icon: m?.icon ?? Icons.construction_rounded,
        title: '${m?.name ?? 'This module'} is on the way',
        message: m == null
            ? null
            : 'Scheduled for phase ${m.phase} of the mobile roadmap. '
                'Meanwhile you can use it from the TruERP web app.',
      ),
    );
  }
}
