//! Lightning runtime for the SatsFarm demo API (test-network only).
//!
//! MUTINYNET (custom signet) TEST NETWORK ONLY. This runs two ldk-node
//! 0.7.1 nodes in the API process:
//!   funder -> the NGO node that pays dealer invoices (port 9735)
//!   dealer -> demo dealer node for end-to-end tests (port 9736)
//! Storage lives under `data/ln/funder` and `data/ln/dealer` (seed files are
//! written to disk there and are never printed or logged).
//!
//! The naira<->sats conversion uses a fixed demo rate, mirroring the Flutter
//! app constant `mockNgnPerSatoshi` (lib/core/constants/app_constants.dart:15).
//! It is explicitly NOT a live price. Every payment stores the rate it used.

use std::path::Path;
use std::str::FromStr;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;

use ldk_node::bitcoin::secp256k1::PublicKey;
use ldk_node::lightning::ln::msgs::SocketAddress;
use ldk_node::lightning_invoice::{Bolt11Invoice, Bolt11InvoiceDescription, Description};
use ldk_node::logger::LogLevel;
use ldk_node::payment::PaymentKind;
use ldk_node::{Builder, Event, Node};
use rusqlite::{Connection, params};

pub const TAG: &str = "MUTINYNET (custom signet) TEST NETWORK ONLY";

// Fixed demo rate. Clearly labeled as such in every response that uses it.
pub const RATE_NGN_PER_SAT: i64 = 5;
pub const RATE_LABEL: &str = "FIXED DEMO RATE: 5 NGN per sat (not a live price)";

// Same endpoints as the Flutter app's LDK setup
// (lib/core/constants/app_constants.dart:10-11, lib/services/ldk_service.dart).
pub const NODE_VERSION: &str = "ldk-node (vendored 0.7.1 with 120s BDK sync-timeout patch)";

const MUTINYNET_ESPLORA_URL: &str = "https://mutinynet.com/api";
const MUTINYNET_RGS_URL: &str = "https://rgs.mutinynet.com/snapshot/0";

pub const FUNDER_PORT: u16 = 9735;
pub const DEALER_PORT: u16 = 9736;

pub type Db = Arc<Mutex<Connection>>;

static RUNTIME: OnceLock<Arc<LnRuntime>> = OnceLock::new();

pub struct LnRuntime {
    pub funder: Arc<Node>,
    pub dealer: Arc<Node>,
}

#[derive(Debug)]
pub enum LnError {
    NotRunning,
    NotWhitelisted,
    InsufficientVoucher(String),
    Duplicate,
    SendFailed(String),
    InvalidInvoice(String),
    Internal(String),
}

pub fn runtime() -> Option<&'static Arc<LnRuntime>> {
    RUNTIME.get()
}

pub fn to_hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push_str(&format!("{b:02x}"));
    }
    out
}

/// Spawn the LN bootstrap in a background thread so the HTTP API binds fast.
/// The status route reports readiness.
pub fn bootstrap(db: Db) {
    std::thread::spawn(move || {
        let funder_dir =
            std::env::var("SATSFARM_LN_FUNDER_DIR").unwrap_or_else(|_| "data/ln/funder".to_owned());
        let dealer_dir =
            std::env::var("SATSFARM_LN_DEALER_DIR").unwrap_or_else(|_| "data/ln/dealer".to_owned());
        match build_runtime(&funder_dir, &dealer_dir) {
            Ok(rt) => {
                eprintln!("SatsFarm LN ({NODE_VERSION}) ready for {TAG}.");
                let rt = Arc::new(rt);
                reconcile_pending_payments(&rt.funder, &db);
                spawn_event_watchers(&rt, db);
                if RUNTIME.set(rt).is_err() {
                    eprintln!("LN runtime already bootstrapped; ignoring duplicate.");
                }
            }
            Err(e) => {
                eprintln!(
                    "LN bootstrap FAILED for {TAG}: {e}. Lightning routes will report as unavailable."
                );
            }
        }
    });
}

