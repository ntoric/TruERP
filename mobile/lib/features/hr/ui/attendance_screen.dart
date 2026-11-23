import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/revision.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/models/hr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../data/hr_repository.dart';
import 'hr_widgets.dart';

final _dayProvider = FutureProvider.autoDispose
    .family<List<Attendance>, DateTime>((ref, day) {
      ref.watch(activeStoreIdProvider);
      ref.watch(dataRevisionProvider);
      return ref.watch(hrRepositoryProvider).attendance(from: day, to: day);
    });

Color attendanceColor(String status) => switch (status) {
  AttendanceStatus.present => StatusColors.success,
  AttendanceStatus.absent => StatusColors.danger,
  AttendanceStatus.halfDay => StatusColors.warning,
  AttendanceStatus.paidLeave => StatusColors.info,
  _ => StatusColors.neutral,
};

/// Daily roll call: one row per active staff member, saved in one go.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _State();
}

class _State extends ConsumerState<AttendanceScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  /// Local edits for [_day], on top of what's saved.
  final _edits = <String, String>{};
  bool _busy = false;

  bool get _isToday => DateUtils.isSameDay(_day, DateTime.now());

  void _go(DateTime d) => setState(() {
    _day = d;
    _edits.clear();
  });

  Future<void> _save(Map<String, String> statuses) async {
    if (statuses.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(hrRepositoryProvider).markBulk(_day, statuses);
      ref.read(dataRevisionProvider.notifier).bump();
      _edits.clear();
      if (mounted) {
        showSnack(context, 'Attendance saved for ${statuses.length} staff');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffListProvider);
    final day = ref.watch(_dayProvider(_day));
    final saved = {
      for (final a in day.asData?.value ?? const <Attendance>[])
        a.staffId: a.status,
    };
    final active =
        staff.asData?.value.where((s) => s.isActive).toList() ??
        const <Staff>[];
    final current = {
      for (final s in active)
        if ((_edits[s.id] ?? saved[s.id]) != null)
          s.id: _edits[s.id] ?? saved[s.id]!,
    };
    int count(String st) => current.values.where((v) => v == st).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Reminder',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => context.push('/attendance-reminder'),
          ),
        ],
      ),
      bottomNavigationBar: _edits.isEmpty
          ? null
          : SaveBar(
              label:
                  'Save ${_edits.length} change${_edits.length == 1 ? '' : 's'}',
              busy: _busy,
              onPressed: () => _save(Map.of(_edits)),
            ),
      body: staff.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(staffListProvider),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.sm,
            Spacing.lg,
            96,
          ),
          children: [
            ContentWidth(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous day',
                          onPressed: () =>
                              _go(_day.subtract(const Duration(days: 1))),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _day,
                                firstDate: DateTime(2015),
                                lastDate: DateTime.now(),
                              );
                              if (d != null) _go(d);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Spacing.md,
                              ),
                              child: Text(
                                _isToday
                                    ? 'Today · ${DateFormat('d MMM').format(_day)}'
                                    : DateFormat(
                                        'EEE, d MMM yyyy',
                                      ).format(_day),
                                textAlign: TextAlign.center,
                                style: context.text.titleSmall,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next day',
                          onPressed: _isToday
                              ? null
                              : () => _go(_day.add(const Duration(days: 1))),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Wrap(
                    spacing: Spacing.md,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${current.length} of ${active.length} marked',
                        style: context.text.labelLarge,
                      ),
                      for (final (s, label, _) in AttendanceStatus.all)
                        if (count(s) > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: attendanceColor(s),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$label ${count(s)}',
                                style: context.text.labelSmall,
                              ),
                            ],
                          ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  if (active.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                for (final s in active) {
                                  if ((_edits[s.id] ?? saved[s.id]) == null) {
                                    _edits[s.id] = AttendanceStatus.present;
                                  }
                                }
                              }),
                        icon: const Icon(Icons.done_all_rounded),
                        label: const Text('Mark everyone else present'),
                      ),
                    ),
                  if (day.isLoading) const LinearProgressIndicator(),
                  if (active.isEmpty)
                    const EmptyState(
                      icon: Icons.people_alt_rounded,
                      title: 'No active staff',
                      message: 'Add staff to start taking attendance.',
                    ),
                  for (final s in active)
                    Card(
                      margin: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(Spacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                InitialsAvatar(s.name, size: 32),
                                const SizedBox(width: Spacing.sm),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (_edits.containsKey(s.id))
                                  Text(
                                    'unsaved',
                                    style: context.text.labelSmall?.copyWith(
                                      color: hrAccent,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: Spacing.sm),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final (status, label, _)
                                      in AttendanceStatus.all) ...[
                                    ChoiceChip(
                                      label: Text(label),
                                      selected:
                                          (_edits[s.id] ?? saved[s.id]) ==
                                          status,
                                      selectedColor: attendanceColor(
                                        status,
                                      ).withValues(alpha: 0.2),
                                      onSelected: (_) => setState(() {
                                        if (saved[s.id] == status) {
                                          _edits.remove(s.id);
                                        } else {
                                          _edits[s.id] = status;
                                        }
                                      }),
                                    ),
                                    const SizedBox(width: Spacing.xs),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Daily attendance reminder settings.
class AttendanceReminderScreen extends ConsumerStatefulWidget {
  const AttendanceReminderScreen({super.key});

  @override
  ConsumerState<AttendanceReminderScreen> createState() => _ReminderState();
}

final _reminderProvider = FutureProvider.autoDispose<AttendanceReminder>(
  (ref) => ref.watch(hrRepositoryProvider).reminder(),
);

class _ReminderState extends ConsumerState<AttendanceReminderScreen> {
  AttendanceReminder? _r;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(hrRepositoryProvider).saveReminder(_r!);
      if (!mounted) return;
      showSnack(context, 'Reminder saved');
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_reminderProvider);
    _r ??= async.asData?.value;
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance reminder')),
      bottomNavigationBar: r == null
          ? null
          : SaveBar(label: 'Save', busy: _busy, onPressed: _save),
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(_reminderProvider),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            ContentWidth(
              child: FormSection(
                title: 'Daily reminder',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remind me to mark attendance'),
                    subtitle: const Text(
                      'Shown in the TruERP web app at the chosen time',
                    ),
                    value: r!.enabled,
                    onChanged: (v) => setState(
                      () => _r = AttendanceReminder(
                        enabled: v,
                        time: r.time,
                        timezone: r.timezone,
                        remindLaterMinutes: r.remindLaterMinutes,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Time'),
                    trailing: Text(r.time, style: context.text.titleMedium),
                    onTap: () async {
                      final parts = r.time.split(':');
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: int.tryParse(parts.first) ?? 10,
                          minute: int.tryParse(parts.last) ?? 0,
                        ),
                      );
                      if (t == null) return;
                      final hhmm =
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                      setState(
                        () => _r = AttendanceReminder(
                          enabled: r.enabled,
                          time: hhmm,
                          timezone: r.timezone,
                          remindLaterMinutes: r.remindLaterMinutes,
                        ),
                      );
                    },
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: r.remindLaterMinutes,
                    decoration: const InputDecoration(
                      labelText: '"Remind me later" snooze',
                    ),
                    items: [
                      for (final m in {15, 30, 60, 120, r.remindLaterMinutes})
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m < 60
                                ? '$m minutes'
                                : '${m ~/ 60} hour${m >= 120 ? 's' : ''}',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(
                      () => _r = AttendanceReminder(
                        enabled: r.enabled,
                        time: r.time,
                        timezone: r.timezone,
                        remindLaterMinutes: v ?? 30,
                      ),
                    ),
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
