import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/android_installation_info_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/network_connectivity_service.dart';
import '../services/sync_metadata_storage_service.dart';
import 'account_provider.dart';

class CloudSyncProvider extends ChangeNotifier {
  CloudSyncProvider({
    required AccountProvider accountProvider,
    required CloudSyncService syncService,
    required SyncMetadataStorageService metadataStorage,
    required Future<void> Function() refreshLocalProviders,
    NetworkConnectivityService connectivityService =
        const NetworkConnectivityService(),
  }) : _accountProvider = accountProvider,
       _syncService = syncService,
       _metadataStorage = metadataStorage,
       _refreshLocalProviders = refreshLocalProviders,
       _connectivityService = connectivityService;

  final AccountProvider _accountProvider;
  final CloudSyncService _syncService;
  final SyncMetadataStorageService _metadataStorage;
  final Future<void> Function() _refreshLocalProviders;
  final NetworkConnectivityService _connectivityService;

  String? _deviceId;
  String? _deviceName;
  DateTime? _lastSyncAt;
  CloudSyncResult? _lastResult;
  String? _errorMessage;
  bool _syncing = false;
  bool _initialized = false;
  bool _isOffline = false;
  String? _observedUid;
  bool _isNewDevice = false;
  List<CloudDevice> _devices = const <CloudDevice>[];

  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  DateTime? get lastSyncAt => _lastSyncAt;
  CloudSyncResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _syncing;
  bool get isInitialized => _initialized;
  bool get isOffline => _isOffline;
  bool get canSync => _accountProvider.isSignedIn && !_syncing;
  bool get isNewDevice => _isNewDevice;
  List<CloudDevice> get devices => List<CloudDevice>.unmodifiable(_devices);

  String get statusLabel {
    if (!_accountProvider.isSignedIn) return 'Sign in to sync';
    if (_syncing) return 'Syncing…';
    if (_isOffline) return 'Offline (changes saved locally)';
    if (_errorMessage != null) return 'Sync needs attention';
    if (_lastSyncAt == null) return 'Ready to sync';
    return 'Synced';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _deviceId = await _metadataStorage.getOrCreateDeviceId();
    _deviceName = await AndroidInstallationInfoService().friendlyDeviceName();
    _observedUid = _accountProvider.user?.uid;
    _accountProvider.addListener(_handleAccountChanged);
    await _refreshRegistrationState();
    _initialized = true;
    notifyListeners();

    if (_accountProvider.isSignedIn) {
      unawaited(
        syncNow(isManual: false).catchError((e) {
          debugPrint('Automated startup cloud sync: $e');
          return _lastResult ??
              CloudSyncResult(
                pushed: 0,
                pulled: 0,
                deleted: 0,
                syncedAt: DateTime.now(),
              );
        }),
      );
    }
  }

  Future<CloudSyncResult> syncNow({
    CloudSyncMode mode = CloudSyncMode.bidirectional,
    bool isManual = true,
  }) async {
    if (_syncing) {
      final existing = _lastResult;
      if (existing != null) return existing;
      throw StateError('A cloud sync is already running.');
    }

    final user = _accountProvider.user;
    if (user == null) {
      throw StateError('Sign in before syncing your Focused workspace.');
    }

    // Check internet connectivity first
    final hasInternet = await _connectivityService.hasInternetConnection();
    if (!hasInternet) {
      _isOffline = true;
      if (!isManual) {
        debugPrint('Skipping automatic cloud sync: Device is offline.');
        notifyListeners();
        return _lastResult ??
            CloudSyncResult(
              pushed: 0,
              pulled: 0,
              deleted: 0,
              syncedAt: _lastSyncAt ?? DateTime.now(),
            );
      }
      _errorMessage =
          'No internet connection. Please connect to the internet to sync from Settings.';
      notifyListeners();
      throw StateError(
        'No internet connection. Please connect to the internet to sync from Settings.',
      );
    }

    _isOffline = false;
    final deviceId = _deviceId ?? await _metadataStorage.getOrCreateDeviceId();
    _deviceId = deviceId;
    _syncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _metadataStorage.bindAccountUid(user.uid);
      final result = await _syncService.sync(
        uid: user.uid,
        deviceId: deviceId,
        deviceName: _deviceName,
        mode: mode,
      );
      await _refreshLocalProviders();
      _lastResult = result;
      _lastSyncAt = result.syncedAt;
      _isNewDevice = false;
      _devices = await _syncService.loadDevices(uid: user.uid);
      return result;
    } catch (error, stackTrace) {
      _errorMessage = _friendlyError(error);
      debugPrint('Cloud sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  void _handleAccountChanged() {
    final uid = _accountProvider.user?.uid;
    if (uid == _observedUid) return;
    final wasSignedOut = _observedUid == null && uid != null;
    _observedUid = uid;
    unawaited(
      _refreshRegistrationState().then((_) {
        if (wasSignedOut && _accountProvider.isSignedIn && !_syncing) {
          syncNow(isManual: false).catchError((e) {
            debugPrint('Automated post-login cloud sync: $e');
            return _lastResult ??
                CloudSyncResult(
                  pushed: 0,
                  pulled: 0,
                  deleted: 0,
                  syncedAt: DateTime.now(),
                );
          });
        }
      }),
    );
  }

  Future<void> _refreshRegistrationState() async {
    final user = _accountProvider.user;
    if (user == null) {
      _isNewDevice = false;
      _devices = const <CloudDevice>[];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final boundUid = _metadataStorage.loadBoundAccountUid();
    if (boundUid == null) {
      await _metadataStorage.bindAccountUid(user.uid);
    } else if (boundUid != user.uid) {
      _isNewDevice = false;
      _devices = const <CloudDevice>[];
      _errorMessage =
          'This local Focused workspace belongs to another signed-in account. '
          'Sync is blocked to prevent mixing private workspace data between accounts.';
      notifyListeners();
      return;
    }

    try {
      final deviceId =
          _deviceId ?? await _metadataStorage.getOrCreateDeviceId();
      _deviceId = deviceId;
      _isNewDevice = !await _syncService.isDeviceRegistered(
        uid: user.uid,
        deviceId: deviceId,
      );
      _devices = await _syncService.loadDevices(uid: user.uid);
      _errorMessage = null;
    } catch (error) {
      debugPrint('Could not inspect Focused device registry: $error');
    }
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    final user = _accountProvider.user;
    if (user == null) {
      _devices = const <CloudDevice>[];
      notifyListeners();
      return;
    }
    try {
      _devices = await _syncService.loadDevices(uid: user.uid);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyError(error);
    }
    notifyListeners();
  }

  Future<void> deleteDevice(String deviceId) async {
    final user = _accountProvider.user;
    if (user == null) {
      throw StateError('Sign in before managing devices.');
    }
    try {
      await _syncService.deleteDevice(uid: user.uid, deviceId: deviceId);
      _devices = await _syncService.loadDevices(uid: user.uid);
      notifyListeners();
    } catch (error) {
      _errorMessage = _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _accountProvider.removeListener(_handleAccountChanged);
    super.dispose();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('permission-denied')) {
      return 'Firestore denied this sync. Check your Firebase security rules for users/{uid} data.';
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'Cloud sync could not reach Firebase. Check the internet connection and try again.';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