fn build_node(dir: &str, port: u16, alias: &str) -> ldk_node::Node {
    let mut builder = Builder::new();
    builder
        .set_entropy_seed_path(format!("{dir}/seed"))
        .set_storage_dir_path(dir.to_string())
        .set_network(ldk_node::bitcoin::Network::Signet)
        .set_chain_source_esplora(MUTINYNET_ESPLORA_URL.to_string(), None)
        .set_gossip_source_rgs(MUTINYNET_RGS_URL.to_string())
        .set_listening_addresses(vec![
            SocketAddress::from_str(&format!("0.0.0.0:{port}")).expect("valid socket address"),
        ])
        .expect("valid listening addresses")
        .set_node_alias(alias.to_string())
        .expect("valid node alias")
        .set_filesystem_logger(Some(format!("{dir}/ldk.log")), Some(LogLevel::Debug));
    let node = Arc::new(builder.build().expect("LN node build must succeed"));
    node.start().expect("LN node start must succeed");
    eprintln!("[{alias}] started, node_id={}", node.node_id());
    Arc::into_inner(node).expect("freshly built node has no other refs")
}

fn build_runtime(funder_dir: &str, dealer_dir: &str) -> Result<LnRuntime, String> {
    create_data_dirs(&[funder_dir, dealer_dir])?;
    eprintln!("SatsFarm LN starting for {TAG} - {NODE_VERSION}.");
    eprintln!(
        "funding: esplora={MUTINYNET_ESPLORA_URL}, rgs={MUTINYNET_RGS_URL}, rate: {RATE_LABEL}"
    );
    let funder = Arc::new(build_node(funder_dir, FUNDER_PORT, "FunderNg"));
    let dealer = Arc::new(build_node(dealer_dir, DEALER_PORT, "DealerNg"));
    // Best-effort first sync; the background sync is authoritative (see
    // lessons from the harness runs - manual syncs can time out with
    // WalletOperationTimeout while Mutinynet Esplora throttles).
    if let Err(e) = funder.sync_wallets() {
        eprintln!("[funder] best-effort wallet sync skipped ({e:?}); relying on background sync.");
    }
    connect_funder_to_dealer(&funder, &dealer);
    Ok(LnRuntime { funder, dealer })
}

fn create_data_dirs(dirs: &[&str]) -> Result<(), String> {
    for dir in dirs {
        if !Path::new(dir).exists() && std::fs::create_dir_all(dir).is_err() {
            return Err(format!("could not create LN storage dir {dir}"));
        }
    }
    Ok(())
}

fn connect_funder_to_dealer(funder: &Arc<Node>, dealer: &Arc<Node>) {
    let addr = SocketAddress::from_str(&format!("127.0.0.1:{DEALER_PORT}")).expect("valid addr");
    let deadline = std::time::Instant::now() + Duration::from_secs(60);
    let mut attempt = 0;
    loop {
        attempt += 1;
        match funder.connect(dealer.node_id(), addr.clone(), true) {
            Ok(()) => {
                eprintln!("[funder] connected to dealer.");
                return;
            }
            Err(e) => {
                if std::time::Instant::now() > deadline {
                    eprintln!(
                        "[funder] could not connect to dealer ({e:?}); will rely on peer reconnect."
                    );
                    return;
                }
                eprintln!("[funder] dealer connect attempt {attempt} failed ({e:?}); retrying.");
                std::thread::sleep(Duration::from_secs(3));
            }
        }
    }
}

