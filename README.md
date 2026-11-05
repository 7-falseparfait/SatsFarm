# SatsFarm

SatsFarm is a prototype for making agricultural support to smallholder farmers
more traceable. A program operator issues naira-denominated grant or loan
vouchers; a farmer can use an active voucher to approve payment to a registered
agro-dealer; and a program operator or local field partner can record loan
repayments.

The project has three parts:

- **Farmer app** — Flutter Android app for joining with an invite, viewing
  vouchers and loan history, and approving dealer payments. The separate
  self-custodial wallet experience is not the source of voucher funds.
- **Program Desk** — React dashboard for managing farmers, vouchers, repayments,
  dealers, and program-node funding.
- **Rust API** — Axum service and SQLite demo ledger. It also runs the funder
  and dealer Lightning nodes used by the payment demo.

This is a hackathon/demo prototype, not a production financial service. The
dashboard and API are not fully authenticated; run them only on your own
computer or a trusted private network.

## What works in the demo

- Create a farmer and issue a single-use invite code/QR from the dashboard.
- Link the farmer app using the code or QR. The app supports English and Hausa
  and has a visible option to switch farmer accounts.
- Create grant and loan vouchers. Loan vouchers show the amount owed in the app.
- Record a loan repayment from the dashboard as grain, cash, or transfer, with
  an optional note. Repayments update the balance and appear in the farmer's
  history. Grants cannot be repaid, and repayments larger than the amount owed
  are rejected.
- Create a dealer invoice, then review its dealer and naira amount and approve
  it in the farmer app. Only the signed-in farmer who owns the voucher can
  approve. The API also checks the available balance and registered dealer.
- Fund the API's funder node from the dashboard and open its channel to the
  dealer node.

The demo exchange rate is fixed at **₦5 per sat**. USSD access, offline use,
independent verification of produce delivery, and production authentication
have not been implemented.

## Requirements

Install the following tools and make sure they are available on your `PATH`:

