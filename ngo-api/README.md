# SatsFarm local NGO API

A small Rust + Axum API with a SQLite demo ledger that also runs two
Lightning nodes (`ldk-node`, vendored 0.7.1 with a 120s BDK sync-timeout patch)
in-process: a **funder** node that pays dealer invoices and a **dealer** node
for end-to-end demos.

MUTINYNET (custom signet) TEST NETWORK ONLY — nothing here touches mainnet.

Naira↔sats conversion uses a **FIXED DEMO RATE: 5 NGN per sat (not a live
price)**, mirroring the Flutter app constant `mockNgnPerSatoshi`. Every payment
row stores the `rate_used` and repeats the rate label in API responses.

## Run locally

From the repository root, in terminal 1:

```sh
cd ngo-api
SATSFARM_API_ADDR=0.0.0.0:8787 cargo run
```

The API listens on port `8787`, creates
`ngo-api/data/satsfarm.sqlite` on first run, and boots the two LDK nodes in
background threads (storage: `ngo-api/data/ln/{funder,dealer}`, never print
seeds). `GET /api/ln/status` flips to `ready` once both nodes are up. In
terminal 2:

```sh
cd ngo-web
npm run dev
```

The API seeds fictional farmers, dealers, and example payment rows into the
local database. New vouchers persist across API and browser restarts. The
dashboard's **Reset demo data** button restores those seed records.

### Farmer invite demo

In the dashboard's Farmers page, add a farmer with their name, phone number,
and initial support amount. The API issues a 10-character single-use code that
expires after 24 hours. Show the code/QR to the farmer; regenerate it to
invalidate the previous code. A redemption is tied to a random install ID held
in the phone's secure storage. Retrying from that same installation returns
the same session, while a different installation is refused.

Run the API on a trusted local network as shown above, then run the Android
app with the laptop's LAN address:

```sh
flutter run -d <android-device> \
  --dart-define=SATS_FARM_API_URL=http://<pc-lan-ip>:8787
```

The base URL is a Flutter build setting (`SATS_FARM_API_URL`), not a source
constant. Debug Android builds allow cleartext HTTP for this LAN demo; release
builds do not. Keep the **Mutinynet test network** label visible; no mainnet
funds or farmer location/GPS data are used.

## HTTP endpoints

- `GET /api/health`
- `GET /api/ln/status` — node IDs, ready flag, channels, balances, demo rate label
- `POST /api/funder/receive-address` — generates a fresh on-chain receive
  address from the API funder node and returns `{ "address": "...",
  "network": "MUTINYNET (custom signet) TEST NETWORK ONLY" }`. Use Mutinynet
  test funds only. On-chain funds do not automatically add Lightning channel
  capacity.
- `GET /api/farmers`
- `POST /api/dashboard/farmers` `{ "name": "...", "phoneNumber": "...", "supportAmount": 50000 }`
  — creates a farmer and initial support balance, and returns the invite code
  and expiry.
- `POST /api/dashboard/farmers/{id}/invite` — invalidates the previous unused
  code and generates another 24-hour code.
- `POST /api/farmers/invites/redeem` `{ "code": "...", "clientId": "..." }`
  — returns a session token, farmer name, and naira balance. Errors distinguish
  `invalid_code`, `expired_code`, and `already_used`.
- `GET /api/farmer/account` with `Authorization: Bearer <session-token>` —
  returns the linked farmer's balance and support/payment history.
- `POST /api/farmers` and `GET /api/farmers/by-device/{device_id}` — legacy
  device-profile compatibility endpoints; the invite-based app does not use
  them.
- `GET /api/farmers/by-device/{device_id}` — what the Flutter app calls at
  startup (404 = not registered yet)
- `GET /api/farmers/{id}/vouchers` — the farmer's voucher list (used by the app)
- `GET /api/vouchers` / `POST /api/vouchers` `{ "farmerId": "F-1042", "purpose": "Maize seed", "amount": 50000, "kind": "Grant" }`
  — `kind` is `"Grant"` (default, never repayable) or `"Loan"` (counts as owed
  money in the dashboard loan-balance metrics)