/// On startup, bring stale Pending DB rows in line with the funder's own
/// payment store (covers payments that were initiated before a restart).
fn reconcile_pending_payments(funder: &Arc<Node>, db: &Db) {
    type Rows = Vec<(String, String)>;
    let rows: Rows = {
        let connection = match db.lock() {
            Ok(c) => c,
            Err(_) => return,
        };
        let mut stmt = match connection.prepare(
			"SELECT id, payment_hash FROM payments WHERE state = 'Pending' AND payment_hash IS NOT NULL",
		) {
			Ok(s) => s,
			Err(e) => { eprintln!("LN reconcile prepare failed: {e}"); return; },
		};
        match stmt
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
            .map(|r| r.collect::<Result<Vec<_>, _>>())
        {
            Ok(Ok(v)) => v,
            Ok(Err(e)) => {
                eprintln!("LN reconcile query failed: {e}");
                return;
            }
            Err(e) => {
                eprintln!("LN reconcile failed: {e}");
                return;
            }
        }
    };
    for (_id, hash_hex) in rows {
        let bytes = match hex_to_bytes(&hash_hex) {
            Some(b) => b,
            None => continue,
        };
        let mut payment_id_bytes = [0u8; 32];
        if bytes.len() != 32 {
            continue;
        }
        payment_id_bytes.copy_from_slice(&bytes);
        if let Some(details) = funder.payment(&ldk_node::lightning::ln::channelmanager::PaymentId(
            payment_id_bytes,
        )) {
            let state = match details.status {
                ldk_node::payment::PaymentStatus::Succeeded => Some("Settled"),
                ldk_node::payment::PaymentStatus::Failed => Some("Failed"),
                ldk_node::payment::PaymentStatus::Pending => None,
            };
            if let Some(new_state) = state {
                let preimage = match &details.kind {
                    PaymentKind::Bolt11 { preimage, .. } => preimage.map(|p| to_hex(&p.0)),
                    _ => None,
                };
                if let Ok(connection) = db.lock() {
                    let _ = connection.execute(
						"UPDATE payments SET state = ?2, preimage = COALESCE(?3, preimage) WHERE payment_hash = ?1 AND state = 'Pending'",
						params![hash_hex, new_state, preimage],
					);
                }
            }
        }
    }
}

fn hex_to_bytes(hex: &str) -> Option<Vec<u8>> {
    let hex = hex.trim();
    if !hex.len().is_multiple_of(2) || hex.is_empty() || !hex.bytes().all(|b| b.is_ascii_hexdigit())
    {
        return None;
    }
    (0..hex.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).ok())
        .collect()
}

fn spawn_event_watchers(rt: &Arc<LnRuntime>, db: Db) {
    {
        let funder = Arc::clone(&rt.funder);
        let db = Arc::clone(&db);
        std::thread::spawn(move || {
            loop {
                let event = funder.wait_next_event();
                match &event {
                    Event::PaymentSuccessful {
                        payment_hash,
                        payment_preimage,
                        ..
                    } => {
                        on_funder_payment_settled(
                            &db,
                            &to_hex(&payment_hash.0),
                            payment_preimage.as_ref().map(|p| to_hex(&p.0)),
                        );
                    }
                    Event::PaymentFailed {
                        payment_hash,
                        reason,
                        ..
                    } => {
                        let hash_hex = payment_hash
                            .as_ref()
                            .map(|h| to_hex(&h.0))
                            .unwrap_or_default();
                        on_funder_payment_failed(
                            &db,
                            &hash_hex,
                            reason.as_ref().map(|r| format!("{r:?}")),
                        );
                    }
                    _ => {}
                }
                if funder.event_handled().is_err() {
                    eprintln!("[funder] event loop stopping (node stopped).");
                    return;
                }
            }
        });
    }
    {
        let dealer = Arc::clone(&rt.dealer);
        std::thread::spawn(move || {
            loop {
                let event = dealer.wait_next_event();
                if let Event::PaymentReceived {
                    payment_hash,
                    amount_msat,
                    ..
                } = &event
                {
                    on_dealer_invoice_received(&db, &to_hex(&payment_hash.0));
                    eprintln!(
                        "[dealer] RECEIVED payment_hash={} amount={amount_msat}msat",
                        to_hex(&payment_hash.0)
                    );
                }
                if dealer.event_handled().is_err() {
                    eprintln!("[dealer] event loop stopping (node stopped).");
                    return;
                }
            }
        });
    }
}

fn on_dealer_invoice_received(db: &Db, hash_hex: &str) {
    let Ok(connection) = db.lock() else { return };
    if let Err(error) = connection.execute(
        "UPDATE dealer_invoices SET state = 'Received' WHERE payment_hash = ?1",
        [hash_hex],
    ) {
        eprintln!("[dealer] invoice status update failed: {error}");
    }
}

