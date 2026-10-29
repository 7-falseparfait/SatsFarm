//! SatsFarm Lightning test harness.
//!
//! Proves a real Lightning payment on Mutinynet (a shared, valueless signet)
//! between two ldk-node 0.7.1 nodes run in one process:
//!   funder (port 9735) -> dealer (port 9736)
//!
//! MUTINYNET TEST NETWORK ONLY. No mainnet code paths exist in this file.

use std::env;
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use ldk_node::bitcoin::Network;
use ldk_node::lightning::ln::msgs::SocketAddress;
use ldk_node::lightning_invoice::{Bolt11InvoiceDescription, Description};
use ldk_node::logger::LogLevel;
use ldk_node::{Builder, Node};

const TAG: &str = "MUTINYNET (custom signet) TEST NETWORK ONLY";
const NODE_VERSION: &str = "ldk-node 0.7.1";

// Network settings copied from the Flutter app's LDK setup, see:
//   lib/core/constants/app_constants.dart  (lines 9-11)
//   lib/services/ldk_service.dart          (setEsploraServer / setGossipSourceRgs)
const MUTINYNET_ESPLORA_URL: &str = "https://mutinynet.com/api";
const MUTINYNET_RGS_URL: &str = "https://rgs.mutinynet.com/snapshot/0";

const FUNDER_DIR: &str = "./data/funder";
const FUNDER_PORT: u16 = 9735;
const FUNDER_ALIAS: &str = "FunderTest";
const DEALER_DIR: &str = "./data/dealer";
const DEALER_PORT: u16 = 9736;
const DEALER_ALIAS: &str = "DealerTest";

const CHANNEL_SATS: u64 = 40_000;
const PAYMENT_SATS: u64 = 1_000;
const HUGE_INVOICE_SATS: u64 = 1_000_000;
const INVOICE_EXPIRY_SECS: u32 = 3600;
const POLL_SECS: u64 = 5;
const CHANNEL_WAIT_TIMEOUT: Duration = Duration::from_secs(60 * 30);

fn now_secs() -> u64 {
	SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()
}

fn to_hex(bytes: &[u8]) -> String {
	let mut s = String::with_capacity(bytes.len() * 2);
	for b in bytes {
		s.push_str(&format!("{b:02x}"));
	}
	s
}

struct Nodes {
	funder: Arc<Node>,
	dealer: Arc<Node>,
}

fn build_node(dir: &str, port: u16, alias: &str) -> Arc<Node> {
	let mut builder = Builder::new();

	builder
		.set_entropy_seed_path(format!("{dir}/seed"))
		.set_storage_dir_path(dir.to_string())
		.set_network(Network::Signet)
		.set_chain_source_esplora(MUTINYNET_ESPLORA_URL.to_string(), None)
		.set_gossip_source_rgs(MUTINYNET_RGS_URL.to_string())
		.set_listening_addresses(vec![
			SocketAddress::from_str(&format!("0.0.0.0:{port}")).expect("valid socket address"),
		])
		.expect("valid listening addresses")
		.set_node_alias(alias.to_string())
		.expect("valid node alias")
		.set_filesystem_logger(Some(format!("{dir}/ldk.log")), Some(LogLevel::Debug));

	let node = builder.build().expect("node build must succeed");
	let node = Arc::new(node);
	eprintln!(
		"[{alias}] built with {NODE_VERSION}, network=SIGNET for {TAG}, esplora={MUTINYNET_ESPLORA_URL}, rgs={MUTINYNET_RGS_URL}"
	);
	node.start().expect("node start must succeed");
	eprintln!("[{alias}] started, node_id={}", node.node_id());
	node
}

fn build_nodes() -> Nodes {
	let funder = build_node(FUNDER_DIR, FUNDER_PORT, FUNDER_ALIAS);
	let dealer = build_node(DEALER_DIR, DEALER_PORT, DEALER_ALIAS);
	Nodes { funder, dealer }
}

fn best_effort_sync(node: &Arc<Node>, label: &str) {
	if let Err(e) = node.sync_wallets() {
		eprintln!("[{label}] manual wallet sync skipped/failed ({e:?}); relying on background sync state.");
	}
}

