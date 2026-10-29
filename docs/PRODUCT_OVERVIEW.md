# SatsFarm: controlled farm-support payments

SatsFarm is a prototype for moving agricultural support through a more
traceable, purpose-limited payment path. A program officer records support for
a farmer; the farmer sees the amount and chooses when to approve payment to a
registered agro-dealer; the program's Lightning node pays the dealer and the
ledger records the outcome.

The idea is to make it harder for program funds to become an untracked cash
transfer. It is not a guarantee against fraud, coercion, collusion, bad inputs,
or misuse after a dealer is paid. It is a practical control and accountability
layer that should be tested with farmers and dealers, and strengthened before
handling real funds.

> **Demo boundary:** all Bitcoin and Lightning activity described here uses
> Mutinynet, a Bitcoin test network. Test coins have no monetary value. The
> naira-to-sats conversion is a fixed demo rate of **₦5 per sat**, not a live
> exchange rate. The visible test-network label must remain in the product.

## The product, by participant

### Program officer: dashboard

The dashboard is the program's operating ledger. An officer can create a farmer
record using the farmer's name, phone number, and initial support amount. The
API creates a farmer record and an initial support voucher, then returns a
single-use invite code with a QR representation. The code expires after 24
hours; an unused code can be regenerated, invalidating the old one.

The officer can issue additional grant or loan vouchers and review farmer
records, voucher balances, dealer activity, and payment states. The overview
shows outstanding grant and loan amounts in naira and their approximate sats
equivalents at the demo rate. It also shows the funder node's usable Lightning
outbound capacity and its approximate naira value.

For a loan voucher, the dashboard can record a repayment as grain, cash, or
transfer, with an optional note. A local field partner can receive and value
produce, then enter that reported value in the same web dashboard; no separate
agent app is needed for the demo. This creates a ledger record, not independent
proof that produce was delivered. The farmer app displays the outstanding loan
and repayment history but does not offer a repayment action.

These are different measures:

- **Voucher outstanding** is the remaining value recorded in the program
  ledger.
- **Funder Lightning available** is currently usable outbound channel
  capacity. It is not the same as all funds owned by the program; it excludes
  on-chain funds and does not guarantee every payment will succeed.
- The dashboard can generate a separate on-chain receive address for the API
  funder node to request Mutinynet test funds. On-chain funds do not
  automatically become Lightning channel capacity.

### Farmer: app

Before a farmer is linked, the app offers invite-code entry or QR scanning. On
successful redemption, the app stores the session token in OS-backed secure
storage and loads the farmer's name, naira balance, history, and individual
vouchers. The farmer can switch between English and Hausa.

To pay a dealer, the farmer opens an active voucher, scans the dealer's
Lightning invoice QR (or enters the invoice), then chooses **Pay dealer**. The
scan only reads the invoice; it does not itself approve or send a payment.
Voucher payment is requested from the SatsFarm API, not from the farmer's
personal Lightning wallet.

Loan vouchers show the remaining amount owed and recorded repayments. Repayment
entry is performed by the program operator or local field partner in the
dashboard, not by the farmer in the app.

The app also has a separate **My wallet** experience for wallet functions such
as Send and Receive. That wallet is distinct from the program voucher balance.

### Dealer: standalone payment page

The dealer uses the separate `/dealer` page, not the program dashboard. After
dealer access is verified with its dealer key, the dealer enters a naira sale
amount. The API converts it at the fixed demo rate, creates an amount-bearing
BOLT11 invoice on the dealer Lightning node, and returns a QR code for that
invoice. The page waits for the invoice state to update and shows when payment
is received.

The dealer page is a payment-request interface; it does not choose the farmer's
voucher or initiate the funder payment. The farmer approves that step in the
app.

## End-to-end payment settlement

For voucher payments, two LDK nodes run in the Rust API process:

1. **Dealer creates an invoice.** The dealer page asks the API for an invoice
   for the sale. The dealer node creates a BOLT11 invoice and the API stores its
   amount, payment hash, expiry, and pending state.
2. **Farmer scans and approves.** The Flutter app reads the invoice QR and
   sends the invoice and selected voucher ID to the API after the farmer taps
   the payment button.
3. **API validates the request.** It parses the invoice, requires an amount in
   whole sats, converts the sats to naira at the fixed demo rate, checks that
   the selected voucher has enough remaining value, and checks that the
   invoice's payee node ID is on the dealer whitelist. Duplicate invoice
   requests are handled idempotently.
