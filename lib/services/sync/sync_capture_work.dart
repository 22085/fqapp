import 'dart:isolate';

import '../../models/library_backup.dart';
import 'sync_document.dart';
import 'sync_snapshot.dart';

typedef LocalSyncCapture = ({
  SyncSnapshot current,
  Map<String, Map<String, dynamic>?> changes,
});

/// Keep full-library JSON conversion and comparison off the UI isolate.
Future<LocalSyncCapture> prepareLocalSyncCapture(
  LibraryBackup backup,
  SyncSnapshot baseline,
  Map<String, dynamic>? pending,
) => Isolate.run(() {
  final current = SyncSnapshot.fromBackup(backup);
  final previous = Map<String, Map<String, dynamic>>.of(baseline.values);
  if (pending != null) {
    for (final key in {...previous.keys, ...pending.keys}) {
      if (syncJson(current.values[key]) == syncJson(pending[key])) {
        final value = pending[key];
        if (value == null) {
          previous.remove(key);
        } else {
          previous[key] = Map<String, dynamic>.from(value as Map);
        }
      }
    }
  }
  return (
    current: current,
    changes: <String, Map<String, dynamic>?>{
      for (final key in {...current.values.keys, ...previous.keys})
        if (syncJson(current.values[key]) != syncJson(previous[key]))
          key: current.values[key],
    },
  );
});

/// At most one queued scan and one dirty flag, regardless of event volume.
/// A follow-up goes to the back of the owner's serial queue so configuration,
/// explicit sync and shutdown cannot be starved by continuous progress writes.
class CoalescedSyncWork {
  CoalescedSyncWork({required this.enqueue, required this.run});
  final Future<void> Function(Future<void> Function()) enqueue;
  final Future<void> Function() run;
  bool _queued = false;
  bool _dirty = false;

  void request() {
    _dirty = true;
    if (_queued) return;
    _queued = true;
    enqueue(
      () async {
        _dirty = false;
        try {
          await run();
        } finally {
          _queued = false;
          if (_dirty) request();
        }
      },
    ).ignore(); // The owner reports capture failures; notifications have no waiter.
  }
}
