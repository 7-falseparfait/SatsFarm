import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/ngo_api_service.dart';
import '../services/secure_storage_service.dart';

/// Program-side state for the farmer: device identity bound to an NGO
/// profile, the vouchers the NGO sent, and dealer redemptions.
class VoucherProvider extends ChangeNotifier {
  VoucherProvider({NgoApiService? api, SecureStorageService? storage})
    : _api = api ?? NgoApiService(),
      _storage = storage ?? SecureStorageService();

  final NgoApiService _api;
  final SecureStorageService _storage;

  FarmerProfile? _profile;
  FarmerAccount? _farmerAccount;
  List<VoucherRecord> _vouchers = <VoucherRecord>[];
  String? _error;
  String? _joinError;
  String? _sessionToken;
  bool _busy = false;
  bool _registered = false;
  bool _checkedRegistration = false;

  FarmerProfile? get profile => _profile;
  FarmerAccount? get farmerAccount => _farmerAccount;
  String? get profileName => _profile?.name;
  List<VoucherRecord> get vouchers => List.unmodifiable(_vouchers);
  bool get busy => _busy;
  bool get registered => _registered;
  bool get checkedRegistration => _checkedRegistration;
  String? get error => _error;
  String? get joinError => _joinError;
  bool get hasFarmerSession => _sessionToken != null && _farmerAccount != null;

  Future<void> logoutFarmer() async {
    await _storage.deleteFarmerSessionToken();
    _sessionToken = null;
    _farmerAccount = null;
    _profile = null;
    _vouchers = <VoucherRecord>[];
    _joinError = null;
    notifyListeners();
  }

  int get activeGrantNgn => _vouchers
      .where(
        (v) => v.kind == VoucherKind.grant && v.status == VoucherStatus.active,
      )
      .fold(0, (sum, v) => sum + v.remainingNgn);
  int get activeLoanNgn => _vouchers
      .where(
        (v) => v.kind == VoucherKind.loan && v.status == VoucherStatus.active,
      )
      .fold(0, (sum, v) => sum + v.amountOwedNgn);