fn on_funder_payment_settled(db: &Db, hash_hex: &str, preimage: Option<String>) {
    let connection = match db.lock() {
        Ok(c) => c,
        Err(_) => return,
    };
    if let Err(e) = connection.execute(
		"UPDATE payments SET state = 'Settled', preimage = COALESCE(?2, preimage) WHERE payment_hash = ?1 AND state = 'Pending'",
		params![hash_hex, preimage],
	) {
		eprintln!("database error on settlement update: {e}");
		return;
	}
    // Deduct the settled naira from the voucher balance (PRD: voucher balances
    // are denominated in naira and reduced by settled dealer payments).
    if let Ok((voucher_id, amount_ngn)) = connection.query_row(
		"SELECT voucher_id, amount_ngn FROM payments WHERE payment_hash = ?1 AND state = 'Settled' ORDER BY sort_order DESC LIMIT 1",
		params![hash_hex],
		|row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?)),
	) {
		let _ = connection.execute(
			"UPDATE vouchers SET remaining_ngn = MAX(remaining_ngn - ?2, 0), status = CASE WHEN MAX(remaining_ngn - ?2, 0) <= 0 THEN 'Spent' ELSE status END WHERE id = ?3",
			params![voucher_id, amount_ngn, voucher_id],
		);
	}
    eprintln!("[funder] payment SETTLED hash={hash_hex}");
}

fn on_funder_payment_failed(db: &Db, hash_hex: &str, reason: Option<String>) {
    let Ok(connection) = db.lock() else { return };
    let _ = connection
		.execute(
			"UPDATE payments SET state = 'Failed', error_reason = ?2 WHERE payment_hash = ?1 AND state = 'Pending'",
			params![hash_hex, reason],
		)
		.ok();
    if let Err(error) = connection.execute(
        "UPDATE dealer_invoices SET state = 'Failed' WHERE payment_hash = ?1 AND state = 'Pending'",
        [hash_hex],
    ) {
        eprintln!("[funder] dealer invoice failure update failed: {error}");
    }
    eprintln!("[funder] payment FAILED hash={hash_hex} reason={reason:?}");
}

/// Mint a BOLT11 invoice on the demo dealer node (test-network only helper).
pub fn dealer_invoice(amount_msat: u64, description: &str) -> Result<String, LnError> {
    let rt = runtime().ok_or(LnError::NotRunning)?;
    let desc = Bolt11InvoiceDescription::Direct(
        Description::new(description.to_string()).map_err(|e| LnError::Internal(format!("{e}")))?,
    );
    let invoice = rt
        .dealer
        .bolt11_payment()
        .receive(amount_msat, &desc, 3600)
        .map_err(|e| LnError::Internal(format!("{e:?}")))?;
    Ok(invoice.to_string())
}

/// A BOLT11 invoice parsed for a voucher payment request.
pub struct ParsedInvoice {
    pub invoice: Bolt11Invoice,
    pub payee: PublicKey,
    pub amount_msat: u64,
    pub payment_hash_hex: String,
}

/// Parse a BOLT11 invoice (test-network only).
pub fn parse_invoice(invoice_str: &str) -> Result<ParsedInvoice, LnError> {
    let invoice = Bolt11Invoice::from_str(invoice_str.trim())
        .map_err(|e| LnError::InvalidInvoice(format!("{e}")))?;
    let amount_msat = invoice.amount_milli_satoshis().ok_or_else(|| {
        LnError::InvalidInvoice(
            "invoice omits an amount; exact vouchers need an amount-bearing BOLT11 invoice."
                .to_string(),
        )
    })?;
    Ok(ParsedInvoice {
        payee: invoice.recover_payee_pub_key(),
        // sha256::Hash Display renders 64 lowercase hex chars.
        payment_hash_hex: invoice.payment_hash().to_string(),
        invoice,
        amount_msat,
    })
}

/// Initiate the payment on the funder node. DB row must already exist.
pub fn initiate_payment(parsed: &ParsedInvoice) -> Result<(), LnError> {
    let rt = runtime().ok_or(LnError::NotRunning)?;
    match rt.funder.bolt11_payment().send(&parsed.invoice, None) {
        Ok(_) => Ok(()),
        Err(ldk_node::NodeError::DuplicatePayment) => Err(LnError::Duplicate),
        Err(e) => Err(LnError::SendFailed(format!("{e:?}"))),
    }
}
