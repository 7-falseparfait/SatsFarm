# SatsFarm Program Desk prototype

This Vite + React + TypeScript app is a separate web prototype for the NGO and
cooperative workflows described in the [SatsFarm PRD](../docs/PRD.md).

## Run locally

```sh
npm install
npm run dev
```

Open the local URL printed by Vite. The Farmers page creates a farmer record
from only a name, phone number, and support amount; it renders invite QR codes
locally in the browser so codes are not sent to a QR service. Start the Rust API
on `0.0.0.0:8787` when connecting an Android phone over Wi-Fi. The Flutter app
is run from the repository root with its API URL configured at build/run time:

```sh
flutter run -d <android-device> \
  --dart-define=SATS_FARM_API_URL=http://<pc-lan-ip>:8787
```

The app scans the dashboard QR or accepts the code by typing. Debug Android
builds permit cleartext HTTP for this trusted-LAN demo only.

For a phone on the same Wi-Fi, serve the web app on the LAN and point it at the
API's LAN address:

```sh
VITE_API_URL=http://<pc-lan-ip>:8787 npm run dev -- --host 0.0.0.0
```

## Vendor page

Open `/dealer` for the separate, phone-sized vendor payment page. It offers two
built-in demo shops, both connected to the shared demo dealer node. The admin
dashboard's **Dealers** section also links directly to each shop's vendor page.
Each shop receives a random key from the API; the database stores its hash and
the admin can regenerate the key to invalidate its previous link.
The vendor enters a naira amount, displays the invoice QR, and sees confirmation
when the funder pays the invoice. The demo has one shared dealer node; it does
not issue invoices from vendor-owned nodes.

## Prototype boundary

Run the Rust API in `../ngo-api` as described in its README. The page then reads
and creates farmer invite and voucher ledger records through that local API.
Example farmers, dealers, and payment states are seeded demo data. The admin
prototype has no login, and the dealer key is only a demo access control. A
voucher created here is not funded until an invoice is paid. Do not use the
sample people, amounts, statuses, or dealer records as real program data.
