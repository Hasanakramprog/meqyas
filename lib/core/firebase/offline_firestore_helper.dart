import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OfflineSyncState {
  /// Connected to the internet and all local writes are synced.
  onlineSynced,

  /// Device is offline; reads & writes are served from local SQLite cache.
  offline,

  /// Online (or reconnecting) and currently flushing queued offline writes to Cloud Firestore.
  syncing,
}

class OfflineSyncStatus {
  final OfflineSyncState state;
  final int pendingWritesCount;
  final DateTime? lastSyncedAt;

  const OfflineSyncStatus({
    required this.state,
    this.pendingWritesCount = 0,
    this.lastSyncedAt,
  });

  bool get isOffline => state == OfflineSyncState.offline;
  bool get isSyncing => state == OfflineSyncState.syncing;
  bool get hasPendingWrites => pendingWritesCount > 0;
}

/// Centralized helper for 100% offline-first Firestore reads, writes, and batches.
///
/// Key guarantees:
/// 1. `writeOfflineSafe` & `commitBatchOfflineSafe` never block the UI spinner when offline.
///    Firestore writes to local SQLite cache immediately; the remote server ACK is tracked
///    in the background and synced automatically when internet returns.
/// 2. `getDocOfflineSafe` & `getQueryOfflineSafe` fall back to `Source.cache` immediately
///    when offline or when the network is slow (`> 1200ms`).
class OfflineFirestoreHelper {
  OfflineFirestoreHelper._();

  static bool _isOnline = true;
  static int _pendingWrites = 0;
  static DateTime? _lastSyncedAt;
  static Timer? _monitorTimer;
  static bool _isCheckingNetwork = false;

  static final StreamController<OfflineSyncStatus> _statusController =
      StreamController<OfflineSyncStatus>.broadcast();

  static bool get isOnline => _isOnline;
  static int get pendingWritesCount => _pendingWrites;

  static OfflineSyncStatus get currentStatus {
    if (!_isOnline) {
      return OfflineSyncStatus(
        state: OfflineSyncState.offline,
        pendingWritesCount: _pendingWrites,
        lastSyncedAt: _lastSyncedAt,
      );
    }
    if (_pendingWrites > 0) {
      return OfflineSyncStatus(
        state: OfflineSyncState.syncing,
        pendingWritesCount: _pendingWrites,
        lastSyncedAt: _lastSyncedAt,
      );
    }
    return OfflineSyncStatus(
      state: OfflineSyncState.onlineSynced,
      pendingWritesCount: 0,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  static Stream<OfflineSyncStatus> watchStatus() async* {
    startMonitoring();
    yield currentStatus;
    yield* _statusController.stream;
  }

  static void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  /// Starts periodic lightweight network reachability monitoring and auto-flushes
  /// queued Firestore writes as soon as connectivity returns.
  static void startMonitoring() {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    if (_monitorTimer != null) return;
    checkConnectivityNow();
    _monitorTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      checkConnectivityNow();
    });
  }

  /// Stops periodic monitoring (e.g. on shell dispose or in tests).
  static void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Performs a fast DNS/socket check to determine if the device currently has internet.
  static Future<bool> checkConnectivityNow() async {
    if (kIsWeb) return true;
    if (_isCheckingNetwork) return _isOnline;
    _isCheckingNetwork = true;
    try {
      final result = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(milliseconds: 900));
      final connected =
          result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      final wasOffline = !_isOnline;
      _isOnline = connected;
      if (connected && (wasOffline || _pendingWrites > 0)) {
        _flushPendingWritesInBackground();
      }
      _emitStatus();
      return connected;
    } catch (_) {
      _isOnline = false;
      _emitStatus();
      return false;
    } finally {
      _isCheckingNetwork = false;
    }
  }

  static void _flushPendingWritesInBackground() {
    FirebaseFirestore.instance.waitForPendingWrites().then((_) {
      _pendingWrites = 0;
      _lastSyncedAt = DateTime.now();
      _emitStatus();
    }).catchError((_) {});
  }

  /// Triggered when the app resumes from background (`AppLifecycleState.resumed`)
  /// to immediately flush any offline writes queued while on site.
  static Future<void> onAppResumed() async {
    final online = await checkConnectivityNow();
    if (online) {
      _flushPendingWritesInBackground();
    }
  }

  /// Non-blocking offline-safe wrapper for `docRef.set()`, `docRef.update()`, or `docRef.delete()`.
  ///
  /// Firestore applies the mutation to the local SQLite cache synchronously when called.
  /// If the device is offline (or the server ACK takes longer than [timeout]), this method
  /// returns cleanly so the UI never hangs while Firestore continues syncing in the background.
  static Future<void> writeOfflineSafe(
    Future<void> writeFuture, {
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    _pendingWrites++;
    _emitStatus();

    var completed = false;
    writeFuture.then((_) {
      completed = true;
      if (_pendingWrites > 0) _pendingWrites--;
      _isOnline = true;
      _lastSyncedAt = DateTime.now();
      _emitStatus();
    }).catchError((Object e) {
      completed = true;
      if (_pendingWrites > 0) _pendingWrites--;
      _emitStatus();
      debugPrint('Firestore background write notice: $e');
    });

    if (!_isOnline) {
      // Give local cache listener 40ms to emit the optimistic snapshot, then return immediately
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return;
    }

    try {
      await writeFuture.timeout(timeout);
    } on TimeoutException {
      if (!completed) {
        // Likely offline or weak network — check connectivity in background and let UI proceed
        unawaited(checkConnectivityNow());
      }
    }
  }

  /// Non-blocking offline-safe wrapper for `batch.commit()`.
  static Future<void> commitBatchOfflineSafe(
    WriteBatch batch, {
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    await writeOfflineSafe(batch.commit(), timeout: timeout);
  }

  /// Reads a single document with automatic fallback to `Source.cache` when offline
  /// or when the network takes longer than [timeout].
  static Future<DocumentSnapshot<Map<String, dynamic>>> getDocOfflineSafe(
    DocumentReference<Map<String, dynamic>> ref, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    if (!_isOnline) {
      try {
        return await ref.get(const GetOptions(source: Source.cache));
      } catch (_) {
        return await ref.get();
      }
    }

    try {
      final doc = await ref.get().timeout(timeout);
      return doc;
    } catch (_) {
      _isOnline = false;
      _emitStatus();
      return await ref.get(const GetOptions(source: Source.cache));
    }
  }

  /// Executes a query with automatic fallback to `Source.cache` when offline
  /// or when the network takes longer than [timeout].
  static Future<QuerySnapshot<Map<String, dynamic>>> getQueryOfflineSafe(
    Query<Map<String, dynamic>> query, {
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    if (!_isOnline) {
      try {
        return await query.get(const GetOptions(source: Source.cache));
      } catch (_) {
        return await query.get();
      }
    }

    try {
      final snap = await query.get().timeout(timeout);
      return snap;
    } catch (_) {
      _isOnline = false;
      _emitStatus();
      return await query.get(const GetOptions(source: Source.cache));
    }
  }
}

final offlineSyncStatusProvider = StreamProvider<OfflineSyncStatus>((ref) {
  return OfflineFirestoreHelper.watchStatus();
});

