import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/private_sync_cloud_service.dart';
import '../services/private_sync_crypto_service.dart';
import '../services/private_sync_secure_storage_service.dart';
import '../services/private_sync_snapshot_service.dart';
import 'account_provider.dart';

enum PrivateSyncState {
  checking,
  localOnly,
  ready,
  keyRequired,
  keyChanged,
  syncing,
  remoteChanged,
  error,
}

class PrivateSyncProvider extends ChangeNotifier {
  PrivateSyncProvider({
    required AccountProvider accountProvider,
    required PrivateSyncCryptoService cryptoService,
    required PrivateSyncSecureStorageService secureStorageService,
    required PrivateSyncCloudService cloudService,
    required PrivateSyncSnapshotService snapshotService,
    List<Listenable> localChangeSources = const [],
  })  : _accountProvider = accountProvider,
        _cryptoService = cryptoService,
        _secureStorageService = secureStorageService,
        _cloudService = cloudService,
        _snapshotService = snapshotService,
        _localChangeSources =
            List<Listenable>.unmodifiable(
          localChangeSources,
        );

  final AccountProvider _accountProvider;
  final PrivateSyncCryptoService _cryptoService;
  final PrivateSyncSecureStorageService
      _secureStorageService;
  final PrivateSyncCloudService _cloudService;
  final PrivateSyncSnapshotService
      _snapshotService;
  final List<Listenable> _localChangeSources;

  Timer? _syncDebounce;
  String? _lastUid;
  LocalPrivateSyncKeyBundle? _localBundle;

  PrivateSyncState _state =
      PrivateSyncState.checking;
  String? _errorMessage;
  int? _cloudKeyVersion;
  String? _activeRevisionId;
  String? _snapshotTag;
  DateTime? _lastSyncedAt;
  Map<String, int> _lastSnapshotSummary =
      const {};

  PrivateSyncState get state => _state;
  String? get errorMessage => _errorMessage;
  int? get cloudKeyVersion => _cloudKeyVersion;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  Map<String, int> get lastSnapshotSummary =>
      Map<String, int>.unmodifiable(
        _lastSnapshotSummary,
      );

  bool get isBusy =>
      _state == PrivateSyncState.checking ||
      _state == PrivateSyncState.syncing;

  bool get cloudConfigured =>
      _cloudKeyVersion != null;

  bool get hasLocalKey =>
      _localBundle != null;

  bool get canRevealKey =>
      _localBundle != null;

  bool get isReady =>
      _state == PrivateSyncState.ready;

  bool get needsKey =>
      _state == PrivateSyncState.keyRequired ||
      _state == PrivateSyncState.keyChanged;

  String get statusLabel {
    switch (_state) {
      case PrivateSyncState.checking:
        return 'Checking…';
      case PrivateSyncState.localOnly:
        return 'Local only';
      case PrivateSyncState.ready:
        return 'Encrypted sync active';
      case PrivateSyncState.keyRequired:
        return 'Private key required';
      case PrivateSyncState.keyChanged:
        return 'Private key changed';
      case PrivateSyncState.syncing:
        return 'Syncing…';
      case PrivateSyncState.remoteChanged:
        return 'Cloud changed on another device';
      case PrivateSyncState.error:
        return 'Needs attention';
    }
  }

  Future<void> initialize() async {
    _accountProvider.addListener(
      _handleAccountChanged,
    );

    for (final source in _localChangeSources) {
      source.addListener(_handleLocalChange);
    }

    _lastUid = _currentUid;
    await refresh();
  }

