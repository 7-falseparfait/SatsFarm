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
}

class _FarmerApiFake extends NgoApiService {
  _FarmerApiFake({this.voucherCount = 1});

  final int voucherCount;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
  }) async {
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