- `POST /api/vouchers/{id}/repayments` `{ "requestId": "…", "amountNgn": 10000, "repaymentType": "Grain", "note": "20 kg maize" }`
  — records a `Grain`, `Cash`, or `Transfer` repayment against a loan voucher.
  The API rejects grants and amounts above the outstanding debt. `requestId`
  makes an exact retry idempotent; reusing it for different repayment details
  returns a conflict. Loan debt is the issued amount less recorded repayments,
  separate from the voucher's remaining dealer-spend balance.
- `GET /api/payments` / `GET /api/payments/{id}` (poll while `state = "Pending"`)
- `POST /api/payments/request` `{ "voucherId": "...", "invoice": "lntbs…", "idempotencyKey": "optional" }`
  - Parses the BOLT11 invoice, refuses zero-amount or msat-remainder invoices
  - Refuses payee node IDs that are not whitelisted (_dealers with `whitelisted = 1`_)
  - Refuses invoices whose sats × 5 NGN exceed the voucher's `remainingNgn`
  - Idempotent on the invoice payment hash or the client `idempotencyKey`
  - Inserted rows start `Pending`; settlement by the funder node flips the row
    to `Settled` (with preimage) and debits the voucher by sats × rate
- `GET /api/dealers/demo` — provisions the two named demo dealers on the shared
  dealer node and returns their current page keys for the vendor picker
- `GET /api/dealers/invoices` — admin view of vendor invoice amounts and statuses
- `POST /api/dealers/whitelist` `{ "nodeId": "03…", "name?": "...", "active?": false }`
  — 66-hex-compressed-pubkey validation; activating a dealer creates a random vendor key
  returned once; the database stores only its SHA-256 hash
- `POST /api/dealers/{nodeId}/key/regenerate` — rotates the dealer key and invalidates the old vendor link
- `POST /api/dealers/demo/{slug}/key/regenerate` — rotates one demo vendor key
- `POST /api/dealers/verify` — validates the `X-Dealer-Key` header
- `POST /api/dealers/invoices` `{ "amountNgn": 5000 }` — with `X-Dealer-Key`, creates a
  tracked BOLT11 invoice on the registered demo dealer node (₦5–₦500,000, in ₦5 increments)
- `GET /api/dealers/invoices/{id}` — with `X-Dealer-Key`, returns `Pending`, `Received`,
  or `Expired`; the invoice expires after one hour
- `POST /api/demo/reset`

Set `SATSFARM_API_ADDR` to change the bind address, `SATSFARM_DB_PATH` for the
SQLite file, `SATSFARM_LN_FUNDER_DIR` / `SATSFARM_LN_DEALER_DIR` for node
storage. For a phone on the same Wi-Fi, bind to `0.0.0.0:8787`; the client must
use the computer's LAN address. Dashboard/admin operations have no authentication
and CORS is permissive; the vendor page requires its dealer key, and the farmer
account endpoint requires its bearer session token. Dealer keys are demo
credentials, not a substitute for production authentication. Keep this demo on a
trusted development network.

## Important operational notes

- **Never run `harness/target/debug/ln_harness` while this API is running.**
  The `data/ln` node state was copied from the harness runs and shares node ID
  identities and ports 9735/9736 — a second instance of the same node will
  conflict.
- The Lightning storage keeps the channel opened during the harness proof
  (40,000 sats channel, funder → dealer) plus ~59,800 spendable on-chain sats
  from the Mutinynet faucet.
- First wallet sync can take a while (Mutinynet Esplora throttles with HTTP
  429 back-off); the vendored patch raises the BDK sync timeout to 120s.
- Payment policy (whitelist + voucher naira balance) is enforced server-side.
  The dashboard only disables the button, never decides.

Repayments are recorded by a local program operator/field partner in the
existing web dashboard; this is a demo entry, not verification of produce
delivery. The farmer app only displays loan debt and repayment history.

## Not implemented yet

No authentication/roles, locked-coin accounting, live FX, refund flows, or
on-chain payments from the API. Seed payment rows
(marked `SEED` in the UI) are fixtures; only rows created via
`POST /api/payments/request` are real Mutinynet test payments.