fn sync_and_report_balances(nodes: &Nodes) {
	best_effort_sync(&nodes.funder, "funder");
	best_effort_sync(&nodes.dealer, "dealer");
	let f = nodes.funder.list_balances();
	let d = nodes.dealer.list_balances();
	eprintln!("[balances @{}]", now_secs());
	eprintln!(
		"  funder: total_onchain={} sat, spendable_onchain={} sat, anchor_reserve={} sat, lightning={} sat",
		f.total_onchain_balance_sats,
		f.spendable_onchain_balance_sats,
		f.total_anchor_channels_reserve_sats,
		f.total_lightning_balance_sats
	);
	eprintln!(
		"  dealer: total_onchain={} sat, spendable_onchain={} sat, anchor_reserve={} sat, lightning={} sat",
		d.total_onchain_balance_sats,
		d.spendable_onchain_balance_sats,
		d.total_anchor_channels_reserve_sats,
		d.total_lightning_balance_sats
	);
}

fn print_funder_address(nodes: &Nodes) {
	let addr = nodes.funder.onchain_payment().new_address().expect("address creation must succeed");
	eprintln!("[funder] MUTINYNET on-chain receive address: {addr}");
}

fn print_channels(nodes: &Nodes) {
	let fch = nodes.funder.list_channels();
	eprintln!("[funder] channels: {}", fch.len());
	for (i, c) in fch.iter().enumerate() {
		eprintln!(
			"  ch{i}: counterparty={} value={}sats outbound={}msat inbound={}msat ready={} usable={} required_confs={:?} current_confs={:?} funding={:?} scid={:?}",
			c.counterparty_node_id,
			c.channel_value_sats,
			c.outbound_capacity_msat,
			c.inbound_capacity_msat,
			c.is_channel_ready,
			c.is_usable,
			c.confirmations_required,
			c.confirmations,
			c.funding_txo.map(|f| f.to_string()),
			c.short_channel_id
		);
	}
	let dch = nodes.dealer.list_channels();
	eprintln!("[dealer] channels: {}", dch.len());
	for (i, c) in dch.iter().enumerate() {
		eprintln!(
			"  ch{i}: counterparty={} value={}sats outbound={}msat inbound={}msat ready={} usable={} required_confs={:?} current_confs={:?}",
			c.counterparty_node_id,
			c.channel_value_sats,
			c.outbound_capacity_msat,
			c.inbound_capacity_msat,
			c.is_channel_ready,
			c.is_usable,
			c.confirmations_required,
			c.confirmations
		);
	}
}

// --- Phase: setup (steps 1-3) -------------------------------------------------
fn phase_setup() {
	let nodes = build_nodes();
	print_funder_address(&nodes);
	print_channels(&nodes);
}

// --- Phase: fund (step 4) -----------------------------------------------------
fn phase_fund() {
	let nodes = build_nodes();
		print_funder_address(&nodes);
		sync_and_report_balances(&nodes);

		eprintln!(
			"Waiting for funding on {TAG}. Polling every {POLL_SECS}s. Stop with Ctrl-C once confirmed."
		);
		loop {
			std::thread::sleep(Duration::from_secs(POLL_SECS));
			let f = nodes.funder.list_balances();
			if f.total_onchain_balance_sats > 0 {
				eprintln!("[funder] ON-CHAIN FUNDS DETECTED via {TAG}.");
				sync_and_report_balances(&nodes);
				return;
			}
		eprintln!(
			"[balances @{}] funder: total_onchain={} sat. Waiting for more confirmations/reserve arrival...",
			now_secs(),
			f.total_onchain_balance_sats
		);
	}
}

// --- Phase: channel (step 5) --------------------------------------------------
fn phase_channel() {
	let nodes = build_nodes();
	best_effort_sync(&nodes.funder, "funder");
	let bal = nodes.funder.list_balances();
	eprintln!(
		"[funder] pre-open on-chain: total={} spendable={} anchor_reserve={}",
		bal.total_onchain_balance_sats,
		bal.spendable_onchain_balance_sats,
		bal.total_anchor_channels_reserve_sats
	);

	nodes
		.funder
		.connect(nodes.dealer.node_id(), SocketAddress::from_str("127.0.0.1:9736").unwrap(), true)
		.expect("connect funder -> dealer must succeed");
	eprintln!("[funder] connected to dealer");

	let existing = nodes
		.funder
		.list_channels()
		.into_iter()
		.find(|c| c.counterparty_node_id == nodes.dealer.node_id());
	match existing {
		Some(c) => eprintln!(
			"[funder] channel to dealer already exists (value={}sats required={:?} had={:?}); skipping open.",
			c.channel_value_sats, c.confirmations_required, c.confirmations
		),
		None => {
			nodes
				.funder
				.open_channel(
					nodes.dealer.node_id(),
					SocketAddress::from_str("127.0.0.1:9736").unwrap(),
					CHANNEL_SATS,
					None,
					None,
				)
				.expect("channel open must succeed");
			eprintln!(
				"[funder] channel open initiated ({CHANNEL_SATS} sats) on {TAG}. Polling every {POLL_SECS}s until usable."
			);
		},
	}

	let deadline = SystemTime::now() + CHANNEL_WAIT_TIMEOUT;
	loop {
		std::thread::sleep(Duration::from_secs(POLL_SECS));
		print_channels(&nodes);
		if let Some(c) = nodes.funder.list_channels().into_iter().find(|c| c.is_usable) {
			eprintln!(
				"[funder] CHANNEL USABLE on {TAG}: requires {:?} confirmations per dealer (fundee); has {:?}; max_outbound={}msat",
				c.confirmations_required, c.confirmations, c.outbound_capacity_msat
			);
			return;
		}
		if SystemTime::now() > deadline {
			panic!("Timed out waiting for a usable channel on {TAG}.");
		}
	}
}

