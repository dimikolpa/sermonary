enum SyncState { unavailable, idle, syncing, error }

abstract interface class SyncService {
  Future<SyncState> status();
  Future<void> push();
  Future<void> pull();
}

abstract interface class BackupService {
  Future<String> createBackup();
}

/// Explicitly reports that sync is not part of the local-first prototype.
class UnavailableSyncService implements SyncService {
  const UnavailableSyncService();
  @override
  Future<SyncState> status() async => SyncState.unavailable;
  @override
  Future<void> pull() =>
      throw UnsupportedError('Synchronisierung ist noch nicht verfügbar.');
  @override
  Future<void> push() =>
      throw UnsupportedError('Synchronisierung ist noch nicht verfügbar.');
}