- [Flutter](https://docs.flutter.dev/get-started/install) with a Dart SDK
  compatible with `pubspec.yaml`.
- [Rust and Cargo](https://www.rust-lang.org/tools/install) (Rust 1.85 or newer
  for the Rust 2024 edition).
- [Node.js and npm](https://nodejs.org/) compatible with the Vite version in
  `ngo-web/package.json`.
- For Android testing: Android SDK/platform tools, an emulator or Android
  phone, and USB debugging enabled for a physical device.

Check the tool installations:

```sh
flutter --version
rustc --version
cargo --version
node --version
npm --version
```

## Start the demo locally

Run each component in a separate terminal from the repository root.

### 1. Start the API

```sh
cd ngo-api
cargo run
```

The API listens at `http://127.0.0.1:8787` by default. On its first start, it
creates `ngo-api/data/satsfarm.sqlite`, seeds fictional demo records, and starts
the funder and dealer LDK nodes. Check that the API is responding:

```sh
curl http://127.0.0.1:8787/api/health
curl http://127.0.0.1:8787/api/ln/status
```

The Lightning nodes can take time to sync; the status endpoint reports when
they are ready. Keep the API running while using the dashboard or farmer app.

Node storage is not in the repository, so a fresh checkout starts with new,
unfunded nodes and **cannot pay anyone yet**. See
[Fund the demo once](#fund-the-demo-once) after starting the dashboard.

### 2. Start the Program Desk

In another terminal:

```sh
cd ngo-web
npm install
npm run dev
```

Open the local address printed by Vite (normally
`http://localhost:5173`). The dealer page is at `/dealer`; the dashboard also
links to the demo dealer pages.

### Fund the demo once

If you have a backup of `ngo-api/data/`, restore it instead (with the API
stopped). Otherwise, on the dashboard's Overview page:

1. Under **Fund the program node**, choose **Get receive address**.
2. Send about 70,000 Mutinynet sats to it from the
   [faucet](https://faucet.mutinynet.com/). This covers the 40,000-sat channel,
   a 25,000-sat reserve, and fees.
3. When the spendable amount on that panel has updated, choose
   **Open dealer channel**.
4. Wait until the button says **Dealer channel open**. Mutinynet blocks are
   quick, but this can take a few minutes.

The channel pays one way, so it covers about ₦200,000 in total at the demo rate.
Use small amounts such as ₦5,000 when rehearsing. Check capacity at any time
with `GET /api/ln/status`.

### 3. Run the farmer app

From the repository root, install Flutter packages:

```sh
flutter pub get
flutter devices
```

For an Android emulator or a phone connected by USB, forward the API port with
ADB so the device's `127.0.0.1` reaches your computer (replace `<device-id>`
with the ID shown by `adb devices`):

```sh
adb -s <device-id> reverse tcp:8787 tcp:8787
flutter run -d <device-id> \
  --dart-define=SATS_FARM_API_URL=http://127.0.0.1:8787
```

Alternatively, put the phone and computer on the same trusted Wi-Fi network.
Find the computer's LAN IP, bind the API to all interfaces, and use that LAN IP
in the app:

```sh
cd ngo-api
SATSFARM_API_ADDR=0.0.0.0:8787 cargo run
```

Then, from the repository root:

```sh
flutter run -d <android-device> \
  --dart-define=SATS_FARM_API_URL=http://<computer-lan-ip>:8787
```

If you also want to open the dashboard on the phone, serve Vite on the LAN and
point it at the API:

```sh
cd ngo-web
VITE_API_URL=http://<computer-lan-ip>:8787 npm run dev -- --host 0.0.0.0
```

Android debug builds allow cleartext HTTP for this local demo. Do not expose the
API or dashboard to the public internet.

## Suggested demo walkthrough

1. Start the API and wait for `GET /api/ln/status` to report ready.
2. Start the dashboard and open its Farmers page.
3. Create a demo farmer and show the invite QR/code.
4. Open the farmer app, redeem the invite, and view the farmer's vouchers.
5. In the dealer page, create an invoice for a sale.
6. In the farmer app, choose **Redeem at dealer** on an active voucher, scan the
   invoice, check the dealer and amount, and choose **Pay dealer**. The app and
   dashboard then show the payment state. An invoice can only be used once, so
   create a new one for each attempt.
7. Create a loan voucher if needed, record a repayment from the dashboard, and
   refresh the farmer's loan history to show the updated amount owed.

Dashboard **Reset demo data** restores the seeded demo ledger records and ends
farmer sessions, so the app returns to the join screen on its next refresh. It
does not mean you should delete the API's Lightning node data: node storage can
contain wallet and channel state.

## Configuration and local data

The API accepts these optional environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SATSFARM_API_ADDR` | `127.0.0.1:8787` | API listen address |
| `SATSFARM_DB_PATH` | `data/satsfarm.sqlite` (relative to `ngo-api`) | SQLite ledger file |
| `SATSFARM_LN_FUNDER_DIR` | `data/ln/funder` (relative to `ngo-api`) | Funder node storage |
| `SATSFARM_LN_DEALER_DIR` | `data/ln/dealer` (relative to `ngo-api`) | Dealer node storage |
| `VITE_API_URL` | `http://127.0.0.1:8787` | API URL used by the web app |
| `SATS_FARM_API_URL` | app default | API URL supplied to Flutter at run/build time |

Keep the API database and Lightning node directories private. Do not publish
their contents, recovery material, or credentials.

## Network and safety notes

- All Bitcoin and Lightning activity is on **Mutinynet**, a custom Signet
  development network. Mutinynet coins have no monetary value. Never send
  mainnet Bitcoin to an address from this demo.
- [Mutinynet explorer](https://mutinynet.com/), [faucet](https://faucet.mutinynet.com/),
  and [Lightning gossip snapshot](https://rgs.mutinynet.com/snapshot/0).
- On-chain funds sent to the funder node become Lightning capacity only after
  you open the dealer channel.
- The naira-to-sats conversion is a fixed demo rate, not a live exchange rate.
- The API dashboard/admin routes have no authentication and CORS is permissive.
  Keep the service on localhost or a trusted development network.
- The API's `ngo-api/data/` directory contains persistent SQLite and Lightning
  node data. Back it up carefully; do not share or casually delete it.
- Do not run `harness/target/debug/ln_harness` while the API is running. It
  shares node identities and ports with the API's Lightning nodes.
- The Linux Flutter build does not currently provide native wallet sync or
  Lightning wallet payment support. Use Android for the wallet/payment demo.

## Validation

Run the relevant checks from the repository root:

```sh
cargo test --manifest-path ngo-api/Cargo.toml
npm run build --prefix ngo-web
flutter analyze
flutter test
```

## Project documentation

- [Product overview](docs/PRODUCT_OVERVIEW.md) — roles, payment flow, and
  current limitations.
- [Product requirements](docs/PRD.md) — pilot requirements and acceptance
  criteria.
- [Project milestones](docs/PROJECT_MILESTONES.md) — completed work and
  roadmap.
- [Design direction](docs/DESIGN_DIRECTION.md) — visual and interaction
  guidance.
- [API documentation](ngo-api/README.md) — endpoint reference and operational
  details.
- [Program Desk documentation](ngo-web/README.md) — dashboard and dealer-page
  details.