// --- Phase: pay (steps 6-8) ---------------------------------------------------
fn run_event_watcher(node: Arc<Node>, label: &'static str, expected: usize, done: Arc<std::sync::atomic::AtomicBool>) {
	let mut handled = 0;
	while handled < expected && !done.load(std::sync::atomic::Ordering::SeqCst) {
		let event = node.wait_next_event();
		eprintln!("[{label}] EVENT @{}: {:?}", now_secs(), event);
		match &event {
			ldk_node::Event::PaymentSuccessful { payment_hash, payment_preimage, .. } => {
				eprintln!(
					"[{label}] SUCCESS proof: payment_hash={} preimage={}",
					to_hex(&payment_hash.0),
					payment_preimage.map(|p| to_hex(&p.0)).unwrap_or_default()
				);
				done.store(true, std::sync::atomic::Ordering::SeqCst);
				handled += 1;
			},
			ldk_node::Event::PaymentReceived { payment_hash, amount_msat, .. } => {
				eprintln!(
					"[{label}] RECEIVED: payment_hash={} amount={}msat",
					to_hex(&payment_hash.0),
					amount_msat
				);
				done.store(true, std::sync::atomic::Ordering::SeqCst);
				handled += 1;
			},
			ldk_node::Event::PaymentFailed { payment_hash, reason, .. } => {
				eprintln!(
					"[{label}] FAILED: payment_hash={:?} reason={:?}",
					payment_hash.map(|h| to_hex(&h.0)),
					reason
				);
				done.store(true, std::sync::atomic::Ordering::SeqCst);
				handled += 1;
			},
			_ => {},
		}
		node.event_handled().expect("event handling must succeed");
	}
}

fn phase_pay() {
	let nodes = build_nodes();
	best_effort_sync(&nodes.funder, "funder");
	best_effort_sync(&nodes.dealer, "dealer");

	// Make sure the peers and their channel are connected/ready before paying.
	nodes
		.funder
		.connect(nodes.dealer.node_id(), SocketAddress::from_str("127.0.0.1:9736").unwrap(), true)
		.expect("connect funder -> dealer must succeed");
	eprintln!("[funder] connected to dealer");

	let deadline = SystemTime::now() + Duration::from_secs(90);
	loop {
		let ch = nodes.funder.list_channels().into_iter().find(|c| c.is_usable);
		if let Some(c) = ch {
			eprintln!("[funder] channel ready for payment (outbound={}msat).", c.outbound_capacity_msat);
			break;
		}
		if SystemTime::now() > deadline {
			panic!("Channel to dealer not usable within 90s on {TAG}.");
		}
		std::thread::sleep(Duration::from_secs(POLL_SECS));
	}

	// Step 6: dealer creates the invoice.
	let amount_msat = PAYMENT_SATS * 1_000;
	let description = Bolt11InvoiceDescription::Direct(
		Description::new("SatsFarm test payment".to_string()).expect("valid description"),
	);
	let invoice = nodes
		.dealer
		.bolt11_payment()
		.receive(amount_msat, &description, INVOICE_EXPIRY_SECS)
		.expect("invoice creation must succeed");
	eprintln!("[dealer] INVOICE ({PAYMENT_SATS} sats):\n{}", invoice);

	let done = Arc::new(std::sync::atomic::AtomicBool::new(false));
	let funder_watcher = {
		let funder = Arc::clone(&nodes.funder);
		let done = Arc::clone(&done);
		std::thread::spawn(move || run_event_watcher(funder, "funder", 1, done))
	};
	let dealer_watcher = {
		let dealer = Arc::clone(&nodes.dealer);
		let done = Arc::clone(&done);
		std::thread::spawn(move || run_event_watcher(dealer, "dealer", 1, done))
	};

	// Step 7: funder pays the invoice.
	let payment_id = nodes.funder.bolt11_payment().send(&invoice, None).expect("payment must initiate");
	eprintln!("[funder] payment initiated: payment_id={:?}", payment_id);

	funder_watcher.join().expect("funder watcher must not panic");
	// Allow the dealer-side watcher a short grace period to observe receipt.
	std::thread::sleep(Duration::from_secs(10));
	dealer_watcher.join().expect("dealer watcher must not panic");

	use ldk_node::payment::PaymentKind;
	if let Some(p) = nodes.funder.payment(&payment_id) {
		let preimage = match &p.kind {
			PaymentKind::Bolt11 { preimage, .. } => preimage.map(|x| to_hex(&x.0)),
			_ => None,
		};
		eprintln!(
			"[funder] payment store: direction={:?} status={:?} amount_msat={:?} fee_paid_msat={:?} preimage={:?}",
			p.direction, p.status, p.amount_msat, p.fee_paid_msat, preimage
		);
	}
	if let Some(p) = nodes.dealer.payment(&payment_id) {
		let preimage = match &p.kind {
			PaymentKind::Bolt11 { preimage, .. } => preimage.map(|x| to_hex(&x.0)),
			_ => None,
		};
		eprintln!(
			"[dealer] payment store: direction={:?} status={:?} amount_msat={:?} preimage={:?}",
			p.direction, p.status, p.amount_msat, preimage
		);
	}
}

