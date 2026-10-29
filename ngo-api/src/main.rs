use std::{
    collections::HashMap,
    env,
    net::SocketAddr,
    path::Path,
    sync::{Arc, Mutex},
};

use axum::{
    Json, Router,
    extract::State,
    http::{Method, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::{Local, Utc};
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use tower_http::cors::{Any, CorsLayer};

pub mod ln;

type Db = Arc<Mutex<Connection>>;
const INVITE_LIFETIME_SECONDS: i64 = 24 * 60 * 60;

#[derive(Clone)]
struct AppState {
    db: Db,
    demo_dealer_keys: Arc<Mutex<HashMap<String, String>>>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Farmer {
    id: String,
    name: String,
    location: String,
    language: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    phone_number: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    support_amount: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    balance_ngn: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    invite_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    invite_expires_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    invite_status: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct FarmerAccount {
    farmer_id: String,
    farmer_name: String,
    balance_ngn: i64,
    history: Vec<FarmerHistoryEntry>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct FarmerHistoryEntry {
    kind: String,
    description: String,
    amount_ngn: i64,
    time: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    repayment_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    note: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Voucher {
    id: String,
    farmer_id: String,
    purpose: String,
    amount: i64,
    remaining_ngn: i64,
    amount_owed_ngn: i64,
    created_at: String,
    status: String,
    kind: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Payment {
    id: String,
    farmer_id: String,
    dealer: String,
    amount_ngn: i64,
    amount_sats: i64,
    state: String,
    time: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    voucher_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    invoice: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    payment_hash: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    preimage: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error_reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    rate_used: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    rate_label: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateVoucher {
    farmer_id: String,
    purpose: String,
    amount: i64,
    /// Grants (default) never expect repayment; loans do.
    kind: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RecordRepayment {
    request_id: String,
    amount_ngn: i64,
    repayment_type: String,
    note: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Repayment {
    id: String,
    voucher_id: String,
    amount_ngn: i64,
    repayment_type: String,
    note: Option<String>,
    time: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RepaymentResult {
    idempotent: bool,
    repayment: Repayment,
    amount_owed_ngn: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RegisterFarmer {
    device_id: String,
    name: String,
    location: Option<String>,
    language: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateDashboardFarmer {
    name: String,
    phone_number: String,
    support_amount: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RedeemInvite {
    code: String,
    client_id: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RedeemedFarmer {
    session_token: String,
    farmer_name: String,
    balance_ngn: i64,
}

/// 'Grant' | 'Loan' — the primary award mode is Grant (no repayment expected).
fn normalize_kind(kind: Option<&str>) -> Result<String, ()> {
    match kind.map(str::trim) {
        None | Some("") => Ok("Grant".to_string()),
        Some(other) => {
            if other.eq_ignore_ascii_case("grant") || other.eq_ignore_ascii_case("loan") {
                let mut normalized = other.to_lowercase();
                normalized[..1].make_ascii_uppercase();
                Ok(normalized)
            } else {
                Err(())
            }
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct WhitelistDealer {
    node_id: String,
    name: Option<String>,
    location: Option<String>,
    /// Optional; set false to revoke a previously whitelisted node ID.
    active: Option<bool>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RequestPayment {
    voucher_id: String,
    invoice: String,
    /// Optional client-provided idempotency key; the invoice's payment hash is
    /// also used as a natural idempotency key, whichever hits first.
    idempotency_key: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DealerInvoiceRequest {
    amount_ngn: i64,
}

#[derive(Debug, Serialize)]
struct ApiError {
    error: String,
    #[serde(skip_serializing)]
    status: StatusCode,
}

impl ApiError {
    fn bad_request(error: String) -> Self {
        Self {
            error,
            status: StatusCode::BAD_REQUEST,
        }
    }

    fn conflict(error: String) -> Self {
        Self {
            error,
            status: StatusCode::CONFLICT,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (
            self.status,
            Json(ApiError {
                error: self.error,
                status: self.status,
            }),
        )
            .into_response()
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let database_path =
        env::var("SATSFARM_DB_PATH").unwrap_or_else(|_| "data/satsfarm.sqlite".to_owned());
    if let Some(parent) = Path::new(&database_path).parent()
        && !parent.as_os_str().is_empty()
    {
        std::fs::create_dir_all(parent)?;
    }
    let connection = Connection::open(database_path)?;
    initialize_database(&connection)?;
    let state = AppState {
        db: Arc::new(Mutex::new(connection)),
        demo_dealer_keys: Arc::new(Mutex::new(HashMap::new())),
    };

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST])
        .allow_headers(Any);
    let db = state.db.clone();
    let app = Router::new()
        .route("/api/health", get(health))
        .route("/api/farmers", get(list_farmers).post(register_farmer))
        .route("/api/dashboard/farmers", post(create_dashboard_farmer))
        .route(
            "/api/dashboard/farmers/{id}/invite",
            post(regenerate_invite),
        )
        .route("/api/farmers/invites/redeem", post(redeem_invite))
        .route("/api/farmer/account", get(farmer_account))
        .route("/api/farmers/by-device/{device_id}", get(farmer_by_device))
        .route("/api/farmers/{id}/vouchers", get(list_farmer_vouchers))
        .route("/api/vouchers", get(list_vouchers).post(create_voucher))
        .route("/api/vouchers/{id}/repayments", post(record_repayment))
        .route("/api/payments", get(list_payments))
        .route("/api/payments/{id}", get(get_payment))
        .route("/api/payments/request", post(request_payment))
        .route("/api/funder/receive-address", post(funder_receive_address))
        .route("/api/dealers", get(list_dealers))
        .route("/api/dealers/demo", get(list_demo_dealers))
        .route(
            "/api/dealers/demo/{slug}/key/regenerate",
            post(regenerate_demo_dealer_key),
        )
        .route("/api/dealers/whitelist", post(whitelist_dealer))
        .route(
            "/api/dealers/{node_id}/key/regenerate",
            post(regenerate_dealer_key),
        )
        .route("/api/dealers/verify", post(verify_dealer_key))
        .route(
            "/api/dealers/invoices",
            get(list_dealer_invoices).post(create_dealer_invoice),
        )
        .route("/api/dealers/invoices/{id}", get(get_dealer_invoice))
        .route("/api/dealers/invoices/history", get(dealer_invoice_history))
        .route("/api/ln/payment/{payment_hash}", get(lightning_payment_proof))
        .route("/api/ln/status", get(ln_status))
        .route("/api/demo/reset", post(reset_demo))
        .layer(cors)
        .with_state(state);

    let address: SocketAddr = env::var("SATSFARM_API_ADDR")
        .unwrap_or_else(|_| "127.0.0.1:8787".to_owned())
        .parse()?;
    let listener = tokio::net::TcpListener::bind(address).await?;
    println!("SatsFarm demo API listening on http://{address}");
    println!("{}", ln::TAG);
    println!(
        "Lightning mode: test-network payments on {} via the funder node; dealer payments only for whitelisted node IDs.",
        ln::TAG
    );
    println!("Naira conversion: {}", ln::RATE_LABEL);
    eprintln!(
        "warning: do not run harness/target/debug/ln_harness at the same time as this service - the copied LN state shares node IDs and ports."
    );
    // Starts both nodes (funder -> pays; dealer -> demo invoices) in threads.
    ln::bootstrap(db);
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health() -> Json<serde_json::Value> {
    Json(
        serde_json::json!({ "ok": true, "mode": "local-ln-demo", "paymentsEnabled": true, "network": "mutinynet-signet-testnet-only" }),
    )
}

async fn list_farmers(State(state): State<AppState>) -> Result<Json<Vec<Farmer>>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    let mut statement = db
        .prepare(
            "SELECT f.id, f.name, f.location, f.language, f.phone_number,
                    COALESCE((SELECT SUM(v.amount_ngn) FROM vouchers v WHERE v.farmer_id = f.id), 0),
                    COALESCE((SELECT SUM(v.remaining_ngn) FROM vouchers v WHERE v.farmer_id = f.id AND v.status = 'Active'), 0),
                    i.code, i.expires_at, i.used
             FROM farmers f
             LEFT JOIN invite_codes i ON i.farmer_id = f.id AND i.invalidated = 0
             WHERE i.id IS NULL OR i.id = (
                 SELECT MAX(i2.id) FROM invite_codes i2
                 WHERE i2.farmer_id = f.id AND i2.invalidated = 0
             )
             ORDER BY f.id",
        )
        .map_err(internal_error)?;
    let rows = statement
        .query_map([], |row| {
            let expires_at: Option<i64> = row.get(8)?;
            let used: Option<bool> = row.get(9)?;
            let invite_status = match (used, expires_at) {
                (Some(true), _) => "Joined",
                (Some(false), Some(expiry)) if expiry <= Utc::now().timestamp() => "Expired",
                (Some(false), Some(_)) => "Invited",
                _ => "Expired",
            };
            Ok(Farmer {
                id: row.get(0)?,
                name: row.get(1)?,
                location: row.get(2)?,
                language: row.get(3)?,
                phone_number: row.get(4)?,
                support_amount: row.get(5)?,
                balance_ngn: row.get(6)?,
                invite_code: if used == Some(true) {
                    None
                } else {
                    row.get(7)?
                },
                invite_expires_at: expires_at.map(|timestamp| timestamp_to_rfc3339(timestamp)),
                invite_status: Some(invite_status.to_owned()),
            })
        })
        .map_err(internal_error)?;
    let farmers = rows
        .collect::<Result<Vec<_>, _>>()
        .map_err(internal_error)?;
    Ok(Json(farmers))
}

async fn create_dashboard_farmer(
    State(state): State<AppState>,
    Json(input): Json<CreateDashboardFarmer>,
) -> Result<(StatusCode, Json<Farmer>), ApiError> {
    let name = input.name.trim();
    let phone_number = input.phone_number.trim();
    if name.is_empty() || name.chars().count() > 60 {
        return Err(ApiError::bad_request(
            "Enter a farmer name of 1 to 60 characters.".to_string(),
        ));
    }
    if phone_number.is_empty() || phone_number.len() > 30 {
        return Err(ApiError::bad_request(
            "Enter a phone number of 1 to 30 characters.".to_string(),
        ));
    }
    if !(1..=10_000_000).contains(&input.support_amount) {
        return Err(ApiError::bad_request(
            "Support amount must be between N1 and N10,000,000.".to_string(),
        ));
    }

    let mut db = state.db.lock().map_err(internal_error)?;
    let tx = db.transaction().map_err(internal_error)?;
    let next_seq: i64 = tx
        .query_row(
            "SELECT COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 1000) + 1 FROM farmers WHERE id LIKE 'F-%'",
            [],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    let id = format!("F-{next_seq}");
    tx.execute(
        "INSERT INTO farmers (id, name, location, language, phone_number) VALUES (?1, ?2, '', 'English', ?3)",
        params![id, name, phone_number],
    )
    .map_err(internal_error)?;
    let voucher_id = format!(
        "SF-{}",
        uuid::Uuid::new_v4().simple().to_string()[..8].to_uppercase()
    );
    let created_at = Utc::now().to_rfc3339();
    tx.execute(
        "INSERT INTO vouchers (id, farmer_id, purpose, amount_ngn, remaining_ngn, created_at, status, kind)
         VALUES (?1, ?2, 'Program support', ?3, ?3, ?4, 'Active', 'Grant')",
        params![voucher_id, id, input.support_amount, created_at],
    )
    .map_err(internal_error)?;
    let invite_code = insert_invite(&tx, &id, Utc::now().timestamp()).map_err(internal_error)?;
    tx.commit().map_err(internal_error)?;

    Ok((
        StatusCode::CREATED,
        Json(Farmer {
            id,
            name: name.to_owned(),
            location: String::new(),
            language: "English".to_owned(),
            phone_number: Some(phone_number.to_owned()),
            support_amount: Some(input.support_amount),
            balance_ngn: Some(input.support_amount),
            invite_code: Some(invite_code),
            invite_expires_at: Some(timestamp_to_rfc3339(
                Utc::now().timestamp() + INVITE_LIFETIME_SECONDS,
            )),
            invite_status: Some("Invited".to_owned()),
        }),
    ))
}

async fn regenerate_invite(
    State(state): State<AppState>,
    axum::extract::Path(farmer_id): axum::extract::Path<String>,
) -> Result<Json<Farmer>, ApiError> {
    let mut db = state.db.lock().map_err(internal_error)?;
    let tx = db.transaction().map_err(internal_error)?;
    let farmer = tx
        .query_row(
            "SELECT id, name, location, language, phone_number
             FROM farmers WHERE id = ?1",
            [&farmer_id],
            |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, Option<String>>(4)?,
                ))
            },
        )
        .optional()
        .map_err(internal_error)?
        .ok_or_else(|| ApiError {
            error: "Farmer was not found.".to_owned(),
            status: StatusCode::NOT_FOUND,
        })?;
    let joined: bool = tx
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM invite_codes WHERE farmer_id = ?1 AND used = 1 AND invalidated = 0)",
            [&farmer_id],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    if joined {
        return Err(ApiError::bad_request(
            "This farmer has already joined.".to_owned(),
        ));
    }
    tx.execute(
        "UPDATE invite_codes SET invalidated = 1 WHERE farmer_id = ?1 AND invalidated = 0",
        [&farmer_id],
    )
    .map_err(internal_error)?;
    let code = insert_invite(&tx, &farmer_id, Utc::now().timestamp()).map_err(internal_error)?;
    let balance: i64 = tx
        .query_row(
            "SELECT COALESCE(SUM(remaining_ngn), 0) FROM vouchers WHERE farmer_id = ?1 AND status = 'Active'",
            [&farmer_id],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    tx.commit().map_err(internal_error)?;
    Ok(Json(Farmer {
        id: farmer.0,
        name: farmer.1,
        location: farmer.2,
        language: farmer.3,
        phone_number: farmer.4,
        support_amount: None,
        balance_ngn: Some(balance),
        invite_code: Some(code),
        invite_expires_at: Some(timestamp_to_rfc3339(
            Utc::now().timestamp() + INVITE_LIFETIME_SECONDS,
        )),
        invite_status: Some("Invited".to_owned()),
    }))
}

async fn redeem_invite(
    State(state): State<AppState>,
    Json(input): Json<RedeemInvite>,
) -> Result<Json<RedeemedFarmer>, ApiError> {
    let code = input.code.trim().to_ascii_uppercase();
    let client_id = input.client_id.trim();
    if code.is_empty() || client_id.len() < 16 || client_id.len() > 128 {
        return Err(ApiError::bad_request("invalid_code".to_owned()));
    }
    let db = state.db.lock().map_err(internal_error)?;
    let now = Utc::now().timestamp();
    let invite = db
        .query_row(
            "SELECT id, farmer_id, expires_at, used, invalidated, used_by_client, session_token
             FROM invite_codes WHERE code = ?1",
            [&code],
            |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, bool>(3)?,
                    row.get::<_, bool>(4)?,
                    row.get::<_, Option<String>>(5)?,
                    row.get::<_, Option<String>>(6)?,
                ))
            },
        )
        .optional()
        .map_err(internal_error)?
        .ok_or_else(|| ApiError::bad_request("invalid_code".to_owned()))?;

    if invite.3 {
        if invite.5.as_deref() != Some(client_id) {
            return Err(ApiError::bad_request("already_used".to_owned()));
        }
        let token = invite
            .6
            .ok_or_else(|| internal_error("Missing farmer session"))?;
        return redeemed_farmer(&db, &invite.1, token).map(Json);
    }
    if invite.4 {
        return Err(ApiError::bad_request("invalid_code".to_owned()));
    }
    if invite.2 <= now {
        return Err(ApiError::bad_request("expired_code".to_owned()));
    }

    let token = uuid::Uuid::new_v4().simple().to_string();
    db.execute(
        "UPDATE invite_codes SET used = 1, used_by_client = ?1, session_token = ?2 WHERE id = ?3 AND used = 0",
        params![client_id, token, invite.0],
    )
    .map_err(internal_error)?;
    redeemed_farmer(&db, &invite.1, token).map(Json)
}

async fn farmer_account(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<FarmerAccount>, ApiError> {
    let token = headers
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|header| header.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError {
            error: "session_required".to_owned(),
            status: StatusCode::UNAUTHORIZED,
        })?;
    let db = state.db.lock().map_err(internal_error)?;
    let farmer_id = db
        .query_row(
            "SELECT farmer_id FROM invite_codes WHERE session_token = ?1 AND used = 1",
            [token],
            |row| row.get::<_, String>(0),
        )
        .optional()
        .map_err(internal_error)?
        .ok_or_else(|| ApiError {
            error: "session_required".to_owned(),
            status: StatusCode::UNAUTHORIZED,
        })?;
    let farmer_name = db
        .query_row(
            "SELECT name FROM farmers WHERE id = ?1",
            [&farmer_id],
            |row| row.get::<_, String>(0),
        )
        .map_err(internal_error)?;
    let balance_ngn = db
        .query_row(
            "SELECT COALESCE(SUM(remaining_ngn), 0) FROM vouchers WHERE farmer_id = ?1 AND status = 'Active'",
            [&farmer_id],
            |row| row.get::<_, i64>(0),
        )
        .map_err(internal_error)?;
    let mut statement = db
        .prepare(
            "SELECT kind, description, amount_ngn, time, repayment_type, note FROM (
                SELECT 'Support' AS kind, purpose AS description, amount_ngn, created_at AS time, NULL AS repayment_type, NULL AS note
                FROM vouchers WHERE farmer_id = ?1
                UNION ALL
                SELECT 'Payment', dealer, amount_ngn, time, NULL, NULL
                FROM payments WHERE farmer_id = ?1 AND state = 'Settled'
                UNION ALL
                SELECT 'Repayment', repayment_type, amount_ngn, time, repayment_type, note
                FROM repayments WHERE voucher_id IN (
                    SELECT id FROM vouchers WHERE farmer_id = ?1
                )
             ) ORDER BY time DESC",
        )
        .map_err(internal_error)?;
    let history = statement
        .query_map([&farmer_id], |row| {
            Ok(FarmerHistoryEntry {
                kind: row.get(0)?,
                description: row.get(1)?,
                amount_ngn: row.get(2)?,
                time: row.get(3)?,
                repayment_type: row.get(4)?,
                note: row.get(5)?,
            })
        })
        .map_err(internal_error)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(internal_error)?;
    Ok(Json(FarmerAccount {
        farmer_id,
        farmer_name,
        balance_ngn,
        history,
    }))
}

fn redeemed_farmer(
    db: &Connection,
    farmer_id: &str,
    session_token: String,
) -> Result<RedeemedFarmer, ApiError> {
    let (farmer_name, balance_ngn) = db
        .query_row(
            "SELECT f.name,
                    COALESCE((SELECT SUM(v.remaining_ngn) FROM vouchers v WHERE v.farmer_id = f.id AND v.status = 'Active'), 0)
             FROM farmers f WHERE f.id = ?1",
            [farmer_id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .map_err(internal_error)?;
    Ok(RedeemedFarmer {
        session_token,
        farmer_name,
        balance_ngn,
    })
}

async fn list_vouchers(State(state): State<AppState>) -> Result<Json<Vec<Voucher>>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    let mut statement = db.prepare("SELECT v.id, v.farmer_id, v.purpose, v.amount_ngn, v.remaining_ngn, v.created_at, v.status, v.kind,
        CASE WHEN v.kind = 'Loan' THEN MAX(v.amount_ngn - COALESCE((SELECT SUM(r.amount_ngn) FROM repayments r WHERE r.voucher_id = v.id), 0), 0) ELSE 0 END
        FROM vouchers v ORDER BY v.created_at DESC, v.id DESC").map_err(internal_error)?;
    let rows = statement
        .query_map([], |row| {
            Ok(Voucher {
                id: row.get(0)?,
                farmer_id: row.get(1)?,
                purpose: row.get(2)?,
                amount: row.get(3)?,
                remaining_ngn: row.get(4)?,
                amount_owed_ngn: row.get(8)?,
                created_at: row.get(5)?,
                status: row.get(6)?,
                kind: row.get(7)?,
            })
        })
        .map_err(internal_error)?;
    let vouchers = rows
        .collect::<Result<Vec<_>, _>>()
        .map_err(internal_error)?;
    Ok(Json(vouchers))
}

async fn list_farmer_vouchers(
    State(state): State<AppState>,
    axum::extract::Path(farmer_id): axum::extract::Path<String>,
) -> Result<Json<Vec<Voucher>>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    let exists: bool = db
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM farmers WHERE id = ?1)",
            [&farmer_id],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    if !exists {
        return Err(ApiError {
            error: format!("Farmer {farmer_id} was not found."),
            status: StatusCode::NOT_FOUND,
        });
    }
    let mut statement = db.prepare("SELECT v.id, v.farmer_id, v.purpose, v.amount_ngn, v.remaining_ngn, v.created_at, v.status, v.kind,
        CASE WHEN v.kind = 'Loan' THEN MAX(v.amount_ngn - COALESCE((SELECT SUM(r.amount_ngn) FROM repayments r WHERE r.voucher_id = v.id), 0), 0) ELSE 0 END
        FROM vouchers v WHERE v.farmer_id = ?1 ORDER BY v.created_at DESC, v.id DESC").map_err(internal_error)?;
    let rows = statement
        .query_map([&farmer_id], |row| {
            Ok(Voucher {
                id: row.get(0)?,
                farmer_id: row.get(1)?,
                purpose: row.get(2)?,
                amount: row.get(3)?,
                remaining_ngn: row.get(4)?,
                amount_owed_ngn: row.get(8)?,
                created_at: row.get(5)?,
                status: row.get(6)?,
                kind: row.get(7)?,
            })
        })
        .map_err(internal_error)?;
    let vouchers = rows
        .collect::<Result<Vec<_>, _>>()
        .map_err(internal_error)?;
    Ok(Json(vouchers))
}

/// Farmers' app registration: binds the device wallet to a program profile.
/// Re-registering with the same deviceId returns the existing profile.
async fn register_farmer(
    State(state): State<AppState>,
    Json(input): Json<RegisterFarmer>,
) -> Result<(StatusCode, Json<Farmer>), ApiError> {
    let device_id = input.device_id.trim().to_owned();
    if device_id.len() < 16 {
        return Err(ApiError::bad_request(
            "deviceId must be a stable random identifier of at least 16 characters.".to_string(),
        ));
    }
    let name = input.name.trim();
    if name.is_empty() || name.len() > 60 {
        return Err(ApiError::bad_request(
            "Enter a farmer name of 1 to 60 characters.".to_string(),
        ));
    }
    let location = input
        .location
        .as_deref()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .unwrap_or("Kano, Nigeria")
        .to_owned();
    let language = match input.language.as_deref().map(str::trim) {
        Some("ha" | "Hausa") => "Hausa".to_string(),
        Some("en" | "English") => "English".to_string(),
        _ => "Hausa".to_string(),
    };
    let db = state.db.lock().map_err(internal_error)?;
    if let Some(existing) = db
        .query_row(
            "SELECT id, name, location, language FROM farmers WHERE device_id = ?1",
            [&device_id],
            |row| {
                Ok(Farmer {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    location: row.get(2)?,
                    language: row.get(3)?,
                    phone_number: None,
                    support_amount: None,
                    balance_ngn: None,
                    invite_code: None,
                    invite_expires_at: None,
                    invite_status: None,
                })
            },
        )
        .optional()
        .map_err(internal_error)?
    {
        return Ok((StatusCode::OK, Json(existing)));
    }
    let next_seq: i64 = db
        .query_row(
            "SELECT COALESCE(MAX(CAST(SUBSTR(id, 3) AS INTEGER)), 1000) + 1 FROM farmers WHERE id LIKE 'F-%'",
            [],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    let id = format!("F-{next_seq}");
    db.execute(
        "INSERT INTO farmers (id, name, location, language, device_id) VALUES (?1, ?2, ?3, ?4, ?5)",
        params![id, name, location, language, device_id],
    )
    .map_err(internal_error)?;
    Ok((
        StatusCode::CREATED,
        Json(Farmer {
            id,
            name: name.to_owned(),
            location,
            language,
            phone_number: None,
            support_amount: None,
            balance_ngn: None,
            invite_code: None,
            invite_expires_at: None,
            invite_status: None,
        }),
    ))
}

async fn farmer_by_device(
    State(state): State<AppState>,
    axum::extract::Path(device_id): axum::extract::Path<String>,
) -> Result<Json<Farmer>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    let farmer = db
        .query_row(
            "SELECT id, name, location, language FROM farmers WHERE device_id = ?1",
            [&device_id],
            |row| {
                Ok(Farmer {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    location: row.get(2)?,
                    language: row.get(3)?,
                    phone_number: None,
                    support_amount: None,
                    balance_ngn: None,
                    invite_code: None,
                    invite_expires_at: None,
                    invite_status: None,
                })
            },
        )
        .optional()
        .map_err(internal_error)?;
    farmer.map(Json).ok_or_else(|| ApiError {
        error: "No program profile is tied to this device yet.".into(),
        status: StatusCode::NOT_FOUND,
    })
}

async fn create_voucher(
    State(state): State<AppState>,
    Json(input): Json<CreateVoucher>,
) -> Result<(StatusCode, Json<Voucher>), ApiError> {
    let farmer_id = input.farmer_id.trim();
    let purpose = input.purpose.trim();
    let kind = normalize_kind(input.kind.as_deref())
        .map_err(|_| ApiError::bad_request("kind must be 'Grant' or 'Loan'.".to_string()))?;
    if input.amount <= 0 || input.amount > 10_000_000 {
        return Err(ApiError::bad_request(
            "Amount must be between N1 and N10,000,000 in this demo.".to_string(),
        ));
    }
    if purpose.is_empty() || purpose.len() > 100 {
        return Err(ApiError::bad_request(
            "Enter a purpose of 1 to 100 characters.".to_string(),
        ));
    }
    let db = state.db.lock().map_err(internal_error)?;
    let farmer_exists: bool = db
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM farmers WHERE id = ?1)",
            [farmer_id],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    if !farmer_exists {
        return Err(ApiError::bad_request("Farmer was not found.".to_string()));
    }

    let id = format!(
        "SF-{}",
        uuid::Uuid::new_v4().simple().to_string()[..8].to_uppercase()
    );
    let created_at = Utc::now().format("%d %b %Y").to_string();
    db.execute("INSERT INTO vouchers (id, farmer_id, purpose, amount_ngn, remaining_ngn, created_at, status, kind) VALUES (?1, ?2, ?3, ?4, ?4, ?5, 'Active', ?6)",
        params![id, farmer_id, purpose, input.amount, created_at, kind]).map_err(internal_error)?;
    Ok((
        StatusCode::CREATED,
        Json(Voucher {
            id,
            farmer_id: farmer_id.to_owned(),
            purpose: purpose.to_owned(),
            amount: input.amount,
            remaining_ngn: input.amount,
            amount_owed_ngn: if kind == "Loan" { input.amount } else { 0 },
            created_at,
            status: "Active".into(),
            kind,
        }),
    ))
}

async fn record_repayment(
    State(state): State<AppState>,
    axum::extract::Path(voucher_id): axum::extract::Path<String>,
    Json(input): Json<RecordRepayment>,
) -> Result<Json<RepaymentResult>, ApiError> {
    let request_id = input.request_id.trim();
    if request_id.is_empty() || request_id.len() > 128 {
        return Err(ApiError::bad_request(
            "requestId must contain 1 to 128 characters.".to_string(),
        ));
    }
    if input.amount_ngn <= 0 {
        return Err(ApiError::bad_request(
            "Repayment amount must be greater than zero.".to_string(),
        ));
    }
    let repayment_type = match input.repayment_type.trim().to_ascii_lowercase().as_str() {
        "grain" => "Grain",
        "cash" => "Cash",
        "transfer" => "Transfer",
        _ => {
            return Err(ApiError::bad_request(
                "type must be 'Grain', 'Cash', or 'Transfer'.".to_string(),
            ));
        }
    };
    let note = input
        .note
        .as_deref()
        .map(str::trim)
        .filter(|note| !note.is_empty())
        .map(str::to_owned);
    if note.as_ref().is_some_and(|note| note.chars().count() > 500) {
        return Err(ApiError::bad_request(
            "Repayment note must be 500 characters or fewer.".to_string(),
        ));
    }

    let db = state.db.lock().map_err(internal_error)?;
    let tx = db.unchecked_transaction().map_err(internal_error)?;
    let existing = tx
        .query_row(
            "SELECT id, voucher_id, amount_ngn, repayment_type, note, time
             FROM repayments WHERE request_id = ?1",
            [request_id],
            |row| {
                Ok(Repayment {
                    id: row.get(0)?,
                    voucher_id: row.get(1)?,
                    amount_ngn: row.get(2)?,
                    repayment_type: row.get(3)?,
                    note: row.get(4)?,
                    time: row.get(5)?,
                })
            },
        )
        .optional()
        .map_err(internal_error)?;

    if let Some(repayment) = existing {
        if repayment.voucher_id != voucher_id
            || repayment.amount_ngn != input.amount_ngn
            || repayment.repayment_type != repayment_type
            || repayment.note != note
        {
            return Err(ApiError::conflict(
                "requestId has already been used for a different repayment.".to_string(),
            ));
        }
        let amount_owed_ngn = tx
            .query_row(
                "SELECT MAX(v.amount_ngn - COALESCE(SUM(r.amount_ngn), 0), 0)
                 FROM vouchers v LEFT JOIN repayments r ON r.voucher_id = v.id
                 WHERE v.id = ?1 AND v.kind = 'Loan' GROUP BY v.id",
                [&voucher_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()
            .map_err(internal_error)?
            .ok_or_else(|| ApiError::bad_request("Loan voucher was not found.".to_string()))?;
        return Ok(Json(RepaymentResult {
            idempotent: true,
            repayment,
            amount_owed_ngn,
        }));
    }

    let amount_owed_ngn = tx
        .query_row(
            "SELECT CASE WHEN kind = 'Loan'
                 THEN MAX(amount_ngn - COALESCE((SELECT SUM(amount_ngn) FROM repayments WHERE voucher_id = vouchers.id), 0), 0)
                 ELSE NULL END
             FROM vouchers WHERE id = ?1",
            [&voucher_id],
            |row| row.get::<_, Option<i64>>(0),
        )
        .optional()
        .map_err(internal_error)?
        .flatten()
        .ok_or_else(|| ApiError::bad_request(
            "Repayments can only be recorded against a loan voucher.".to_string(),
        ))?;

    if input.amount_ngn > amount_owed_ngn {
        return Err(ApiError::bad_request(format!(
            "Repayment exceeds the amount owed ({amount_owed_ngn} NGN)."
        )));
    }

    let repayment = Repayment {
        id: format!(
            "RP-{}",
            uuid::Uuid::new_v4().simple().to_string()[..8].to_uppercase()
        ),
        voucher_id: voucher_id.clone(),
        amount_ngn: input.amount_ngn,
        repayment_type: repayment_type.to_string(),
        note,
        time: Utc::now().to_rfc3339(),
    };
    tx.execute(
        "INSERT INTO repayments (id, voucher_id, request_id, amount_ngn, repayment_type, note, time)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![
            repayment.id,
            repayment.voucher_id,
            request_id,
            repayment.amount_ngn,
            repayment.repayment_type,
            repayment.note,
            repayment.time
        ],
    )
    .map_err(internal_error)?;
    tx.commit().map_err(internal_error)?;

    Ok(Json(RepaymentResult {
        idempotent: false,
        amount_owed_ngn: amount_owed_ngn - input.amount_ngn,
        repayment,
    }))
}

async fn list_payments(
    State(state): State<AppState>,
    axum::extract::Query(query): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<Payment>>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    if let Some(voucher_id) = query
        .get("voucherId")
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
    {
        let mut statement = db.prepare(
            "SELECT id, farmer_id, dealer, amount_ngn, amount_sats, state, time, voucher_id, invoice, payment_hash, preimage, error_reason, rate_used FROM payments WHERE voucher_id = ?1 ORDER BY sort_order DESC",
        ).map_err(internal_error)?;
        let rows = statement
            .query_map([voucher_id], map_payment_row)
            .map_err(internal_error)?;
        let mut payments = rows
            .collect::<Result<Vec<_>, _>>()
            .map_err(internal_error)?;
        for payment in payments.iter_mut() {
            payment.rate_label = payment.rate_used.map(|_| ln::RATE_LABEL.to_string());
        }
        return Ok(Json(payments));
    }
    let mut statement = db.prepare(
        "SELECT id, farmer_id, dealer, amount_ngn, amount_sats, state, time, voucher_id, invoice, payment_hash, preimage, error_reason, rate_used FROM payments ORDER BY sort_order DESC",
    ).map_err(internal_error)?;
    let rows = statement
        .query_map([], map_payment_row)
        .map_err(internal_error)?;
    let mut payments = rows
        .collect::<Result<Vec<_>, _>>()
        .map_err(internal_error)?;
    for payment in payments.iter_mut() {
        payment.rate_label = payment.rate_used.map(|_| ln::RATE_LABEL.to_string());
    }
    Ok(Json(payments))
}

// Indexes map to: voucher_id, invoice, payment_hash, preimage, error_reason, rate_used (after 7 base columns).
fn map_payment_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Payment> {
    Ok(Payment {
        id: row.get(0)?,
        farmer_id: row.get(1)?,
        dealer: row.get(2)?,
        amount_ngn: row.get(3)?,
        amount_sats: row.get(4)?,
        state: row.get(5)?,
        time: row.get(6)?,
        voucher_id: row.get(7)?,
        invoice: row.get(8)?,
        payment_hash: row.get(9)?,
        preimage: row.get(10)?,
        error_reason: row.get(11)?,
        rate_used: row.get(12)?,
        rate_label: None,
    })
}

async fn get_payment(
    State(state): State<AppState>,
    axum::extract::Path(id): axum::extract::Path<String>,
) -> Result<Json<Payment>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    let row = db
        .query_row(
            "SELECT id, farmer_id, dealer, amount_ngn, amount_sats, state, time, voucher_id, invoice, payment_hash, preimage, error_reason, rate_used FROM payments WHERE id = ?1",
            [&id],
            |row| {
                Ok(Payment {
                    id: row.get(0)?,
                    farmer_id: row.get(1)?,
                    dealer: row.get(2)?,
                    amount_ngn: row.get(3)?,
                    amount_sats: row.get(4)?,
                    state: row.get(5)?,
                    time: row.get(6)?,
                    voucher_id: row.get(7)?,
                    invoice: row.get(8)?,
                    payment_hash: row.get(9)?,
                    preimage: row.get(10)?,
                    error_reason: row.get(11)?,
                    rate_used: row.get(12)?,
                    rate_label: None,
                })
            },
        )
        .optional()
        .map_err(internal_error)?;
    match row {
        Some(mut payment) => {
            payment.rate_label = payment.rate_used.map(|_| ln::RATE_LABEL.to_string());
            Ok(Json(payment))
        }
        None => Err(ApiError {
            error: format!("Payment {id} was not found."),
            status: StatusCode::NOT_FOUND,
        }),
    }
}

async fn list_dealers(
    State(state): State<AppState>,
) -> Result<Json<Vec<serde_json::Value>>, ApiError> {
    if let Some(runtime) = ln::runtime() {
        ensure_demo_dealers(&state, &runtime.dealer.node_id().to_string())?;
    }
    let db = state.db.lock().map_err(internal_error)?;
    let mut statement = db
        .prepare("SELECT name, location, node_id, whitelisted FROM dealers ORDER BY name")
        .map_err(internal_error)?;
    let rows = statement
        .query_map([], |row| {
            Ok(serde_json::json!({
                "name": row.get::<_, String>(0)?, "location": row.get::<_, String>(1)?,
                "nodeId": row.get::<_, String>(2)?, "active": row.get::<_, bool>(3)?,
            }))
        })
        .map_err(internal_error)?;
    let dealers = rows
        .collect::<Result<Vec<_>, _>>()
        .map_err(internal_error)?;
    Ok(Json(dealers))
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DemoDealerLink {
    slug: String,
    name: String,
    dealer_key: String,
}

const DEMO_DEALER_PROFILES: [(&str, &str, &str); 2] = [
    ("gidan-noma", "Gidan Noma Agro", "Zaria, Kaduna"),
    ("northern-seeds", "Northern Seeds Co.", "Kano Municipal"),
];

fn ensure_demo_dealers(
    state: &AppState,
    runtime_node_id: &str,
) -> Result<Vec<DemoDealerLink>, ApiError> {
    let mut keys = state.demo_dealer_keys.lock().map_err(internal_error)?;
    let db = state.db.lock().map_err(internal_error)?;
    let mut dealers = Vec::with_capacity(DEMO_DEALER_PROFILES.len());
    for (slug, name, location) in DEMO_DEALER_PROFILES {
        let dealer_key = keys
            .entry(slug.to_owned())
            .or_insert_with(new_dealer_key)
            .clone();
        let key_hash = dealer_key_hash(&dealer_key);
        let existing_id: Option<i64> = db
            .query_row(
                "SELECT id FROM dealers WHERE name = ?1 ORDER BY id LIMIT 1",
                [name],
                |row| row.get(0),
            )
            .optional()
            .map_err(internal_error)?;
        if let Some(id) = existing_id {
            db.execute(
                "UPDATE dealers SET location = ?1, node_id = ?2, whitelisted = 1, dealer_key = ?3 WHERE id = ?4",
                params![location, runtime_node_id, key_hash, id],
            )
            .map_err(internal_error)?;
        } else {
            db.execute(
                "INSERT INTO dealers (name, location, node_id, whitelisted, dealer_key) VALUES (?1, ?2, ?3, 1, ?4)",
                params![name, location, runtime_node_id, key_hash],
            )
            .map_err(internal_error)?;
        }
        dealers.push(DemoDealerLink {
            slug: slug.to_owned(),
            name: name.to_owned(),
            dealer_key,
        });
    }
    Ok(dealers)
}

async fn list_demo_dealers(
    State(state): State<AppState>,
) -> Result<Json<Vec<DemoDealerLink>>, ApiError> {
    let runtime = ln::runtime().ok_or_else(|| ApiError {
        error: "The demo dealer node is starting. Try again shortly.".to_string(),
        status: StatusCode::SERVICE_UNAVAILABLE,
    })?;
    Ok(Json(ensure_demo_dealers(
        &state,
        &runtime.dealer.node_id().to_string(),
    )?))
}

async fn regenerate_demo_dealer_key(
    State(state): State<AppState>,
    axum::extract::Path(slug): axum::extract::Path<String>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let runtime = ln::runtime().ok_or_else(|| ApiError {
        error: "The demo dealer node is starting. Try again shortly.".to_string(),
        status: StatusCode::SERVICE_UNAVAILABLE,
    })?;
    if !DEMO_DEALER_PROFILES
        .iter()
        .any(|(demo_slug, _, _)| *demo_slug == slug)
    {
        return Err(ApiError::bad_request(
            "Demo dealer was not found.".to_string(),
        ));
    }
    let mut keys = state.demo_dealer_keys.lock().map_err(internal_error)?;
    let dealer_key = new_dealer_key();
    let key_hash = dealer_key_hash(&dealer_key);
    let (_, name, _) = DEMO_DEALER_PROFILES
        .iter()
        .find(|(demo_slug, _, _)| *demo_slug == slug)
        .expect("validated demo dealer slug");
    let db = state.db.lock().map_err(internal_error)?;
    let updated = db
        .execute(
            "UPDATE dealers SET dealer_key = ?1 WHERE name = ?2 AND node_id = ?3 AND whitelisted = 1",
            params![key_hash, name, runtime.dealer.node_id().to_string()],
        )
        .map_err(internal_error)?;
    if updated == 0 {
        return Err(ApiError::bad_request(
            "Demo dealer is not registered yet.".to_string(),
        ));
    }
    keys.insert(slug, dealer_key.clone());
    Ok(Json(serde_json::json!({ "dealerKey": dealer_key })))
}

async fn whitelist_dealer(
    State(state): State<AppState>,
    Json(input): Json<WhitelistDealer>,
) -> Result<Json<serde_json::Value>, ApiError> {
    use std::str::FromStr;
    let node_id = input.node_id.trim();
    let key = ldk_node::bitcoin::secp256k1::PublicKey::from_str(node_id).map_err(|_| {
        ApiError::bad_request(
            "nodeId must be a valid 33-byte compressed public key (66 hex chars).".to_string(),
        )
    })?;
    let node_id = key.to_string(); // canonical compressed serialization
    let provided_name = input
        .name
        .as_deref()
        .map(str::trim)
        .filter(|n| !n.is_empty());
    let active = input.active.unwrap_or(true);
    let db = state.db.lock().map_err(internal_error)?;
    let mut issued_dealer_key = None;
    let existing: Option<i64> = db
        .query_row(
            "SELECT id FROM dealers WHERE node_id = ?1",
            [&node_id],
            |row| row.get(0),
        )
        .optional()
        .map_err(internal_error)?;
    if active {
        let dealer_key = new_dealer_key();
        let key_hash = dealer_key_hash(&dealer_key);
        issued_dealer_key = Some(dealer_key);
        if let Some(id) = existing {
            match provided_name {
                Some(new_name) => {
                    db.execute(
                        "UPDATE dealers SET whitelisted = 1, name = ?1, dealer_key = ?2 WHERE id = ?3",
                        params![new_name, key_hash, id],
                    )
                    .map_err(internal_error)?;
                }
                None => {
                    db.execute(
                        "UPDATE dealers SET whitelisted = 1, dealer_key = ?2 WHERE id = ?1",
                        params![id, key_hash],
                    )
                    .map_err(internal_error)?;
                }
            }
        } else {
            let name = provided_name
                .map(str::to_owned)
                .unwrap_or_else(|| format!("Dealer {}", node_id[2..10].to_uppercase()));
            let location = input.location.clone().unwrap_or_default();
            db.execute(
                "INSERT INTO dealers (name, location, node_id, whitelisted, dealer_key) VALUES (?1, ?2, ?3, 1, ?4)",
                params![name, location, node_id, key_hash],
            )
            .map_err(internal_error)?;
        }
    } else if let Some(id) = existing {
        db.execute(
            "UPDATE dealers SET whitelisted = 0, dealer_key = NULL WHERE id = ?1",
            params![id],
        )
        .map_err(internal_error)?;
    } else {
        return Err(ApiError::bad_request(format!(
            "Cannot deactivate {node_id}: it was never whitelisted."
        )));
    }
    Ok(Json(serde_json::json!({
        "ok": true,
        "nodeId": node_id,
        "active": active,
        "dealerKey": issued_dealer_key,
    })))
}

fn new_dealer_key() -> String {
    uuid::Uuid::new_v4().simple().to_string()
}

async fn regenerate_dealer_key(
    State(state): State<AppState>,
    axum::extract::Path(node_id): axum::extract::Path<String>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    let active: bool = db
        .query_row(
            "SELECT whitelisted FROM dealers WHERE node_id = ?1",
            [&node_id],
            |row| row.get(0),
        )
        .optional()
        .map_err(internal_error)?
        .ok_or_else(|| ApiError::bad_request("Dealer was not found.".to_string()))?;
    if !active {
        return Err(ApiError::bad_request(
            "Activate the dealer before generating a link.".to_string(),
        ));
    }
    let dealer_key = new_dealer_key();
    let key_hash = dealer_key_hash(&dealer_key);
    db.execute(
        "UPDATE dealers SET dealer_key = ?1 WHERE node_id = ?2",
        params![key_hash, node_id],
    )
    .map_err(internal_error)?;
    Ok(Json(serde_json::json!({ "dealerKey": dealer_key })))
}

fn dealer_key_hash(dealer_key: &str) -> String {
    use ldk_node::bitcoin::hashes::Hash;
    ldk_node::bitcoin::hashes::sha256::Hash::hash(dealer_key.as_bytes()).to_string()
}

fn authorized_demo_dealer(
    db: &Connection,
    dealer_key: &str,
    runtime_node_id: &str,
) -> Result<i64, ApiError> {
    let key_hash = dealer_key_hash(dealer_key);
    db.query_row(
        "SELECT id FROM dealers WHERE node_id = ?1 AND dealer_key = ?2 AND whitelisted = 1",
        params![runtime_node_id, key_hash],
        |row| row.get(0),
    )
    .optional()
    .map_err(internal_error)?
    .ok_or_else(|| ApiError {
        error: "Not a registered dealer.".to_string(),
        status: StatusCode::FORBIDDEN,
    })
}

fn dealer_amount_sats(amount_ngn: i64) -> Result<u64, ApiError> {
    if amount_ngn < ln::RATE_NGN_PER_SAT
        || amount_ngn > 500_000
        || amount_ngn % ln::RATE_NGN_PER_SAT != 0
    {
        return Err(ApiError::bad_request(
            "Enter an amount from ₦5 to ₦500,000 in steps of ₦5.".to_string(),
        ));
    }
    u64::try_from(amount_ngn / ln::RATE_NGN_PER_SAT)
        .map_err(|_| ApiError::bad_request("Invalid amount.".to_string()))
}

async fn verify_dealer_key(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<serde_json::Value>, ApiError> {
    let dealer_key = headers
        .get("x-dealer-key")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    let runtime_node_id = ln::runtime()
        .map(|runtime| runtime.dealer.node_id().to_string())
        .ok_or_else(|| {
            ApiError::bad_request(
                "The dealer payment node is not ready. Try again shortly.".to_string(),
            )
        })?;
    let db = state.db.lock().map_err(internal_error)?;
    authorized_demo_dealer(&db, dealer_key, &runtime_node_id)?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

async fn create_dealer_invoice(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
    Json(input): Json<DealerInvoiceRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), ApiError> {
    let amount_sats = dealer_amount_sats(input.amount_ngn)?;
    let dealer_key = headers
        .get("x-dealer-key")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    let runtime = ln::runtime().ok_or_else(|| {
        ApiError::bad_request(
            "The dealer payment node is not ready. Try again shortly.".to_string(),
        )
    })?;
    let runtime_node_id = runtime.dealer.node_id().to_string();
    let dealer_id = {
        let db = state.db.lock().map_err(internal_error)?;
        authorized_demo_dealer(&db, dealer_key, &runtime_node_id)?
    };
    let invoice = ln::dealer_invoice(
        amount_sats * 1000,
        "SatsFarm dealer sale on Mutinynet test network",
    )
    .map_err(|error| {
        ApiError::bad_request(format!("Could not create dealer invoice: {error:?}"))
    })?;
    let parsed = ln::parse_invoice(&invoice).map_err(|error| {
        ApiError::bad_request(format!("Could not validate dealer invoice: {error:?}"))
    })?;
    let id = uuid::Uuid::new_v4().simple().to_string();
    let created_at = Utc::now().timestamp();
    let expires_at = created_at + 60 * 60;
    let db = state.db.lock().map_err(internal_error)?;
    db.execute(
        "INSERT INTO dealer_invoices (id, dealer_id, amount_ngn, amount_sats, rate_used, invoice, payment_hash, state, created_at, expires_at) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 'Pending', ?8, ?9)",
        params![
            id,
            dealer_id,
            input.amount_ngn,
            amount_sats,
            ln::RATE_NGN_PER_SAT,
            invoice,
            parsed.payment_hash_hex,
            created_at,
            expires_at,
        ],
    )
    .map_err(internal_error)?;
    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({
            "id": id,
            "invoice": invoice,
            "amountNgn": input.amount_ngn,
            "status": "Pending",
            "expiresAt": expires_at,
        })),
    ))
}

async fn list_dealer_invoices(
    State(state): State<AppState>,
) -> Result<Json<Vec<serde_json::Value>>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    db.execute(
        "UPDATE dealer_invoices SET state = 'Expired' WHERE state = 'Pending' AND expires_at <= ?1",
        [Utc::now().timestamp()],
    )
    .map_err(internal_error)?;
    let mut statement = db
        .prepare(
            "SELECT i.id, d.name, i.amount_ngn, i.state, i.created_at FROM dealer_invoices i JOIN dealers d ON d.id = i.dealer_id ORDER BY i.created_at DESC",
        )
        .map_err(internal_error)?;
    let rows = statement
        .query_map([], |row| {
            let created_at: i64 = row.get(4)?;
            let created_label = chrono::DateTime::<Utc>::from_timestamp(created_at, 0)
                .map(|date| {
                    date.with_timezone(&Local)
                        .format("%d %b %Y, %H:%M")
                        .to_string()
                })
                .unwrap_or_else(|| "Unknown".to_owned());
            Ok(serde_json::json!({
                "id": row.get::<_, String>(0)?,
                "dealer": row.get::<_, String>(1)?,
                "amountNgn": row.get::<_, i64>(2)?,
                "status": row.get::<_, String>(3)?,
                "createdAt": created_label,
            }))
        })
        .map_err(internal_error)?;
    Ok(Json(
        rows.collect::<Result<Vec<_>, _>>()
            .map_err(internal_error)?,
    ))
}

async fn get_dealer_invoice(
    State(state): State<AppState>,
    axum::extract::Path(id): axum::extract::Path<String>,
    headers: axum::http::HeaderMap,
) -> Result<Json<serde_json::Value>, ApiError> {
    let dealer_key = headers
        .get("x-dealer-key")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    let runtime_node_id = ln::runtime()
        .map(|runtime| runtime.dealer.node_id().to_string())
        .ok_or_else(|| {
            ApiError::bad_request(
                "The dealer payment node is not ready. Try again shortly.".to_string(),
            )
        })?;
    let db = state.db.lock().map_err(internal_error)?;
    let dealer_id = authorized_demo_dealer(&db, dealer_key, &runtime_node_id)?;
    let invoice: Option<(i64, String, i64)> = db
        .query_row(
            "SELECT amount_ngn, state, expires_at FROM dealer_invoices WHERE id = ?1 AND dealer_id = ?2",
            params![id, dealer_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        )
        .optional()
        .map_err(internal_error)?;
    let Some((amount_ngn, mut status, expires_at)) = invoice else {
        return Err(ApiError {
            error: "Payment was not found.".to_string(),
            status: StatusCode::NOT_FOUND,
        });
    };
    if status == "Pending" && Utc::now().timestamp() >= expires_at {
        db.execute(
            "UPDATE dealer_invoices SET state = 'Expired' WHERE id = ?1 AND state = 'Pending'",
            [&id],
        )
        .map_err(internal_error)?;
        status = "Expired".to_string();
    }
    Ok(Json(serde_json::json!({
        "id": id,
        "amountNgn": amount_ngn,
        "status": status,
    })))
}

async fn dealer_invoice_history(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> Result<Json<Vec<serde_json::Value>>, ApiError> {
    let dealer_key = headers
        .get("x-dealer-key")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();
    let runtime_node_id = ln::runtime()
        .map(|runtime| runtime.dealer.node_id().to_string())
        .ok_or_else(|| {
            ApiError::bad_request(
                "The dealer payment node is not ready. Try again shortly.".to_string(),
            )
        })?;
    let db = state.db.lock().map_err(internal_error)?;
    let dealer_id = authorized_demo_dealer(&db, dealer_key, &runtime_node_id)?;
    let mut statement = db
        .prepare(
            "SELECT i.id, i.amount_ngn, i.amount_sats, i.rate_used, i.state, i.created_at, i.invoice, i.payment_hash, LOWER(py.preimage)
             FROM dealer_invoices i
             LEFT JOIN payments py ON py.payment_hash = i.payment_hash AND py.state = 'Settled'
             WHERE i.dealer_id = ?1
             GROUP BY i.id
             ORDER BY i.created_at DESC LIMIT 20",
        )
        .map_err(internal_error)?;
    let rows = statement
        .query_map([dealer_id], |row| {
            let preimage: Option<String> = row.get(8)?;
            Ok(serde_json::json!({
                "id": row.get::<_, String>(0)?,
                "amountNgn": row.get::<_, i64>(1)?,
                "amountSats": row.get::<_, i64>(2)?,
                "rateUsed": row.get::<_, i64>(3)?,
                "status": row.get::<_, String>(4)?,
                "createdAt": row.get::<_, i64>(5)?,
                "invoice": row.get::<_, String>(6)?,
                "paymentHash": row.get::<_, Option<String>>(7)?,
                "preimage": preimage,
            }))
        })
        .map_err(internal_error)?;
    Ok(Json(
        rows.collect::<Result<Vec<_>, _>>()
            .map_err(internal_error)?,
    ))
}

/// Public, no-auth settlement proof so judges and funder partners can verify a
/// payment without any dealer or program credentials: hash + preimage hashes to
/// the payment hash (so anyone can re-check sha256 locally) plus the Mutinynet
/// explorer reference for the channel.
async fn lightning_payment_proof(
    State(state): State<AppState>,
    axum::extract::Path(payment_hash_hex): axum::extract::Path<String>,
) -> Result<Json<serde_json::Value>, ApiError> {
    let payment_hash_hex = payment_hash_hex.trim().to_lowercase();
    if payment_hash_hex.len() != 64
        || !payment_hash_hex.chars().all(|c| c.is_ascii_hexdigit())
    {
        return Err(ApiError::bad_request(
            "A payment hash is 64 hex characters.".to_string(),
        ));
    }
    let db = state.db.lock().map_err(internal_error)?;
    let row: Option<(String, Option<String>, Option<i64>, Option<String>, Option<i64>)> = db
        .query_row(
            "SELECT d.dealer, d.amount_ngn, d.amount_sats, p.preimage, d.rate_used
             FROM dealer_invoices d
             LEFT JOIN payments p ON p.payment_hash = d.payment_hash AND p.state = 'Settled'
             WHERE d.payment_hash = ?1
             GROUP BY d.id
             ORDER BY d.created_at DESC LIMIT 1",
            [&payment_hash_hex],
            |row| {
                Ok((
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                ))
            },
        )
        .optional()
        .map_err(internal_error)?;
    use ldk_node::bitcoin::hashes::Hash;
    let Some((dealer_name, amount_ngn, amount_sats, preimage, rate_used)) = row else {
        return Err(ApiError {
            error: "No recorded payment for this payment hash.".to_string(),
            status: StatusCode::NOT_FOUND,
        });
    };
    let preimage: Option<String> = preimage.map(|value| value.to_lowercase());
    let preimage_bytes = preimage.as_ref().map(|hex_preimage| {
        (0..hex_preimage.len() / 2)
            .map(|index| {
                u8::from_str_radix(&hex_preimage[index * 2..index * 2 + 2], 16)
                    .unwrap_or_default()
            })
            .collect::<Vec<u8>>()
    });
    let preimage_hashes_to_payment_hash = preimage_bytes
        .as_deref()
        .map(|bytes| {
            ldk_node::bitcoin::hashes::sha256::Hash::hash(bytes).to_string()
                == payment_hash_hex
        })
        .unwrap_or(false);
    Ok(Json(serde_json::json!({
        "network": "Mutinynet (Bitcoin test network; coins have no monetary value)",
        "explorer": "https://mutinynet.com/",
        "paymentHash": payment_hash_hex,
        "paidToDealer": dealer_name,
        "status": if preimage_hashes_to_payment_hash { "Settled" } else { "Not settled" },
        "amountSats": amount_sats,
        "amountNgn": amount_ngn,
        "rateUsedNgnPerSat": rate_used,
        "preimage": preimage,
        "preimageSha256MatchesPaymentHash": preimage_hashes_to_payment_hash,
        "verification": format!(
            "sha256(hex-decoded preimage) == payment hash if {}",
            payment_hash_hex
        ),
    })))
}

async fn ln_status() -> Json<serde_json::Value> {
    let unavailable = serde_json::json!({
        "network": ln::TAG,
        "version": ln::NODE_VERSION,
        "ready": false,
        "rateNgnPerSat": ln::RATE_NGN_PER_SAT,
        "rateLabel": ln::RATE_LABEL,
        "detail": "Lightning nodes are still bootstrapping or failed to start; retry shortly."
    });
    match ln::runtime() {
        None => Json(unavailable),
        Some(rt) => {
            let balances = rt.funder.list_balances();
            let status = rt.funder.status();
            let channels = rt
                .funder
                .list_channels()
                .into_iter()
                .map(|channel| {
                    serde_json::json!({
                        "counterpartyNodeId": channel.counterparty_node_id.to_string(),
                        "channelValueSats": channel.channel_value_sats,
                        "outboundCapacitySats": channel.outbound_capacity_msat / 1000,
                        "inboundCapacitySats": channel.inbound_capacity_msat / 1000,
                        "confirmationsRequired": channel.confirmations_required,
                        "isUsable": channel.is_usable,
                        "fundingTxid": channel.funding_txo.map(|txo| txo.txid.to_string()),
                    })
                })
                .collect::<Vec<_>>();
            let peers = rt
                .funder
                .list_peers()
                .into_iter()
                .map(|peer| peer.node_id.to_string())
                .collect::<Vec<_>>();
            Json(serde_json::json!({
                "network": ln::TAG,
                "version": ln::NODE_VERSION,
                "ready": true,
                "rateNgnPerSat": ln::RATE_NGN_PER_SAT,
                "rateLabel": ln::RATE_LABEL,
                "funder": {
                    "nodeId": rt.funder.node_id().to_string(),
                    "isRunning": status.is_running,
                    "spendableOnchainSats": balances.spendable_onchain_balance_sats,
                    "totalOnchainSats": balances.total_onchain_balance_sats,
                    "anchorReserveSats": balances.total_anchor_channels_reserve_sats,
                    "lightningSats": balances.total_lightning_balance_sats,
                    "channels": channels,
                    "peers": peers,
                },
                "dealer": { "nodeId": rt.dealer.node_id().to_string() }
            }))
        }
    }
}

async fn funder_receive_address() -> Result<Json<serde_json::Value>, ApiError> {
    let runtime = ln::runtime().ok_or_else(|| ApiError {
        error: "Funder node is not ready yet. Try again after Lightning finishes starting."
            .to_string(),
        status: StatusCode::SERVICE_UNAVAILABLE,
    })?;
    let address = runtime
        .funder
        .onchain_payment()
        .new_address()
        .map_err(internal_error)?;
    Ok(Json(serde_json::json!({
        "address": address.to_string(),
        "network": ln::TAG,
    })))
}

/// Mint a BOLT11 invoice on the demo dealer node so the whole flow can be
/// exercised end-to-end without an external dealer paying-in.
async fn request_payment(
    State(state): State<AppState>,
    Json(input): Json<RequestPayment>,
) -> Result<(StatusCode, Json<serde_json::Value>), ApiError> {
    let invoice_str = input.invoice.trim();
    if invoice_str.is_empty() {
        return Err(ApiError::bad_request("invoice is required.".to_string()));
    }
    let parsed = ln::parse_invoice(invoice_str).map_err(|e| {
        ApiError::bad_request(match e {
            ln::LnError::InvalidInvoice(message) => format!("Invalid invoice: {message}"),
            other => format!("Could not read the invoice: {other:?}"),
        })
    })?;
    if parsed.amount_msat % 1000 != 0 {
        return Err(ApiError::bad_request(
            "Voucher payments cover whole sats only; the invoice's msat remainder is not allowed."
                .to_string(),
        ));
    }
    let amount_sats = i64::try_from(parsed.amount_msat / 1000).map_err(|_| {
        ApiError::bad_request("Invoice amount overflows the demo limits.".to_string())
    })?;
    let needed_ngn = amount_sats.saturating_mul(ln::RATE_NGN_PER_SAT);
    if needed_ngn > 10_000_000 {
        return Err(ApiError::bad_request(
            "The invoice cost exceeds this demo's N10,000,000 voucher ceiling.".to_string(),
        ));
    }
    let client_key = input
        .idempotency_key
        .as_deref()
        .map(str::trim)
        .filter(|key| !key.is_empty())
        .map(str::to_owned)
        .unwrap_or_else(|| parsed.payment_hash_hex.clone());

    let db = state.db.lock().map_err(internal_error)?;
    // Idempotency first: same invoice or same client key -> existing row.
    let existing: Option<String> = db
        .query_row(
            "SELECT id FROM payments WHERE payment_hash = ?1 OR (idempotency_key = ?2 AND idempotency_key IS NOT NULL) ORDER BY sort_order DESC LIMIT 1",
            params![parsed.payment_hash_hex, client_key],
            |row| row.get(0),
        )
        .optional()
        .map_err(internal_error)?;
    if let Some(id) = existing {
        let payment = load_payment(&db, &id)?;
        return Ok((
            StatusCode::OK,
            Json(serde_json::json!({ "idempotent": true, "payment": payment })),
        ));
    }

    // Voucher check.
    let voucher: Option<(String, i64, String)> = db
        .query_row(
            "SELECT farmer_id, remaining_ngn, status FROM vouchers WHERE id = ?1",
            [&input.voucher_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        )
        .optional()
        .map_err(internal_error)?;
    let Some((farmer_id, remaining_ngn, _voucher_status)) = voucher else {
        return Err(ApiError::bad_request(format!(
            "Voucher {} was not found.",
            input.voucher_id
        )));
    };
    if needed_ngn > remaining_ngn {
        return Err(ApiError::bad_request(format!(
            "This dealer invoice needs {needed_ngn} NGN at the demo rate; the voucher holds {remaining_ngn} NGN."
        )));
    }

    // Whitelist check on the invoice's payee node ID.
    let payee_hex = parsed.payee.to_string();
    let whitelisted: bool = db
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM dealers WHERE node_id = ?1 AND whitelisted = 1)",
            [&payee_hex],
            |row| row.get(0),
        )
        .map_err(internal_error)?;
    if !whitelisted {
        return Err(ApiError::bad_request(format!(
            "Node ID {payee_hex} is not whitelisted for dealer payments."
        )));
    }
    let dealer_label: String = db
        .query_row(
            "SELECT name FROM dealers WHERE node_id = ?1 AND whitelisted = 1",
            [&payee_hex],
            |row| row.get(0),
        )
        .optional()
        .map_err(internal_error)?
        .unwrap_or_else(|| format!("Lightning dealer {}", payee_hex[2..10].to_uppercase()));

    // Insert Pending row, then attempt the send; synchronous errors move the
    // row to Failed immediately.
    let id = format!(
        "SF-{}",
        uuid::Uuid::new_v4().simple().to_string()[..8].to_uppercase()
    );
    let time = Local::now().format("%d %b %Y, %H:%M").to_string();
    let sort_order = chrono::Utc::now().timestamp();
    let insert_result = db.execute(
        "INSERT INTO payments (id, farmer_id, dealer, amount_ngn, amount_sats, state, time, sort_order, voucher_id, invoice, payment_hash, preimage, idempotency_key, rate_used, error_reason) VALUES (?1,?2,?3,?4,?5,'Pending',?6,?7,?8,?9,?10,NULL,?11,?12,NULL)",
        params![
            id,
            farmer_id,
            dealer_label,
            needed_ngn,
            amount_sats,
            time,
            sort_order,
            input.voucher_id,
            invoice_str,
            parsed.payment_hash_hex,
            client_key,
            ln::RATE_NGN_PER_SAT,
        ],
    );
    if let Err(rusqlite::Error::SqliteFailure(ffi_error, _)) = &insert_result
        && ffi_error.extended_code == rusqlite::ffi::SQLITE_CONSTRAINT_UNIQUE
    {
        let id_2: Option<String> = db
                .query_row(
                    "SELECT id FROM payments WHERE idempotency_key = ?1 ORDER BY sort_order DESC LIMIT 1",
                    [&client_key],
                    |row| row.get(0),
                )
                .optional()
                .map_err(internal_error)?;
        let payment = load_payment(
            &db,
            &id_2.ok_or_else(|| internal_error("unique insert raced"))?,
        )?;
        return Ok((
            StatusCode::OK,
            Json(serde_json::json!({ "idempotent": true, "payment": payment })),
        ));
    }
    insert_result.map_err(internal_error)?;

    match ln::initiate_payment(&parsed) {
        Ok(()) => {
            let payment = load_payment(&db, &id)?;
            Ok((
                StatusCode::CREATED,
                Json(serde_json::json!({ "idempotent": false, "payment": payment })),
            ))
        }
        Err(ln::LnError::Duplicate) => {
            db.execute(
                "UPDATE payments SET state = 'Failed', error_reason = ?2 WHERE id = ?1",
                params![
                    id,
                    "DuplicatePayment: node already has a payment for this invoice/payee."
                ],
            )
            .map_err(internal_error)?;
            db.execute(
                "UPDATE dealer_invoices SET state = 'Failed' WHERE payment_hash = ?1 AND state = 'Pending'",
                [&parsed.payment_hash_hex],
            )
            .map_err(internal_error)?;
            let payment = load_payment(&db, &id)?;
            Ok((
                StatusCode::OK,
                Json(serde_json::json!({ "idempotent": false, "payment": payment })),
            ))
        }
        Err(ln::LnError::NotRunning) => {
            db.execute("DELETE FROM payments WHERE id = ?1", params![id])
                .map_err(internal_error)?;
            Err(ApiError::bad_request(
                "Lightning runtime is not ready; the request was not recorded. Retry shortly."
                    .to_string(),
            ))
        }
        Err(other) => {
            let reason = format!("{other:?}");
            db.execute(
                "UPDATE payments SET state = 'Failed', error_reason = ?2 WHERE id = ?1",
                params![id, reason],
            )
            .map_err(internal_error)?;
            db.execute(
                "UPDATE dealer_invoices SET state = 'Failed' WHERE payment_hash = ?1 AND state = 'Pending'",
                [&parsed.payment_hash_hex],
            )
            .map_err(internal_error)?;
            let payment = load_payment(&db, &id)?;
            Ok((
                StatusCode::OK,
                Json(serde_json::json!({ "idempotent": false, "payment": payment })),
            ))
        }
    }
}

fn load_payment(db: &Connection, id: &str) -> Result<Payment, ApiError> {
    db.query_row(
        "SELECT id, farmer_id, dealer, amount_ngn, amount_sats, state, time, voucher_id, invoice, payment_hash, preimage, error_reason, rate_used FROM payments WHERE id = ?1",
        [id],
        |row| {
            Ok(Payment {
                id: row.get(0)?,
                farmer_id: row.get(1)?,
                dealer: row.get(2)?,
                amount_ngn: row.get(3)?,
                amount_sats: row.get(4)?,
                state: row.get(5)?,
                time: row.get(6)?,
                voucher_id: row.get(7)?,
                invoice: row.get(8)?,
                payment_hash: row.get(9)?,
                preimage: row.get(10)?,
                error_reason: row.get(11)?,
                rate_used: row.get(12)?,
                rate_label: None,
            })
        },
    )
    .optional()
    .map_err(internal_error)?
    .map(|mut payment| {
        payment.rate_label = payment.rate_used.map(|_| ln::RATE_LABEL.to_string());
        payment
    })
    .ok_or_else(|| ApiError::bad_request(format!("Payment {id} was not found.")))
}

async fn reset_demo(State(state): State<AppState>) -> Result<Json<serde_json::Value>, ApiError> {
    let db = state.db.lock().map_err(internal_error)?;
    seed_demo_data(&db).map_err(internal_error)?;
    Ok(Json(serde_json::json!({ "ok": true })))
}

fn timestamp_to_rfc3339(timestamp: i64) -> String {
    chrono::DateTime::<Utc>::from_timestamp(timestamp, 0)
        .expect("invite timestamps are within the supported UTC range")
        .to_rfc3339()
}

fn insert_invite(db: &Connection, farmer_id: &str, now: i64) -> rusqlite::Result<String> {
    const ALPHABET: &[u8; 32] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    loop {
        let bytes = uuid::Uuid::new_v4();
        let code: String = bytes
            .as_bytes()
            .iter()
            .take(10)
            .map(|byte| ALPHABET[(byte & 31) as usize] as char)
            .collect();
        match db.execute(
            "INSERT INTO invite_codes (farmer_id, code, created_at, expires_at) VALUES (?1, ?2, ?3, ?4)",
            params![farmer_id, code, now, now + INVITE_LIFETIME_SECONDS],
        ) {
            Ok(_) => return Ok(code),
            Err(error)
                if error.sqlite_error_code()
                    == Some(rusqlite::ErrorCode::ConstraintViolation) =>
            {
                continue;
            }
            Err(error) => return Err(error),
        }
    }
}

fn initialize_database(db: &Connection) -> rusqlite::Result<()> {
    db.execute_batch("PRAGMA foreign_keys = ON;
        CREATE TABLE IF NOT EXISTS farmers (id TEXT PRIMARY KEY, name TEXT NOT NULL, location TEXT NOT NULL, language TEXT NOT NULL, device_id TEXT, phone_number TEXT);
        CREATE TABLE IF NOT EXISTS vouchers (id TEXT PRIMARY KEY, farmer_id TEXT NOT NULL REFERENCES farmers(id), purpose TEXT NOT NULL, amount_ngn INTEGER NOT NULL, remaining_ngn INTEGER NOT NULL, created_at TEXT NOT NULL, status TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'Grant');
        CREATE TABLE IF NOT EXISTS repayments (id TEXT PRIMARY KEY, voucher_id TEXT NOT NULL REFERENCES vouchers(id), request_id TEXT NOT NULL UNIQUE, amount_ngn INTEGER NOT NULL CHECK (amount_ngn > 0), repayment_type TEXT NOT NULL CHECK (repayment_type IN ('Grain', 'Cash', 'Transfer')), note TEXT, time TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS dealers (id INTEGER PRIMARY KEY, name TEXT NOT NULL, location TEXT NOT NULL, node_id TEXT NOT NULL, whitelisted INTEGER NOT NULL, dealer_key TEXT);
        CREATE TABLE IF NOT EXISTS payments (id TEXT PRIMARY KEY, farmer_id TEXT NOT NULL REFERENCES farmers(id), dealer TEXT NOT NULL, amount_ngn INTEGER NOT NULL, amount_sats INTEGER NOT NULL, state TEXT NOT NULL, time TEXT NOT NULL, sort_order INTEGER NOT NULL, voucher_id TEXT, invoice TEXT, payment_hash TEXT, payment_id TEXT, preimage TEXT, idempotency_key TEXT, rate_used INTEGER, error_reason TEXT);
        CREATE TABLE IF NOT EXISTS dealer_invoices (
            id TEXT PRIMARY KEY,
            dealer_id INTEGER NOT NULL REFERENCES dealers(id),
            amount_ngn INTEGER NOT NULL,
            amount_sats INTEGER NOT NULL,
            rate_used INTEGER NOT NULL,
            invoice TEXT NOT NULL,
            payment_hash TEXT NOT NULL UNIQUE,
            state TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS invite_codes (
            id INTEGER PRIMARY KEY,
            farmer_id TEXT NOT NULL REFERENCES farmers(id),
            code TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            used INTEGER NOT NULL DEFAULT 0,
            invalidated INTEGER NOT NULL DEFAULT 0,
            used_by_client TEXT,
            session_token TEXT
        );")?;
    // Best-effort migrations for DBs created by the pre-Lightning build.
    for sql in [
        "ALTER TABLE payments ADD COLUMN voucher_id TEXT",
        "ALTER TABLE payments ADD COLUMN invoice TEXT",
        "ALTER TABLE payments ADD COLUMN payment_hash TEXT",
        "ALTER TABLE payments ADD COLUMN payment_id TEXT",
        "ALTER TABLE payments ADD COLUMN preimage TEXT",
        "ALTER TABLE payments ADD COLUMN idempotency_key TEXT",
        "ALTER TABLE payments ADD COLUMN rate_used INTEGER",
        "ALTER TABLE payments ADD COLUMN error_reason TEXT",
        "ALTER TABLE farmers ADD COLUMN device_id TEXT",
        "ALTER TABLE farmers ADD COLUMN phone_number TEXT",
        "ALTER TABLE vouchers ADD COLUMN kind TEXT NOT NULL DEFAULT 'Grant'",
        "ALTER TABLE dealers ADD COLUMN dealer_key TEXT",
    ] {
        let _ = db.execute_batch(sql);
    }
    db.execute_batch(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_idempotency ON payments(idempotency_key) WHERE idempotency_key IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_hash ON payments(payment_hash) WHERE payment_hash IS NOT NULL AND state <> 'Failed';")?;
    let has_farmers: bool =
        db.query_row("SELECT EXISTS(SELECT 1 FROM farmers)", [], |row| row.get(0))?;
    if !has_farmers {
        seed_demo_data(db)?;
    } else {
        let tx = db.unchecked_transaction()?;
        let farmer_ids = {
            let mut statement = tx.prepare(
                "SELECT f.id FROM farmers f WHERE NOT EXISTS (
                    SELECT 1 FROM invite_codes i WHERE i.farmer_id = f.id AND i.invalidated = 0
                )",
            )?;
            statement
                .query_map([], |row| row.get::<_, String>(0))?
                .collect::<Result<Vec<_>, _>>()?
        };
        let now = Utc::now().timestamp();
        for farmer_id in farmer_ids {
            insert_invite(&tx, &farmer_id, now)?;
        }
        tx.commit()?;
    }
    Ok(())
}

fn seed_demo_data(db: &Connection) -> rusqlite::Result<()> {
    let tx = db.unchecked_transaction()?;
    tx.execute_batch(
        "DELETE FROM payments; DELETE FROM dealer_invoices; DELETE FROM repayments; DELETE FROM vouchers; DELETE FROM invite_codes; DELETE FROM dealers; DELETE FROM farmers;",
    )?;
    for (id, name, location, language) in [
        ("F-1042", "Amina Yusuf", "Zaria, Kaduna", "Hausa"),
        ("F-1043", "Musa Ibrahim", "Kano Municipal", "Hausa"),
        ("F-1044", "Hauwa Adamu", "Katsina, Katsina", "Hausa"),
        ("F-1045", "Bello Usman", "Sokoto North", "English"),
    ] {
        tx.execute(
            "INSERT INTO farmers (id, name, location, language) VALUES (?1, ?2, ?3, ?4)",
            params![id, name, location, language],
        )?;
        insert_invite(&tx, id, Utc::now().timestamp())?;
    }
    for (id, farmer, purpose, amount, date, kind) in [
        (
            "SF-2081",
            "F-1042",
            "Seed & fertilizer",
            50000,
            "18 Oct 2026",
            "Loan",
        ),
        (
            "SF-2080",
            "F-1043",
            "Maize seed",
            35000,
            "17 Oct 2026",
            "Grant",
        ),
        (
            "SF-2079",
            "F-1044",
            "Fertilizer",
            42000,
            "16 Oct 2026",
            "Grant",
        ),
        (
            "SF-2078",
            "F-1045",
            "Seed & fertilizer",
            60000,
            "15 Oct 2026",
            "Loan",
        ),
    ] {
        tx.execute(
            "INSERT INTO vouchers (id, farmer_id, purpose, amount_ngn, remaining_ngn, created_at, status, kind) VALUES (?1, ?2, ?3, ?4, ?4, ?5, 'Active', ?6)",
            params![id, farmer, purpose, amount, date, kind],
        )?;
    }
    for (name, location, node_id) in [
        ("Gidan Noma Agro", "Zaria, Kaduna", "02f3…91ac"),
        ("Northern Seeds Co.", "Kano Municipal", "03bd…4e72"),
        ("Kano Farm Inputs", "Kano Municipal", "02a1…88df"),
    ] {
        tx.execute(
            "INSERT INTO dealers (name, location, node_id, whitelisted) VALUES (?1, ?2, ?3, 1)",
            params![name, location, node_id],
        )?;
    }
    for (id, farmer, dealer, ngn, sats, state, time, order) in [
        (
            "PAY-9032",
            "F-1042",
            "Gidan Noma Agro",
            18000,
            8200,
            "Settled",
            "Today, 10:42",
            4,
        ),
        (
            "PAY-9031",
            "F-1044",
            "Northern Seeds Co.",
            12500,
            5700,
            "Pending",
            "Today, 09:18",
            3,
        ),
        (
            "PAY-9030",
            "F-1043",
            "Kano Farm Inputs",
            9500,
            4300,
            "Settled",
            "Yesterday, 16:05",
            2,
        ),
        (
            "PAY-9029",
            "F-1045",
            "Sokoto Growers Supply",
            7200,
            3300,
            "Failed",
            "Yesterday, 13:27",
            1,
        ),
    ] {
        tx.execute(
            "INSERT INTO payments (id, farmer_id, dealer, amount_ngn, amount_sats, state, time, sort_order) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![id, farmer, dealer, ngn, sats, state, time, order],
        )?;
    }
    tx.commit()
}

fn internal_error(error: impl std::fmt::Display) -> ApiError {
    eprintln!("api error: {error}");
    ApiError {
        error: "The local demo API could not complete the request.".into(),
        status: StatusCode::INTERNAL_SERVER_ERROR,
    }
}

#[cfg(test)]
mod invite_tests {
    use super::*;

    fn test_state() -> AppState {
        let db = Connection::open_in_memory().unwrap();
        initialize_database(&db).unwrap();
        AppState {
            db: Arc::new(Mutex::new(db)),
            demo_dealer_keys: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    #[test]
    fn dealer_key_requires_an_active_registration_for_the_demo_node() {
        let state = test_state();
        let db = state.db.lock().unwrap();
        db.execute(
            "INSERT INTO dealers (name, location, node_id, whitelisted, dealer_key) VALUES ('Demo shop', '', '02demo', 1, ?1)",
            [dealer_key_hash("secret-link-key")],
        )
        .unwrap();
        let dealer_id: i64 = db
            .query_row(
                "SELECT id FROM dealers WHERE node_id = '02demo'",
                [],
                |row| row.get(0),
            )
            .unwrap();

        assert_eq!(
            authorized_demo_dealer(&db, "secret-link-key", "02demo").unwrap(),
            dealer_id
        );
        assert_eq!(
            authorized_demo_dealer(&db, "wrong-key", "02demo")
                .unwrap_err()
                .status,
            StatusCode::FORBIDDEN
        );
        assert_eq!(
            authorized_demo_dealer(&db, "secret-link-key", "another-node")
                .unwrap_err()
                .status,
            StatusCode::FORBIDDEN
        );

        db.execute(
            "UPDATE dealers SET whitelisted = 0 WHERE node_id = '02demo'",
            [],
        )
        .unwrap();
        assert_eq!(
            authorized_demo_dealer(&db, "secret-link-key", "02demo")
                .unwrap_err()
                .status,
            StatusCode::FORBIDDEN
        );
    }

    #[test]
    fn dealer_amount_conversion_is_exact_and_bounded() {
        assert_eq!(dealer_amount_sats(50_000).unwrap(), 10_000);
        assert_eq!(dealer_amount_sats(5).unwrap(), 1);
        assert!(dealer_amount_sats(6).is_err());
        assert!(dealer_amount_sats(0).is_err());
        assert!(dealer_amount_sats(500_005).is_err());

        let first = new_dealer_key();
        let second = new_dealer_key();
        assert_eq!(first.len(), 32);
        assert_ne!(first, second);
    }

    #[test]
    fn two_demo_dealers_are_registered_on_the_shared_demo_node() {
        let state = test_state();
        let dealers = ensure_demo_dealers(&state, "runtime-demo-node").unwrap();
        assert_eq!(dealers.len(), 2);
        assert_eq!(dealers[0].name, "Gidan Noma Agro");
        assert_eq!(dealers[1].name, "Northern Seeds Co.");

        let db = state.db.lock().unwrap();
        let first =
            authorized_demo_dealer(&db, &dealers[0].dealer_key, "runtime-demo-node").unwrap();
        let second =
            authorized_demo_dealer(&db, &dealers[1].dealer_key, "runtime-demo-node").unwrap();
        assert_ne!(first, second);
        drop(db);

        let repeat = ensure_demo_dealers(&state, "runtime-demo-node").unwrap();
        assert_eq!(repeat[0].dealer_key, dealers[0].dealer_key);
        assert_eq!(repeat[1].dealer_key, dealers[1].dealer_key);
    }

    #[tokio::test]
    async fn dealer_invoice_activity_is_visible_to_admin_and_expires() {
        let state = test_state();
        let dealers = ensure_demo_dealers(&state, "runtime-demo-node").unwrap();
        let dealer_id = {
            let db = state.db.lock().unwrap();
            db.query_row(
                "SELECT id FROM dealers WHERE name = ?1 AND node_id = ?2",
                params![dealers[0].name, "runtime-demo-node"],
                |row| row.get::<_, i64>(0),
            )
            .unwrap()
        };
        let now = Utc::now().timestamp();
        {
            let db = state.db.lock().unwrap();
            db.execute(
                "INSERT INTO dealer_invoices (id, dealer_id, amount_ngn, amount_sats, rate_used, invoice, payment_hash, state, created_at, expires_at) VALUES ('demo-sale-1', ?1, 5000, 1000, 5, 'private-invoice', 'private-hash', 'Pending', ?2, ?3)",
                params![dealer_id, now, now + 60],
            )
            .unwrap();
        }

        let Json(sales) = list_dealer_invoices(State(state.clone())).await.unwrap();
        assert_eq!(sales[0]["dealer"], dealers[0].name);
        assert_eq!(sales[0]["amountNgn"], 5000);
        assert_eq!(sales[0]["status"], "Pending");
        assert!(sales[0].get("invoice").is_none());
        assert!(sales[0].get("paymentHash").is_none());

        {
            let db = state.db.lock().unwrap();
            db.execute(
                "UPDATE dealer_invoices SET expires_at = ?1 WHERE id = 'demo-sale-1'",
                [now - 1],
            )
            .unwrap();
        }
        let Json(expired_sales) = list_dealer_invoices(State(state)).await.unwrap();
        assert_eq!(expired_sales[0]["status"], "Expired");
    }

    #[tokio::test]
    async fn dealer_registration_and_regeneration_rotate_the_vendor_key() {
        let state = test_state();
        let node_id = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";
        let Json(created) = whitelist_dealer(
            State(state.clone()),
            Json(WhitelistDealer {
                node_id: node_id.to_owned(),
                name: Some("Demo shop".to_owned()),
                location: None,
                active: Some(true),
            }),
        )
        .await
        .unwrap();
        let first_key = created["dealerKey"].as_str().unwrap().to_owned();
        let Json(listed) = list_dealers(State(state.clone())).await.unwrap();
        let registered = listed
            .iter()
            .find(|dealer| dealer["nodeId"].as_str() == Some(node_id))
            .unwrap();
        assert!(registered.get("dealerKey").is_none());

        let Json(rotated) = regenerate_dealer_key(
            State(state.clone()),
            axum::extract::Path(node_id.to_owned()),
        )
        .await
        .unwrap();
        let second_key = rotated["dealerKey"].as_str().unwrap().to_owned();
        assert_ne!(first_key, second_key);

        let db = state.db.lock().unwrap();
        assert!(
            authorized_demo_dealer(&db, &first_key, node_id)
                .unwrap_err()
                .status
                == StatusCode::FORBIDDEN
        );
        assert!(authorized_demo_dealer(&db, &second_key, node_id).is_ok());
    }

    async fn create_farmer(state: &AppState) -> Farmer {
        let (_, Json(farmer)) = create_dashboard_farmer(
            State(state.clone()),
            Json(CreateDashboardFarmer {
                name: "Demo Farmer".to_owned(),
                phone_number: "+2348000000000".to_owned(),
                support_amount: 52_500,
            }),
        )
        .await
        .unwrap();
        farmer
    }

    #[tokio::test]
    async fn creating_farmer_redeeming_and_same_client_retry_return_balance() {
        let state = test_state();
        let farmer = create_farmer(&state).await;
        let code = farmer.invite_code.as_deref().unwrap();
        assert_eq!(code.len(), 10);
        assert!(
            code.chars()
                .all(|character| character.is_ascii_alphanumeric())
        );

        let request = RedeemInvite {
            code: code.to_owned(),
            client_id: "demo-client-device-0001".to_owned(),
        };
        let Json(first) = redeem_invite(State(state.clone()), Json(request))
            .await
            .unwrap();
        assert_eq!(first.farmer_name, "Demo Farmer");
        assert_eq!(first.balance_ngn, 52_500);

        let Json(retry) = redeem_invite(
            State(state.clone()),
            Json(RedeemInvite {
                code: code.to_owned(),
                client_id: "demo-client-device-0001".to_owned(),
            }),
        )
        .await
        .unwrap();
        assert_eq!(retry.session_token, first.session_token);

        let error = redeem_invite(
            State(state.clone()),
            Json(RedeemInvite {
                code: code.to_owned(),
                client_id: "different-client-device-0002".to_owned(),
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(error.error, "already_used");

        let mut headers = axum::http::HeaderMap::new();
        headers.insert(
            axum::http::header::AUTHORIZATION,
            format!("Bearer {}", first.session_token).parse().unwrap(),
        );
        let Json(account) = farmer_account(State(state), headers).await.unwrap();
        assert_eq!(account.farmer_name, "Demo Farmer");
        assert_eq!(account.balance_ngn, 52_500);
        assert_eq!(account.history.len(), 1);
    }

    #[tokio::test]
    async fn repayments_reduce_loan_owed_and_are_idempotent() {
        let state = test_state();
        let farmer = create_farmer(&state).await;
        let (_, Json(loan)) = create_voucher(
            State(state.clone()),
            Json(CreateVoucher {
                farmer_id: farmer.id.clone(),
                purpose: "Seed".to_owned(),
                amount: 3_000,
                kind: Some("Loan".to_owned()),
            }),
        )
        .await
        .unwrap();
        assert_eq!(loan.amount_owed_ngn, 3_000);

        let input = RecordRepayment {
            request_id: "demo-repayment-1".to_owned(),
            amount_ngn: 1_000,
            repayment_type: "Grain".to_owned(),
            note: Some("20 kg maize".to_owned()),
        };
        let Json(first) = record_repayment(
            State(state.clone()),
            axum::extract::Path(loan.id.clone()),
            Json(input),
        )
        .await
        .unwrap();
        assert!(!first.idempotent);
        assert_eq!(first.amount_owed_ngn, 2_000);

        let Json(retry) = record_repayment(
            State(state.clone()),
            axum::extract::Path(loan.id.clone()),
            Json(RecordRepayment {
                request_id: "demo-repayment-1".to_owned(),
                amount_ngn: 1_000,
                repayment_type: "grain".to_owned(),
                note: Some("20 kg maize".to_owned()),
            }),
        )
        .await
        .unwrap();
        assert!(retry.idempotent);
        assert_eq!(retry.repayment.id, first.repayment.id);
        assert_eq!(retry.amount_owed_ngn, 2_000);

        let error = record_repayment(
            State(state.clone()),
            axum::extract::Path(loan.id.clone()),
            Json(RecordRepayment {
                request_id: "too-large".to_owned(),
                amount_ngn: 2_001,
                repayment_type: "Cash".to_owned(),
                note: None,
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(error.status, StatusCode::BAD_REQUEST);

        let error = record_repayment(
            State(state.clone()),
            axum::extract::Path(loan.id.clone()),
            Json(RecordRepayment {
                request_id: "demo-repayment-1".to_owned(),
                amount_ngn: 999,
                repayment_type: "Grain".to_owned(),
                note: Some("20 kg maize".to_owned()),
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(error.status, StatusCode::CONFLICT);

        let (_, Json(grant)) = create_voucher(
            State(state.clone()),
            Json(CreateVoucher {
                farmer_id: farmer.id.clone(),
                purpose: "Grant".to_owned(),
                amount: 2_000,
                kind: Some("Grant".to_owned()),
            }),
        )
        .await
        .unwrap();
        let error = record_repayment(
            State(state.clone()),
            axum::extract::Path(grant.id),
            Json(RecordRepayment {
                request_id: "grant-repayment".to_owned(),
                amount_ngn: 500,
                repayment_type: "Transfer".to_owned(),
                note: None,
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(error.status, StatusCode::BAD_REQUEST);

        let count = state
            .db
            .lock()
            .unwrap()
            .query_row(
                "SELECT COUNT(*) FROM repayments WHERE voucher_id = ?1",
                [&loan.id],
                |row| row.get::<_, i64>(0),
            )
            .unwrap();
        assert_eq!(count, 1);

        let Json(farmer_vouchers) =
            list_farmer_vouchers(State(state.clone()), axum::extract::Path(farmer.id.clone()))
                .await
                .unwrap();
        assert_eq!(
            farmer_vouchers
                .iter()
                .find(|voucher| voucher.id == loan.id)
                .unwrap()
                .amount_owed_ngn,
            2_000
        );
        let Json(dashboard_vouchers) = list_vouchers(State(state.clone())).await.unwrap();
        assert_eq!(
            dashboard_vouchers
                .iter()
                .find(|voucher| voucher.id == loan.id)
                .unwrap()
                .amount_owed_ngn,
            2_000
        );

        let Json(redeemed) = redeem_invite(
            State(state.clone()),
            Json(RedeemInvite {
                code: farmer.invite_code.unwrap(),
                client_id: "repayment-history-test".to_owned(),
            }),
        )
        .await
        .unwrap();
        let mut headers = axum::http::HeaderMap::new();
        headers.insert(
            axum::http::header::AUTHORIZATION,
            format!("Bearer {}", redeemed.session_token)
                .parse()
                .unwrap(),
        );
        let Json(account) = farmer_account(State(state), headers).await.unwrap();
        let repayment = account
            .history
            .iter()
            .find(|entry| entry.kind == "Repayment")
            .unwrap();
        assert_eq!(repayment.repayment_type.as_deref(), Some("Grain"));
        assert_eq!(repayment.note.as_deref(), Some("20 kg maize"));
    }

    #[tokio::test]
    async fn expired_invite_is_refused() {
        let state = test_state();
        let farmer = create_farmer(&state).await;
        let code = farmer.invite_code.unwrap();
        state
            .db
            .lock()
            .unwrap()
            .execute(
                "UPDATE invite_codes SET expires_at = ?1 WHERE code = ?2",
                params![Utc::now().timestamp() - 1, code],
            )
            .unwrap();

        let error = redeem_invite(
            State(state),
            Json(RedeemInvite {
                code,
                client_id: "demo-client-device-0003".to_owned(),
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(error.error, "expired_code");
    }

    #[tokio::test]
    async fn regenerating_invite_invalidates_the_previous_code() {
        let state = test_state();
        let farmer = create_farmer(&state).await;
        let old_code = farmer.invite_code.unwrap();
        let Json(regenerated) =
            regenerate_invite(State(state.clone()), axum::extract::Path(farmer.id))
                .await
                .unwrap();
        let new_code = regenerated.invite_code.unwrap();
        assert_ne!(old_code, new_code);

        let old_error = redeem_invite(
            State(state.clone()),
            Json(RedeemInvite {
                code: old_code,
                client_id: "demo-client-device-0004".to_owned(),
            }),
        )
        .await
        .unwrap_err();
        assert_eq!(old_error.error, "invalid_code");

        let Json(joined) = redeem_invite(
            State(state),
            Json(RedeemInvite {
                code: new_code,
                client_id: "demo-client-device-0004".to_owned(),
            }),
        )
        .await
        .unwrap();
        assert_eq!(joined.farmer_name, "Demo Farmer");
        assert_eq!(joined.balance_ngn, 52_500);
    }
}
