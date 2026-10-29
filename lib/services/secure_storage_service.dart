import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// OS-backed storage for wallet recovery material and wallet-local metadata.
/// On Linux this uses Secret Service/libsecret and requires an unlocked keyring.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _mnemonicKey = 'satsfarm.wallet.mnemonic';
  static const _backupConfirmedKey = 'satsfarm.wallet.backup_confirmed';
  static const _nextReceiveIndexKey = 'satsfarm.wallet.next_receive_index';
  static const _deviceIdKey = 'satsfarm.farmer.device_id';
  static const _joinClientIdKey = 'satsfarm.farmer.join_client_id';
  static const _farmerSessionTokenKey = 'satsfarm.farmer.session_token';
  final FlutterSecureStorage _storage;

  Future<void> saveMnemonic(String mnemonic) async {
    await _storage.write(key: _mnemonicKey, value: mnemonic);
    final saved = await _storage.read(key: _mnemonicKey);
    if (saved != mnemonic) {
      throw StateError(
        'Secure storage did not confirm the saved recovery phrase.',
      );
    }
  }

  Future<String?> readMnemonic() => _storage.read(key: _mnemonicKey);

  Future<void> setBackupConfirmed(bool confirmed) =>
      _storage.write(key: _backupConfirmedKey, value: confirmed.toString());

  Future<bool> isBackupConfirmed() async =>
      await _storage.read(key: _backupConfirmedKey) == 'true';

  Future<int> readNextReceiveIndex() async =>
      int.tryParse(await _storage.read(key: _nextReceiveIndexKey) ?? '') ?? 0;

  Future<void> saveNextReceiveIndex(int index) =>
      _storage.write(key: _nextReceiveIndexKey, value: index.toString());

  /// Stable random identifier for this program member (not the wallet seed).
  /// Generated once per wallet installation and bound to the NGO profile.
  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);

  Future<void> saveDeviceId(String deviceId) =>
      _storage.write(key: _deviceIdKey, value: deviceId);

  Future<String?> readJoinClientId() => _storage.read(key: _joinClientIdKey);

  Future<void> saveJoinClientId(String clientId) =>
      _storage.write(key: _joinClientIdKey, value: clientId);

  Future<String?> readFarmerSessionToken() =>
      _storage.read(key: _farmerSessionTokenKey);

  Future<void> saveFarmerSessionToken(String token) =>
      _storage.write(key: _farmerSessionTokenKey, value: token);

  Future<void> deleteFarmerSessionToken() =>
      _storage.delete(key: _farmerSessionTokenKey);

  Future<void> deleteWallet() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _backupConfirmedKey);
    await _storage.delete(key: _nextReceiveIndexKey);
    await _storage.delete(key: _deviceIdKey);
  }
}
