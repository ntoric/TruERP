import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_exception.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  final prefs = await SharedPreferences.getInstance();
  await initializeDateFormatting('en_IN');

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    // API errors are shown to the user with a retry button, so don't
    // silently retry them in the background.
    retry: (count, error) => error is ApiException ? null : (count < 2 ? const Duration(seconds: 1) : null),
    child: const TruErpApp(),
  ));
}
