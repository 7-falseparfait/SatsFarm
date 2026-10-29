/// Network configuration for development. Never use these endpoints as a
/// substitute for an independently operated backend in production.
enum BitcoinNetwork { mutinynet, signet, testnet }

class AppConstants {
  const AppConstants._();

  /// Mutinynet is the shared, valueless Signet environment for development.
  static const BitcoinNetwork network = BitcoinNetwork.mutinynet;
  static const String mutinynetEsploraUrl = 'https://mutinynet.com/api';
  static const String mutinynetRgsUrl = 'https://rgs.mutinynet.com/snapshot/0';
  static const String signetEsploraUrl = 'https://blockstream.info/signet/api';
  static const String testnetEsploraUrl =
      'https://blockstream.info/testnet/api';
  static const int mockNgnPerSatoshi = 5;
}
