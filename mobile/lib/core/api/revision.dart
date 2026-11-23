import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after any create/update/delete. Lists include it in their
/// reset key so they reload after a save made on another screen.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);
