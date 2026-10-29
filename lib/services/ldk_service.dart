import 'package:ldk_node/ldk_node.dart' as ldk;

import '../core/constants/app_constants.dart';

/// LDK Node wrapper. Native library support in ldk_node 0.3.0 is mobile only.
class LdkService {
  ldk.Node? _node;
  Stream<ldk.Event>? _events;
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  Stream<ldk.Event>? get events => _events;

  Future<void> initialize({
    required String mnemonicPhrase,
    required String storageDirectory,
    BitcoinNetwork network = AppConstants.network,
  }) async {
    final ldkNetwork = switch (network) {
      BitcoinNetwork.mutinynet || BitcoinNetwork.signet => ldk.Network.signet,
      BitcoinNetwork.testnet => ldk.Network.testnet,
    };
    final config = ldk.Config(
      probingLiquidityLimitMultiplier: BigInt.from(3),
      trustedPeers0Conf: [],
      storageDirPath: storageDirectory,
      network: ldkNetwork,
      listeningAddresses: [],
      onchainWalletSyncIntervalSecs: BigInt.from(60),
      walletSyncIntervalSecs: BigInt.from(30),
      feeRateCacheUpdateIntervalSecs: BigInt.from(600),
      logLevel: ldk.LogLevel.info,
      defaultCltvExpiryDelta: 144,
    );
    final builder = ldk.Builder.fromConfig(config: config)
        .setEntropyBip39Mnemonic(
          mnemonic: ldk.Mnemonic(seedPhrase: mnemonicPhrase),
        )
        .setEsploraServer(switch (network) {
          BitcoinNetwork.mutinynet => AppConstants.mutinynetEsploraUrl,
          BitcoinNetwork.signet => AppConstants.signetEsploraUrl,
          BitcoinNetwork.testnet => AppConstants.testnetEsploraUrl,
        });
    if (network == BitcoinNetwork.mutinynet) {
      // Use Mutinynet's graph snapshot for faster Lightning startup.
      builder.setGossipSourceRgs(AppConstants.mutinynetRgsUrl);
    }
    _node = await builder.build();
  }

  Future<void> start() async {
    final node = _node ?? (throw StateError('Initialize the LDK node first.'));
    await node.start();
    _isRunning = true;
    _events = _watchEvents(node);
    await node.syncWallets();
  }

  Stream<ldk.Event> _watchEvents(ldk.Node node) async* {
    while (true) {
      yield await node.nextEventAsync();
    }
  }

  Future<String> createInvoice({
    required int amountSats,
    required String description,
    int expirySeconds = 3600,
  }) async {
    final node = _node ?? (throw StateError('Initialize the LDK node first.'));
    final handler = await node.bolt11Payment();
    final invoice = await handler.receive(
      amountMsat: BigInt.from(amountSats) * BigInt.from(1000),
      description: description,
      expirySecs: expirySeconds,
    );
    return invoice.toString();
  }

  Future<int> lightningBalanceSats() async {
    final node = _node;
    if (node == null) return 0;
    final balances = await node.listBalances();
    return balances.totalLightningBalanceSats.toInt();
  }

  Future<void> stop() async {
    await _node?.stop();
    _isRunning = false;
  }
}