// --- Phase: fail (step 9) -----------------------------------------------------
fn phase_fail() {
	let nodes = build_nodes();
	best_effort_sync(&nodes.funder, "funder");

	// Connect + wait for the channel so the first (successful) part of the
	// duplicate-payment test reflects a normal paying state.
	nodes
		.funder
		.connect(nodes.dealer.node_id(), SocketAddress::from_str("127.0.0.1:9736").unwrap(), true)
		.expect("connect funder -> dealer must succeed");
	let deadline = SystemTime::now() + Duration::from_secs(90);
	loop {
		if nodes.funder.list_channels().iter().any(|c| c.is_usable) {
			break;
		}
		if SystemTime::now() > deadline {
			panic!("Channel to dealer not usable within 90s on {TAG}.");
		}
		std::thread::sleep(Duration::from_secs(POLL_SECS));
	}

	let description = Bolt11InvoiceDescription::Direct(
		Description::new("SatsFarm test payment".to_string()).expect("valid description"),
	);
	let invoice = nodes
		.dealer
		.bolt11_payment()
		.receive(PAYMENT_SATS * 1_000, &description, INVOICE_EXPIRY_SECS)
		.expect("invoice creation must succeed");

	let done = Arc::new(std::sync::atomic::AtomicBool::new(false));
	let funder_watcher = {
		let funder = Arc::clone(&nodes.funder);
		let done = Arc::clone(&done);
		std::thread::spawn(move || run_event_watcher(funder, "funder", 1, done))
	};

	// 9a: pay, then attempt to pay the same invoice again.
	let first = nodes.funder.bolt11_payment().send(&invoice, None);
	eprintln!("[fail 9a] first send of invoice: {:?}", first);
	let dup_result = nodes.funder.bolt11_payment().send(&invoice, None);
	eprintln!("[fail 9a] duplicate send of same invoice: {:?}", dup_result);

	funder_watcher.join().expect("funder watcher must not panic");

	// 9b: invoice far larger than the channel can send.
	let huge_desc = Bolt11InvoiceDescription::Direct(
		Description::new("SatsFarm oversize test".to_string()).expect("valid description"),
	);
	let huge_invoice = nodes
		.dealer
		.bolt11_payment()
		.receive(HUGE_INVOICE_SATS * 1_000, &huge_desc, INVOICE_EXPIRY_SECS)
		.expect("huge invoice creation must succeed");
	let huge_send = nodes.funder.bolt11_payment().send(&huge_invoice, None);
	eprintln!("[fail 9b] send {HUGE_INVOICE_SATS} sats invoice: {:?}", huge_send);
}

fn main() {
	let phase = env::args().nth(1).unwrap_or_else(|| "setup".to_string());
	eprintln!("=== {TAG} === phase '{phase}' - {NODE_VERSION} - now={}", now_secs());
	match phase.as_str() {
		"setup" => phase_setup(),
		"fund" => phase_fund(),
		"channel" => phase_channel(),
		"pay" => phase_pay(),
		"fail" => phase_fail(),
		other => {
			eprintln!("Unknown phase '{other}'. Use one of: setup fund channel pay fail");
			std::process::exit(2);
		},
	}
}