4. **Funder node sends the payment.** The API's funder LDK node sends the
   Lightning payment to the dealer invoice. The farmer's own wallet node is not
   involved in this voucher payment.
5. **Both sides record settlement.** The API initially records a pending
   payment. When the funder node reports settlement, the API marks the payment
   settled and deducts its naira-equivalent cost from the voucher. When the
   dealer node reports receipt, the dealer invoice moves to received. The
   farmer app and dashboard can then refresh their records.
6. **Failure is not success.** A payment that fails is recorded as failed; the
   voucher deduction is performed on settlement, not merely when a request is
   submitted. Pending payments are not confirmations.

Lightning settlement is between the funder and dealer nodes over their
Mutinynet channel. The API coordinates the request and ledger updates. A
successful Lightning payment proves that the invoice was paid; it does not
prove that the dealer supplied the correct goods or that those goods reached
the intended farm.

## Why this may help protect farmer support

Traditional cash disbursement can be difficult to reconcile once funds pass
through multiple people. SatsFarm explores a different control point: record
support as a voucher, require an explicit farmer action for a purchase, and
route the resulting payment to a registered dealer rather than sending the
voucher amount to the farmer as unrestricted wallet funds.

That structure can help with:

- **Purpose limitation:** the demo flow is designed around paying registered
  agro-dealers, rather than withdrawing the voucher as cash.
- **Farmer visibility and choice:** the app shows voucher balances and asks for
  an approval action before requesting payment.
- **Traceability:** a payment record connects the voucher, naira amount, sats
  amount, dealer, payment state, and rate used.
- **Reconciliation:** the dashboard gives program staff a shared view of
  issued support, remaining voucher value, and settlement status.
- **Faster discrepancy checks:** individual voucher records help explain why a
  farmer's total balance is the sum of several active allocations.

These controls reduce some opportunities for diversion, but they do not
eliminate fraud. A dealer may collude with an operator or farmer, a farmer may
be pressured to approve a transaction, credentials may be shared, and a valid
payment does not verify the physical delivery or quality of inputs. Independent
receipts, delivery confirmation, farmer feedback, spot checks, separation of
duties, and a clear complaint process remain important.

## LDK in the farmer app: do we still need it?

**Not for the voucher-to-dealer payment path.** That path uses the funder and
dealer LDK nodes hosted by the Rust API. The farmer app scans an invoice and
calls the API; it does not need to hold Lightning funds or run an LDK node to
approve a voucher payment.

**The current app still uses LDK for its separate My wallet functionality.**
The Flutter `LdkService` backs wallet operations such as creating a Lightning
invoice and reading the wallet's Lightning balance. Removing the mobile
`ldk_node` dependency would therefore remove or break those wallet features
unless they are intentionally redesigned or removed. Keeping it does not mean
voucher payments route through the farmer's wallet.

## What this demo does not yet guarantee

This is a working test-network prototype, not a production disbursement or
anti-fraud system. In particular:

- Dashboard/admin endpoints are not authenticated, and the API uses permissive
  CORS. Keep it on a trusted development network.
- Dealer page access uses a demo dealer key. Treat dealer keys as demo
  credentials, not production identity or authorization.
- Farmer account reads use a session token, but the current voucher-payment
  request is not bound to that farmer session. The voucher ID and dealer
  whitelist checks are not a complete production authorization system.
- The current payment flow checks the remaining voucher balance before
  submission but does not reserve balance for a pending payment. Concurrent
  payment attempts need atomic holds/reservations before real deployment.
- The ₦5-per-sat rate is fixed demo configuration, not market pricing.
- Payment settlement records do not verify physical goods, delivery, price
  fairness, or farmer consent beyond the app's approval action.
- Mutinynet coins are valueless test assets; no mainnet funds should be used.

Before a real pilot, add authenticated and role-scoped dashboard access,
session-bound payment authorization, atomic voucher balance reservations,
audited operator actions, secure key management, operational monitoring,
dispute/refund procedures, and a reviewed pricing and custody model. Test these
controls with the intended communities and obtain appropriate legal and
financial guidance.

## Main implementation areas

- Flutter farmer and wallet app: [lib/](../lib/)
- Rust API, SQLite program ledger, and API-hosted Lightning nodes: [ngo-api/](../ngo-api/)
- Program dashboard and dealer page: [ngo-web/](../ngo-web/)
- API setup and local demo instructions: [ngo-api/README.md](../ngo-api/README.md)