  Future<void> refresh() async {
    _syncDebounce?.cancel();
    _errorMessage = null;

    final uid = _currentUid;
    if (uid == null) {
      _resetForSignedOut();
      return;
    }

    _state = PrivateSyncState.checking;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _secureStorageService.read(uid),
        _cloudService.loadConfig(uid),
      ]);

      final localBundle =
          results[0] as LocalPrivateSyncKeyBundle?;
      final cloudConfig =
          results[1] as PrivateSyncCloudConfig?;

      _localBundle = localBundle;

      if (cloudConfig == null) {
        _cloudKeyVersion = null;
        _activeRevisionId = null;
        _snapshotTag = null;
        _lastSyncedAt = null;
        _lastSnapshotSummary = const {};
        _state = PrivateSyncState.localOnly;
        notifyListeners();
        return;
      }

      _cloudKeyVersion =
          cloudConfig.keyVersion;
      _activeRevisionId =
          cloudConfig.activeRevisionId;
      _snapshotTag =
          cloudConfig.snapshotTag;
      _lastSyncedAt =
          cloudConfig.updatedAt;

      if (localBundle == null) {
        _state =
            PrivateSyncState.keyRequired;
      } else if (localBundle.keyVersion !=
          cloudConfig.keyVersion) {
        _state =
            PrivateSyncState.keyChanged;
      } else {
        _state = PrivateSyncState.ready;
      }

      notifyListeners();
    } catch (error) {
      _state = PrivateSyncState.error;
      _errorMessage =
          _friendlyError(error);
      notifyListeners();
    }
  }

  Future<String> enablePrivateSync() async {
    final uid = _requireUid();

    _state = PrivateSyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    LocalPrivateSyncKeyBundle? newBundle;

    try {
      final existing =
          await _cloudService.loadConfig(uid);

      if (existing != null) {
        _cloudKeyVersion =
            existing.keyVersion;
        _activeRevisionId =
            existing.activeRevisionId;
        _snapshotTag =
            existing.snapshotTag;
        _state =
            PrivateSyncState.keyRequired;
        throw const PrivateSyncAlreadyConfiguredException();
      }

      final generated =
          await _cryptoService.generateMasterKey();

      final dataKey =
          await _cryptoService.generateDataKey();

      newBundle =
          LocalPrivateSyncKeyBundle(
        masterKeyBytes:
            generated.masterKeyBytes,
        dataKeyBytes: dataKey,
        keyVersion: 1,
      );

      await _secureStorageService.write(
        uid: uid,
        bundle: newBundle,
      );

      final wrappedDataKey =
          await _cryptoService.wrapDataKey(
        masterKeyBytes:
            newBundle.masterKeyBytes,
        dataKeyBytes:
            newBundle.dataKeyBytes,
      );

      final keyCheck =
          await _cryptoService.createKeyCheck(
        uid: uid,
        masterKeyBytes:
            newBundle.masterKeyBytes,
      );

      final snapshot =
          await _snapshotService.export();

      final encryptedSnapshot =
          await _cryptoService.encryptBytes(
        clearText:
            snapshot.compressedBytes,
        keyBytes:
            newBundle.dataKeyBytes,
      );

      final snapshotTag =
          await _cryptoService.snapshotTag(
        clearTextHash:
            snapshot.clearTextHash,
        dataKeyBytes:
            newBundle.dataKeyBytes,
      );

      final revision =
          await _cloudService.createWorkspace(
        uid: uid,
        keyVersion: 1,
        wrappedDataKey: wrappedDataKey,
        keyCheck: keyCheck,
        encryptedSnapshot:
            encryptedSnapshot,
        snapshotTag: snapshotTag,
      );

      _localBundle = newBundle;
      _cloudKeyVersion = 1;
      _activeRevisionId =
          revision.revisionId;
      _snapshotTag = snapshotTag;
      _lastSyncedAt = DateTime.now();
      _lastSnapshotSummary =
          snapshot.summary;
      _state = PrivateSyncState.ready;
      notifyListeners();

      return generated.formattedKey;
    } catch (error) {
      if (newBundle != null &&
          _cloudKeyVersion == null) {
        await _secureStorageService
            .delete(uid);
        _localBundle = null;
      }

      if (error
          is PrivateSyncAlreadyConfiguredException) {
        _errorMessage =
            'Encrypted sync already exists for this account. '
            'Enter the existing Focused private key instead.';
      } else {
        _state = PrivateSyncState.error;
        _errorMessage =
            _friendlyError(error);
      }

      notifyListeners();
      rethrow;
    }
  }

  Future<void> unlockWithKey(
    String formattedKey,
  ) async {
    final uid = _requireUid();

    _state = PrivateSyncState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final config =
          await _cloudService.loadConfig(uid);

      if (config == null) {
        throw StateError(
          'This account does not have encrypted sync configured.',
        );
      }

      final masterKey =
          await _cryptoService.parseMasterKey(
        formattedKey,
      );

      final valid =
          await _cryptoService.verifyKeyCheck(
        uid: uid,
        masterKeyBytes: masterKey,
        keyCheck: config.keyCheck,
      );

      if (!valid) {
        throw const FormatException(
          'That Focused private key does not match this account.',
        );
      }

      final dataKey =
          await _cryptoService.unwrapDataKey(
        masterKeyBytes: masterKey,
        wrappedDataKey:
            config.wrappedDataKey,
      );

      final bundle =
          LocalPrivateSyncKeyBundle(
        masterKeyBytes: masterKey,
        dataKeyBytes: dataKey,
        keyVersion: config.keyVersion,
      );

      await _secureStorageService.write(
        uid: uid,
        bundle: bundle,
      );

      _localBundle = bundle;
      _cloudKeyVersion =
          config.keyVersion;
      _activeRevisionId =
          config.activeRevisionId;
      _snapshotTag =
          config.snapshotTag;
      _lastSyncedAt =
          config.updatedAt;
      _state = PrivateSyncState.ready;
      notifyListeners();
    } catch (error) {
      _state = PrivateSyncState.error;
      _errorMessage =
          _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<String> revealPrivateKey() async {
    final bundle = _localBundle;
    if (bundle == null) {
      throw StateError(
        'This device does not have the Focused private key.',
      );
    }

    return _cryptoService.formatMasterKey(
      bundle.masterKeyBytes,
    );
  }

  Future<String> rotatePrivateKey() async {
    final uid = _requireUid();
    final currentBundle = _requireBundle();

    _state = PrivateSyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    final generated =
        await _cryptoService.generateMasterKey();

    final newVersion =
        currentBundle.keyVersion + 1;

    final nextBundle =
        LocalPrivateSyncKeyBundle(
      masterKeyBytes:
          generated.masterKeyBytes,
      dataKeyBytes:
          currentBundle.dataKeyBytes,
      keyVersion: newVersion,
    );

    try {
      // Save the new key locally first. If the cloud transaction fails,
      // the previous local key is restored.
      await _secureStorageService.write(
        uid: uid,
        bundle: nextBundle,
      );

      final wrappedDataKey =
          await _cryptoService.wrapDataKey(
        masterKeyBytes:
            nextBundle.masterKeyBytes,
        dataKeyBytes:
            nextBundle.dataKeyBytes,
      );

      final keyCheck =
          await _cryptoService.createKeyCheck(
        uid: uid,
        masterKeyBytes:
            nextBundle.masterKeyBytes,
      );

      await _cloudService.rotateKey(
        uid: uid,
        expectedKeyVersion:
            currentBundle.keyVersion,
        newKeyVersion: newVersion,
        wrappedDataKey: wrappedDataKey,
        keyCheck: keyCheck,
      );

      _localBundle = nextBundle;
      _cloudKeyVersion = newVersion;
      _state = PrivateSyncState.ready;
      _lastSyncedAt = DateTime.now();
      notifyListeners();

      return generated.formattedKey;
    } catch (error) {
      await _secureStorageService.write(
        uid: uid,
        bundle: currentBundle,
      );

      _localBundle = currentBundle;

      if (error
          is PrivateSyncKeyVersionChangedException) {
        _state =
            PrivateSyncState.keyChanged;
      } else {
        _state = PrivateSyncState.error;
      }

      _errorMessage =
          _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> syncNow() async {
    final uid = _requireUid();
    final bundle = _requireBundle();

    if (_cloudKeyVersion !=
        bundle.keyVersion) {
      _state = PrivateSyncState.keyChanged;
      notifyListeners();
      return;
    }

    final previousState = _state;
    _state = PrivateSyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot =
          await _snapshotService.export();

      final snapshotTag =
          await _cryptoService.snapshotTag(
        clearTextHash:
            snapshot.clearTextHash,
        dataKeyBytes:
            bundle.dataKeyBytes,
      );

      if (snapshotTag == _snapshotTag) {
        _lastSnapshotSummary =
            snapshot.summary;
        _state = PrivateSyncState.ready;
        notifyListeners();
        return;
      }

      final encrypted =
          await _cryptoService.encryptBytes(
        clearText:
            snapshot.compressedBytes,
        keyBytes:
            bundle.dataKeyBytes,
      );

      final revision =
          await _cloudService
              .replaceActiveRevision(
        uid: uid,
        expectedKeyVersion:
            bundle.keyVersion,
        expectedActiveRevisionId:
            _activeRevisionId,
        encryptedSnapshot: encrypted,
        snapshotTag: snapshotTag,
      );

      _activeRevisionId =
          revision.revisionId;
      _snapshotTag = snapshotTag;
      _lastSnapshotSummary =
          snapshot.summary;
      _lastSyncedAt = DateTime.now();
      _state = PrivateSyncState.ready;
      notifyListeners();
    } on PrivateSyncKeyVersionChangedException
        catch (error) {
      _state = PrivateSyncState.keyChanged;
      _errorMessage = error.toString();
      notifyListeners();
    } on PrivateSyncRemoteChangedException
        catch (error) {
      _state =
          PrivateSyncState.remoteChanged;
      _errorMessage = error.toString();
      notifyListeners();
    } catch (error) {
      _state = previousState ==
              PrivateSyncState.ready
          ? PrivateSyncState.error
          : previousState;
      _errorMessage =
          _friendlyError(error);
      notifyListeners();
    }
  }

  Future<void> disablePrivateSync() async {
    final uid = _requireUid();

    _state = PrivateSyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      await _cloudService.disable(uid);
      await _secureStorageService.delete(uid);

      _localBundle = null;
      _cloudKeyVersion = null;
      _activeRevisionId = null;
      _snapshotTag = null;
      _lastSyncedAt = null;
      _lastSnapshotSummary = const {};
      _state = PrivateSyncState.localOnly;
      notifyListeners();
    } catch (error) {
      _state = PrivateSyncState.error;
      _errorMessage =
          _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> forgetLocalKeyForSignOut() async {
    final uid = _currentUid;
    if (uid == null) return;

    await _secureStorageService.delete(uid);
    _localBundle = null;

    if (_cloudKeyVersion != null) {
      _state =
          PrivateSyncState.keyRequired;
    } else {
      _state =
          PrivateSyncState.localOnly;
    }

    notifyListeners();
  }

  Future<DownloadedPrivateSyncRevision?>
      downloadEncryptedCloudRevisionForFutureRestore()
      async {
    final uid = _requireUid();
    final bundle = _requireBundle();

    final revision =
        await _cloudService.downloadActiveRevision(
      uid: uid,
      revisionId: _activeRevisionId,
    );

    if (revision == null) return null;

    final compressed =
        await _cryptoService.decryptBytes(
      envelope: revision.envelope,
      keyBytes: bundle.dataKeyBytes,
    );

    // Validate that the decrypted payload is a supported Focused snapshot.
    _snapshotService.decodeCompressedSnapshot(
      compressed,
    );

    return revision;
  }

  String? get _currentUid =>
      _accountProvider.user?.uid;

  String _requireUid() {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Sign in before configuring private sync.',
      );
    }
    return uid;
  }

  LocalPrivateSyncKeyBundle _requireBundle() {
    final bundle = _localBundle;
    if (bundle == null) {
      throw StateError(
        'Enter the Focused private key on this device first.',
      );
    }
    return bundle;
  }

  void _handleAccountChanged() {
    final uid = _currentUid;

    if (uid == _lastUid) return;

    _lastUid = uid;
    unawaited(refresh());
  }

  void _handleLocalChange() {
    if (_state != PrivateSyncState.ready) {
      return;
    }

    _syncDebounce?.cancel();
    _syncDebounce = Timer(
      const Duration(seconds: 2),
      () {
        unawaited(syncNow());
      },
    );
  }

  void _resetForSignedOut() {
    _localBundle = null;
    _cloudKeyVersion = null;
    _activeRevisionId = null;
    _snapshotTag = null;
    _lastSyncedAt = null;
    _lastSnapshotSummary = const {};
    _state = PrivateSyncState.localOnly;
    _errorMessage = null;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    final message =
        error.toString().replaceFirst(
              'Exception: ',
              '',
            );

    if (message.contains(
      'PERMISSION_DENIED',
    )) {
      return 'Firestore denied this request. Apply the Focused owner-only '
          'Firestore rules before enabling private sync.';
    }

    if (message.contains(
          'UNAVAILABLE',
        ) ||
        message.toLowerCase().contains(
          'network',
        )) {
      return 'Cloud sync is unavailable right now. Your local data is safe.';
    }

    return message;
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();

    _accountProvider.removeListener(
      _handleAccountChanged,
    );

    for (final source in _localChangeSources) {
      source.removeListener(_handleLocalChange);
    }

    super.dispose();
  }
}
