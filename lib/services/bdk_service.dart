import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:bech32/bech32.dart' as bech32;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/ripemd160.dart';

import '../core/constants/app_constants.dart';

/// BDK descriptor wallet wrapper. Native package support currently targets
/// Android/iOS; callers should gate initialization on supported platforms.
class BdkService {
  bdk.Wallet? _wallet;
  bdk.Blockchain? _blockchain;
  bip32.BIP32? _linuxMasterKey;
  int _nextReceiveIndex = 0;
  int get nextReceiveIndex => _nextReceiveIndex;

  Future<String> generateMnemonic({int words = 12}) async {
    final strength = switch (words) {
      12 => 128,
      24 => 256,
      _ => throw ArgumentError.value(words, 'words', 'Use 12 or 24'),
    };
    // Seed generation does not depend on the BDK native bridge, which has no
    // Linux implementation in bdk_flutter 0.31.3.
    return bip39.generateMnemonic(strength: strength);
  }

  Future<void> initialize({
    required String mnemonicPhrase,
    int nextReceiveIndex = 0,
    BitcoinNetwork network = AppConstants.network,
  }) async {
    _nextReceiveIndex = nextReceiveIndex;
    if (defaultTargetPlatform == TargetPlatform.linux) {
      if (!bip39.validateMnemonic(mnemonicPhrase)) {
        throw const FormatException(
          'The recovery phrase is not a valid BIP39 mnemonic.',
        );
      }
      final testnetBip32 = bip32.NetworkType(
        wif: 0xef,
        bip32: bip32.Bip32Type(public: 0x043587cf, private: 0x04358394),
      );
      _linuxMasterKey = bip32.BIP32.fromSeed(
        bip39.mnemonicToSeed(mnemonicPhrase),
        testnetBip32,
      );
      return;
    }

    final bdkNetwork = switch (network) {
      BitcoinNetwork.mutinynet || BitcoinNetwork.signet => bdk.Network.signet,
      BitcoinNetwork.testnet => bdk.Network.testnet,
    };
    final mnemonic = await bdk.Mnemonic.fromString(mnemonicPhrase);
    final secret = await bdk.DescriptorSecretKey.create(
      network: bdkNetwork,
      mnemonic: mnemonic,
    );
    final external = await bdk.Descriptor.newBip84(
      secretKey: secret,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.externalChain,
    );
    final internal = await bdk.Descriptor.newBip84(
      secretKey: secret,
      network: bdkNetwork,
      keychain: bdk.KeychainKind.internalChain,
    );
    _wallet = await bdk.Wallet.create(
      descriptor: external,
      changeDescriptor: internal,
      network: bdkNetwork,
      databaseConfig: const bdk.DatabaseConfig.memory(),
    );
    final url = switch (network) {
      BitcoinNetwork.mutinynet => AppConstants.mutinynetEsploraUrl,
      BitcoinNetwork.signet => AppConstants.signetEsploraUrl,
      BitcoinNetwork.testnet => AppConstants.testnetEsploraUrl,
    };
    _blockchain = await bdk.Blockchain.create(
      config: bdk.BlockchainConfig.esplora(
        config: bdk.EsploraConfig(
          baseUrl: url,
          stopGap: BigInt.from(20),
          concurrency: 4,
        ),
      ),
    );
  }

  Future<String> getAddress() async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      final masterKey = _linuxMasterKey;
      if (masterKey == null) {
        throw StateError(
          'Create or restore a wallet before generating an address.',
        );
      }
      final child = masterKey.derivePath("m/84'/1'/0'/0/$_nextReceiveIndex");
      _nextReceiveIndex++;
      final publicKeyHash = RIPEMD160Digest().process(
        Uint8List.fromList(crypto.sha256.convert(child.publicKey).bytes),
      );
      return bech32.segwit.encode(bech32.Segwit('tb', 0, publicKeyHash));
    }
    final wallet = _wallet;
    if (wallet == null) throw StateError('Initialize the BDK wallet first.');
    return wallet
        .getAddress(
          addressIndex: bdk.AddressIndex.reset(index: _nextReceiveIndex++),
        )
        .address
        .toString();
  }

  Future<int> syncAndGetBalance() async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      throw UnsupportedError(
        'On-chain balance sync requires a Linux BDK native backend, which bdk_flutter 0.31.3 does not provide.',
      );
    }
    final wallet = _wallet;
    final blockchain = _blockchain;
    if (wallet == null || blockchain == null) {
      throw StateError('Initialize the BDK wallet first.');
    }
    await wallet.sync(blockchain: blockchain);
    return wallet.getBalance().total.toInt();
  }

  Future<int> getBalance() async {
    if (defaultTargetPlatform == TargetPlatform.linux) return 0;
    final wallet = _wallet;
    if (wallet == null) throw StateError('Initialize the BDK wallet first.');
    return wallet.getBalance().total.toInt();
  }
}
