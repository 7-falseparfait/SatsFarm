import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/currency_formatter.dart';
import '../services/bdk_service.dart';
import '../services/ldk_service.dart';
import '../services/secure_storage_service.dart';

/// Wallet state shared by onboarding and the farmer screens.
class WalletProvider extends ChangeNotifier {
  WalletProvider({
    BdkService? bdkService,
    LdkService? ldkService,
    SecureStorageService? storage,
  }) : _bdk = bdkService ?? BdkService(),
       _ldk = ldkService ?? LdkService(),
       _storage = storage ?? SecureStorageService();

  final BdkService _bdk;
  final LdkService _ldk;
  final SecureStorageService _storage;

  int _onchainSats = 0;
  int _lightningSats = 0;
  String? _currentReceiveAddress;
  String? _currentInvoice;
  String? _error;
  String? _mnemonic;
  bool _busy = false;
  bool _walletReady = false;
  bool _backupConfirmed = false;

  int get satsBalance => _onchainSats + _lightningSats;
  int get ngnBalance => CurrencyFormatter.satsToNgn(
    satsBalance,
    ngnPerSat: AppConstants.mockNgnPerSatoshi,
  );
  bool get isNodeRunning => _ldk.isRunning;
  String? get currentReceiveAddress => _currentReceiveAddress;
  String? get currentInvoice => _currentInvoice;
  String? get error => _error;
  bool get isBusy => _busy;
  bool get hasWallet => _walletReady;
  bool get needsBackupConfirmation => _walletReady && !_backupConfirmed;
  bool get isLinuxDesktop => defaultTargetPlatform == TargetPlatform.linux;
  String? get recoveryPhrase => _mnemonic;

  /// Restores a saved wallet at app startup. Returns false only when no wallet
  /// has been saved; secure-storage errors are allowed to reach the startup UI.
  Future<bool> loadSavedWallet({required String storageDirectory}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final mnemonic = await _storage.readMnemonic();
      if (mnemonic == null) return false;
      _mnemonic = mnemonic;
      _backupConfirmed = await _storage.isBackupConfirmed();
      await _initializeWalletState(mnemonic, storageDirectory);
      _walletReady = true;
      _startLightningIfSupported(mnemonic, storageDirectory);
      return true;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String> createWallet({required String storageDirectory}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final mnemonic = await _bdk.generateMnemonic();
      await _storage.saveMnemonic(mnemonic);
      await _storage.setBackupConfirmed(false);
      _mnemonic = mnemonic;
      _backupConfirmed = false;
      await _initializeWalletState(mnemonic, storageDirectory);
      _walletReady = true;
      _startLightningIfSupported(mnemonic, storageDirectory);
      return mnemonic;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Restores a phrase explicitly entered by the user and initializes its
  /// derivation state before allowing navigation to the wallet.
  Future<void> restoreWallet(
    String mnemonic, {
    required String storageDirectory,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _storage.saveMnemonic(mnemonic);
      await _storage.setBackupConfirmed(true);
      _mnemonic = mnemonic;
      _backupConfirmed = true;
      await _initializeWalletState(mnemonic, storageDirectory);
      _walletReady = true;
      _startLightningIfSupported(mnemonic, storageDirectory);
    } catch (e) {
      _walletReady = false;
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> confirmRecoveryPhrase() async {
    if (!_walletReady) throw StateError('Initialize the wallet first.');
    await _storage.setBackupConfirmed(true);
    _backupConfirmed = true;
    notifyListeners();
  }

  Future<void> _initializeWalletState(
    String mnemonic,
    String storageDirectory,
  ) async {
    final nextAddressIndex = await _storage.readNextReceiveIndex();
    await _bdk.initialize(
      mnemonicPhrase: mnemonic,
      nextReceiveIndex: nextAddressIndex,
    );
  }

  void _startLightningIfSupported(String mnemonic, String storageDirectory) {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    unawaited(_startLightning(mnemonic, storageDirectory));
  }

  Future<void> _startLightning(String mnemonic, String storageDirectory) async {
    try {
      await _ldk.initialize(
        mnemonicPhrase: mnemonic,
        storageDirectory: storageDirectory,
      );
      await _ldk.start();
      await refreshBalances();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void reportError(Object error) {
    _error = error.toString();
    notifyListeners();
  }

  Future<void> refreshBalances() async {
    try {
      _onchainSats = await _bdk.syncAndGetBalance();
      _lightningSats = await _ldk.lightningBalanceSats();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<String> generateReceiveAddress() async {
    try {
      if (!_walletReady) {
        throw StateError(
          'Create or restore a wallet before generating an address.',
        );
      }
      final address = await _bdk.getAddress();
      await _storage.saveNextReceiveIndex(_bdk.nextReceiveIndex);
      _currentReceiveAddress = address;
      _error = null;
      notifyListeners();
      return address;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> generateInvoice({
    required int amountSats,
    String description = 'SatsFarm payment',
  }) async {
    try {
      final invoice = await _ldk.createInvoice(
        amountSats: amountSats,
        description: description,
      );
      _currentInvoice = invoice;
      _error = null;
      notifyListeners();
      return invoice;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
