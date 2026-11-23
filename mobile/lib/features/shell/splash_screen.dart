import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_controller.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/common.dart';
import '../auth/ui/auth_layout.dart';

/// Shown while the saved session is restored, or when the server can't be
/// reached at launch (the user stays signed in and can retry).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: session.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ErrorView(error: session.error!, onRetry: () => ref.invalidate(sessionProvider)),
                    Wrap(
                      spacing: Spacing.sm,
                      children: [
                        TextButton(onPressed: () => showServerSheet(context, ref), child: const Text('Server settings')),
                        TextButton(
                          onPressed: () => ref.read(sessionProvider.notifier).logout(),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', height: 80),
                    const SizedBox(height: Spacing.xl),
                    const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.6)),
                  ],
                ),
        ),
      ),
    );
  }
}
