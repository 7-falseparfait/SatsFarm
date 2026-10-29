import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Base URL of the local SatsFarm NGO API. Override when the app runs on a
/// phone by passing:
///   flutter run --dart-define=SATS_FARM_API_URL=http://`<pc-lan-ip>`:8787
const String ngoApiBaseUrl = String.fromEnvironment(
  'SATS_FARM_API_URL',
  defaultValue: 'http://127.0.0.1:8787',
);

/// Thrown for API errors with an optional human-friendly message from the API.
class NgoApiException implements Exception {
  NgoApiException(this.status, {this.message});

  final int status;
  final String? message;

  @override
  String toString() => message ?? 'NGO API request failed ($status).';
}

/// Minimal JSON HTTP client for the SatsFarm/demo NGO API (no auth in demo).
class NgoApiService {
  NgoApiService({HttpClient Function()? clientFactory})
    : client = (clientFactory?.call() ?? HttpClient()) {
    client.connectionTimeout = const Duration(seconds: 8);
  }

  final HttpClient client;

  Uri _uri(String path) => Uri.parse('$ngoApiBaseUrl$path');

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
  }) async {
    try {
      final request = await client.getUrl(_uri(path));
      if (bearerToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $bearerToken',
        );
      }
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await _readBody(response);
      _ensureOk(response.statusCode, body);
      return body;
    } on TimeoutException {
      throw NgoApiException(0, message: null);
    } on SocketException {
      throw NgoApiException(0);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final request = await client.postUrl(_uri(path));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await _readBody(response);
      _ensureOk(response.statusCode, body);
      return body;
    } on TimeoutException {
      throw NgoApiException(0, message: null);
    } on SocketException {
      throw NgoApiException(0);
    }
  }

  Future<Map<String, dynamic>> _readBody(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    if (text.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'value': decoded};
  }

  void _ensureOk(int status, Map<String, dynamic> body) {
    if (status < 200 || status >= 300) {
      throw NgoApiException(status, message: body['error'] as String?);
    }
  }
}

/// Farmer program profile from the NGO API.
class FarmerProfile {
  const FarmerProfile({
    required this.id,
    required this.name,
    required this.location,
    required this.language,
  });

  factory FarmerProfile.fromMap(Map<String, dynamic> map) => FarmerProfile(
    id: map['id'] as String,
    name: map['name'] as String,
    location: map['location'] as String? ?? '',
    language: map['language'] as String? ?? 'Hausa',
  );

  final String id;
  final String name;
  final String location;
  final String language;
}

/// Award kinds as sent by the program desk. Grants never become debt.
enum VoucherKind { grant, loan }

enum VoucherStatus { active, spent, closed }

/// A voucher issued to a farmer, denominated in naira.
class VoucherRecord {
  const VoucherRecord({
    required this.id,
    required this.purpose,
    required this.amount,
    required this.remainingNgn,
    required this.amountOwedNgn,
    required this.createdAt,
    required this.kind,
    required this.status,
  });

  factory VoucherRecord.fromMap(Map<String, dynamic> map) => VoucherRecord(
    id: map['id'] as String,
    purpose: map['purpose'] as String? ?? '',
    amount: (map['amount'] as num? ?? 0).toInt(),
    remainingNgn: (map['remainingNgn'] as num? ?? 0).toInt(),
    amountOwedNgn: (map['amountOwedNgn'] as num? ?? 0).toInt(),
    createdAt: map['createdAt'] as String? ?? '',
    kind: switch (map['kind'] as String? ?? 'Grant') {
      'Loan' => VoucherKind.loan,
      _ => VoucherKind.grant,
    },
    status: switch (map['status'] as String? ?? 'Active') {
      'Spent' => VoucherStatus.spent,
      'Closed' => VoucherStatus.closed,
      _ => VoucherStatus.active,
    },
  );

  final String id;
  final String purpose;
  final int amount;
  final int remainingNgn;
  final int amountOwedNgn;
  final String createdAt;
  final VoucherKind kind;
  final VoucherStatus status;

  double get spentFraction =>
      amount <= 0 ? 0 : ((amount - remainingNgn) / amount).clamp(0.0, 1.0);
}

/// Payment states as returned by GET /api/payments/{id}.
enum PaymentState { pending, settled, failed }

/// A dealer payment recorded against a voucher.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.state,
    required this.amountNgn,
    required this.amountSats,
    required this.dealer,
    required this.time,
    this.paymentHash,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    id: map['id'] as String? ?? '',
    state: switch (map['state'] as String? ?? 'Pending') {
      'Settled' => PaymentState.settled,
      'Failed' => PaymentState.failed,
      _ => PaymentState.pending,
    },
    amountNgn: (map['amountNgn'] as num? ?? 0).toInt(),
    amountSats: (map['amountSats'] as num? ?? 0).toInt(),
    dealer: map['dealer'] as String? ?? '',
    time: map['time'] as String? ?? '',
    paymentHash: map['paymentHash'] as String?,
  );

  final String id;
  final PaymentState state;
  final int amountNgn;
  final int amountSats;
  final String dealer;
  final String time;
  final String? paymentHash;
}

class FarmerAccount {
  const FarmerAccount({
    required this.farmerId,
    required this.name,
    required this.balanceNgn,
    required this.history,
  });

  factory FarmerAccount.fromMap(Map<String, dynamic> map) => FarmerAccount(
    farmerId: map['farmerId'] as String,
    name: map['farmerName'] as String,
    balanceNgn: (map['balanceNgn'] as num? ?? 0).toInt(),
    history: (map['history'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FarmerHistoryEntry.fromMap)
        .toList(),
  );

  final String farmerId;
  final String name;
  final int balanceNgn;
  final List<FarmerHistoryEntry> history;
}

class FarmerHistoryEntry {
  const FarmerHistoryEntry({
    required this.kind,
    required this.description,
    required this.amountNgn,
    required this.time,
    this.repaymentType,
    this.note,
  });

  factory FarmerHistoryEntry.fromMap(Map<String, dynamic> map) =>
      FarmerHistoryEntry(
        kind: map['kind'] as String? ?? '',
        description: map['description'] as String? ?? '',
        amountNgn: (map['amountNgn'] as num? ?? 0).toInt(),
        time: map['time'] as String? ?? '',
        repaymentType: map['repaymentType'] as String?,
        note: map['note'] as String?,
      );

  final String kind;
  final String description;
  final int amountNgn;
  final String time;
  final String? repaymentType;
  final String? note;
}
