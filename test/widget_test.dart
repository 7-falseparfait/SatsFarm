import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sats_farm/l10n/app_localizations.dart';
import 'package:sats_farm/l10n/l10n.dart';
import 'package:sats_farm/presentation/screens/farmer_join_screen.dart';
import 'package:sats_farm/presentation/screens/vouchers_screen.dart';
import 'package:sats_farm/providers/voucher_provider.dart';
import 'package:sats_farm/services/ngo_api_service.dart';
import 'package:sats_farm/services/secure_storage_service.dart';

void main() {
  testWidgets('first-time farmer can enter or scan an invite', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => VoucherProvider()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('ha')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FarmerJoinScreen(),
        ),
      ),
    );

    expect(find.text('Join SatsFarm'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Join my program'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('Mutinynet test network'), findsOneWidget);
  });

  testWidgets('joined farmer can see their voucher record', (
    WidgetTester tester,
  ) async {
    final provider = VoucherProvider(
      api: _FarmerApiFake(),
      storage: _SessionStorageFake(),
    );
    await provider.initializeInviteSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('ha')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FarmerHomeScreen(onOpenWallet: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My vouchers'), findsOneWidget);
    expect(
      find.text('SF-2081 · GRANT · ACTIVE\n₦50,000 issued'),
      findsOneWidget,
    );
    expect(find.text('Seed & fertilizer'), findsOneWidget);
    // Once on the balance card and once on the voucher.
    expect(find.text('₦50,000'), findsNWidgets(2));
  });

  testWidgets('farmer sees the dealer and amount before approving a payment', (
    WidgetTester tester,
  ) async {
    final api = _FarmerApiFake();
    final provider = VoucherProvider(
      api: api,
      storage: _SessionStorageFake(),
      paymentPollInterval: Duration.zero,
    );
    await provider.initializeInviteSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('ha')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: FarmerHomeScreen(onOpenWallet: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Redeem at dealer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem at dealer'));
    await tester.pumpAndSettle();
    expect(find.text('Pay dealer'), findsNothing);

    await tester.enterText(find.byType(TextField), 'lntbs${'1' * 80}');
    await tester.tap(find.text('Review payment'));
    await tester.pumpAndSettle();
    expect(find.text('Northern Seeds Co.'), findsOneWidget);
    expect(find.text('₦5,000'), findsOneWidget);
    expect(api.requested, isEmpty, reason: 'reviewing must not pay');

    await tester.tap(find.text('Pay dealer'));
    await tester.pumpAndSettle();
    expect(api.requested, ['/api/payments/request']);
    expect(api.tokens, everyElement('test-session'));
    expect(find.text('Dealer paid on Mutinynet'), findsOneWidget);
    expect(find.text('Pay dealer'), findsNothing);
  });

  group('payment outcome', () {
    Future<VoucherProvider> signedIn(_FarmerApiFake api) async {
      final provider = VoucherProvider(
        api: api,
        storage: _SessionStorageFake(),
        paymentPollInterval: Duration.zero,
      );
      await provider.initializeInviteSession();
      return provider;
    }

    test('a missed status check does not report a failed payment', () async {
      final api = _FarmerApiFake()..statusChecksToDrop = 2;
      final provider = await signedIn(api);
      final payment = await provider.redeem(voucherId: 'SF-2081', invoice: 'x');
      expect(payment.state, PaymentState.settled);
    });

    test('no answer to the request is pending, not failed', () async {
      final api = _FarmerApiFake()..requestError = NgoApiException(0);
      final provider = await signedIn(api);
      final payment = await provider.redeem(voucherId: 'SF-2081', invoice: 'x');
      expect(payment.state, PaymentState.pending);
      expect(provider.error, isNull);
    });

    test('a refusal from the API is a failure with its reason', () async {
      final api = _FarmerApiFake()
        ..requestError = NgoApiException(400, message: 'Not whitelisted');
      final provider = await signedIn(api);
      final payment = await provider.redeem(voucherId: 'SF-2081', invoice: 'x');
      expect(payment.state, PaymentState.failed);
      expect(provider.error, 'Not whitelisted');
    });
  });

  testWidgets('full voucher list scrolls without overflowing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = VoucherProvider(
      api: _FarmerApiFake(voucherCount: 6),
      storage: _SessionStorageFake(),
    );
    await provider.initializeInviteSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('en'), Locale('ha')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: VouchersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Seed & fertilizer'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Voucher 6'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Redeem at dealer').first);
    await tester.pumpAndSettle();
    expect(find.text('Scan dealer QR code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

class _SessionStorageFake extends SecureStorageService {
  @override
  Future<String?> readFarmerSessionToken() async => 'test-session';

  @override
  Future<void> deleteFarmerSessionToken() async {}
}

class _FarmerApiFake extends NgoApiService {
  _FarmerApiFake({this.voucherCount = 1});

  final int voucherCount;
  final List<String> requested = <String>[];
  final List<String?> tokens = <String?>[];
  NgoApiException? requestError;
  int statusChecksToDrop = 0;

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload, {
    String? bearerToken,
  }) async {
    tokens.add(bearerToken);
    if (path == '/api/payments/preview') {
      return {
        'dealer': 'Northern Seeds Co.',
        'amountNgn': 5000,
        'amountSats': 1000,
        'availableAfterNgn': 45000,
      };
    }
    requested.add(path);
    if (requestError != null) throw requestError!;
    return {
      'payment': {'id': 'SF-PAY', 'state': 'Pending'},
    };
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
  }) async {
    if (path == '/api/payments/SF-PAY') {
      if (statusChecksToDrop > 0) {
        statusChecksToDrop -= 1;
        throw NgoApiException(0);
      }
      return {
        'id': 'SF-PAY',
        'state': 'Settled',
        'amountNgn': 5000,
        'amountSats': 1000,
      };
    }
    if (path == '/api/farmer/account') {
      return {
        'farmerId': 'F-1042',
        'farmerName': 'Amina Yusuf',
        'balanceNgn': 50000,
        'history': [],
      };
    }
    if (path == '/api/farmers/F-1042/vouchers') {
      return {
        'value': List.generate(voucherCount, (index) {
          final isFirst = index == 0;
          return {
            'id': isFirst ? 'SF-2081' : 'SF-${index + 1}',
            'farmerId': 'F-1042',
            'purpose': isFirst ? 'Seed & fertilizer' : 'Voucher ${index + 1}',
            'amount': 50000,
            'remainingNgn': 50000,
            'createdAt': '18 Oct 2026',
            'status': 'Active',
            'kind': 'Grant',
          };
        }),
      };
    }
    throw StateError('Unexpected API request: $path');
  }
}