  Future<void> initializeInviteSession() async {
    _sessionToken = await _storage.readFarmerSessionToken();
    if (_sessionToken == null) return;
    try {
      await _loadFarmerAccount();
    } on NgoApiException catch (error) {
      if (error.status == 401) {
        await _storage.deleteFarmerSessionToken();
        _sessionToken = null;
        return;
      }
      _joinError = 'unavailable';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> redeemInvite(String code) async {
    _busy = true;
    _joinError = null;
    notifyListeners();
    try {
      var clientId = await _storage.readJoinClientId();
      if (clientId == null) {
        clientId = _generateDeviceId();
        await _storage.saveJoinClientId(clientId);
      }
      final response = await _api.postJson('/api/farmers/invites/redeem', {
        'code': code.trim(),
        'clientId': clientId,
      });
      final token = response['sessionToken'] as String;
      await _storage.saveFarmerSessionToken(token);
      _sessionToken = token;
      await _loadFarmerAccount();
      return true;
    } on NgoApiException catch (error) {
      _joinError = switch (error.message) {
        'invalid_code' => 'invalid',
        'expired_code' => 'expired',
        'already_used' => 'used',
        _ => 'unavailable',
      };
      return false;
    } on PlatformException {
      _joinError = 'storage';
      return false;
    } on MissingPluginException {
      _joinError = 'storage';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshFarmerAccount() async {
    _busy = true;
    _joinError = null;
    notifyListeners();
    try {
      await _loadFarmerAccount();
    } on NgoApiException {
      _joinError = 'unavailable';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadFarmerAccount() async {
    final token = _sessionToken;
    if (token == null) return;
    final map = await _api.getJson('/api/farmer/account', bearerToken: token);
    _farmerAccount = FarmerAccount.fromMap(map);
    _profile = FarmerProfile(
      id: _farmerAccount!.farmerId,
      name: _farmerAccount!.name,
      location: '',
      language: 'English',
    );
    await _refreshInner();
  }

  /// Loads the device identity, resumes any saved profile, then refreshes.
  Future<void> initialize() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (_sessionToken != null) {
        _registered = _farmerAccount != null;
        _checkedRegistration = true;
        if (_registered) await _refreshInner();
        return;
      }
      String? deviceId = await _storage.readDeviceId();
      if (deviceId == null) {
        deviceId = _generateDeviceId();
        await _storage.saveDeviceId(deviceId);
      }
      try {
        final map = await _api.getJson('/api/farmers/by-device/$deviceId');
        _profile = FarmerProfile.fromMap(map);
        _registered = true;
      } on NgoApiException catch (e) {
        if (e.status == 404) {
          _registered = false;
        } else {
          _error = e.message ?? 'Could not reach the SatsFarm program API.';
        }
      }
      _checkedRegistration = true;
      if (_registered) await _refreshInner();
    } on NgoApiException {
      _error = 'Could not reach the SatsFarm program API on this network.';
      _checkedRegistration = true;
    } catch (e) {
      if (e is Exception) _error = 'Could not reach the SatsFarm program API.';
      _checkedRegistration = true;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Registers this device with the NGO program desk as a new farmer.
  Future<void> registerProfile({
    required String name,
    required String location,
    String language = 'Ha',
  }) async {
    final deviceId = await _storage.readDeviceId();
    if (deviceId == null) {
      _error = 'Device identity is missing; restart the app.';
      notifyListeners();
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final map = await _api.postJson('/api/farmers', {
        'deviceId': deviceId,
        'name': name,
        'location': location,
        'language': language,
      });
      _profile = FarmerProfile.fromMap(map);
      _registered = true;
      await _refreshInner();
    } on NgoApiException catch (e) {
      _error = e.message ?? 'Registration failed. Try again.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _refreshInner();
    } on NgoApiException catch (e) {
      _error = e.message ?? 'Could not reach the SatsFarm program API.';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Asks the NGO to pay a whitelisted dealer's invoice from this voucher, and
  /// waits for the payment to settle (or fail) on the Mutinynet test network.
  Future<PaymentRecord> redeem({
    required String voucherId,
    required String invoice,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    PaymentRecord result;
    try {
      final map = await _api.postJson('/api/payments/request', {
        'voucherId': voucherId,
        'invoice': invoice.trim(),
      });
      result = _paymentFromResponse(map);
      var attempts = 0;
      while (result.state == PaymentState.pending && attempts < 12) {
        await Future<void>.delayed(const Duration(seconds: 4));
        final fetched = await _api.getJson('/api/payments/${result.id}');
        result = PaymentRecord.fromMap(fetched);
        attempts += 1;
      }
      await _refreshInner();
      return result;
    } on NgoApiException catch (e) {
      _error = e.message ?? 'Redeem request failed. Try again.';
      return PaymentRecord(
        id: '',
        state: PaymentState.failed,
        amountNgn: 0,
        amountSats: 0,
        dealer: '',
        time: '',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _refreshInner() async {
    if (_profile == null) return;
    final map = await _api.getJson('/api/farmers/${_profile!.id}/vouchers');
    final value = map['value'];
    if (value is List) {
      _vouchers = value
          .whereType<Map<String, dynamic>>()
          .map(VoucherRecord.fromMap)
          .toList();
    } else {
      _vouchers = <VoucherRecord>[];
    }
  }

  PaymentRecord _paymentFromResponse(Map<String, dynamic> map) {
    final inner = map['payment'];
    if (inner is Map<String, dynamic>) return PaymentRecord.fromMap(inner);
    return PaymentRecord.fromMap(map);
  }

  String _generateDeviceId() {
    final random = Random.secure();
    const chars = '0123456789abcdef';
    return List<String>.generate(
      32,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
