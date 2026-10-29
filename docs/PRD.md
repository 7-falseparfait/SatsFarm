# SatsFarm Hackathon Product Requirements Document

*Revised October 18, 2026 · Owner: @Osuji*

This PRD describes the hackathon build only. It is a planning document; the requirements below do not claim that the product is implemented or production-ready. All payment demonstrations use Mutinynet, whose coins have no monetary value.

## Product summary

SatsFarm lets an NGO issue a naira-valued input voucher to a farmer, lets the farmer approve payment to a registered agro-dealer over Lightning, and gives both sides a shared record of payments and repayments. For the chosen pilot architecture, the NGO's LDK node pays the dealer after farmer approval. The farmer does not hold voucher funds, and the NGO node and dealer node are the only parties that need a Lightning channel for voucher spending.

The product has two interfaces:

- **Farmer Android app:** voucher value and amount owed in naira, repayment history, dealer payment approval, Hausa and English, plus an advanced self-custodial wallet.
- **NGO web page:** issue vouchers, see payments, and record repayments. A local field partner can use this same web page; no separate agent app is in the hackathon scope.

## Problem and users

NGOs in Nigeria provide agricultural inputs on credit and collect repayment after harvest. Money and goods can pass through many hands without a shared, timely record of what was issued, spent, and repaid. SatsFarm tests whether a naira-denominated voucher and a verifiable Lightning payment record can make that flow easier to track.

| User | Need |
| --- | --- |
| Farmer | See voucher value, amount owed, and repayment history in naira; pay a registered dealer; use Hausa or English. |
| NGO officer | Issue vouchers, see who received value and when, and review payments and balances owed. |
| Field partner | Receive or assess produce and record the agreed naira repayment value and optional note in the NGO web page. |
| Agro-dealer | Present a Lightning invoice as a QR code and receive payment. |

## Hackathon goals

- Demonstrate a working voucher → dealer payment → repayment flow on a Pixel 7a and an NGO web page.
- Explain why the pilot uses Bitcoin and Lightning: direct digital settlement to a registered dealer and a shared payment record that both sides can check.
- Make the farmer experience Hausa-capable and naira-first.
- Keep Send and Receive available as proof of the self-custodial wallet, under an advanced **My wallet** area.

## Non-goals

The hackathon build does not include Esusu, Season Goals, joint-liability cells, buyer-paid repayment, weather insurance, Taproot Assets, a multisignature treasury, batch disbursement, or mainnet payments. These may appear on a roadmap slide only when clearly labeled as not built.

## Guiding product decisions

1. **Naira first.** Vouchers and amounts owed are denominated in naira. Convert to sats at payment time and record the rate used, so the farmer's debt does not move with BTC prices.
2. **The pilot voucher is an NGO-side ledger entry.** It is not sats held in the farmer's wallet. After the farmer approves, the NGO node pays the dealer.
3. **Registered dealers only.** The NGO service checks the dealer node ID against its whitelist before authorizing payment.
4. **A phone cannot enforce repayment.** A non-custodial client is a convenience, not an enforcement mechanism. Buyer-paid repayment is a later option and is out of this hackathon scope.
5. **Inputs, grants, loans, and savings remain distinct.** The pilot voucher is for registered agro-dealers; grant, loan, and personal savings records and language must not be conflated.
6. **Payment evidence is not impact evidence.** A settled payment proves a network payment, not that inputs were used or a harvest achieved.
7. **Mainnet is a separate approval.** The hackathon uses Mutinynet only and must show a visible test-network label.

## Demo flow

1. An NGO officer creates a voucher for a farmer, for example ₦50,000 of inputs.
2. The farmer app displays the voucher balance and amount owed in naira, with sats as secondary information, and offers a Hausa/English toggle.
3. The farmer chooses **Pay dealer** and scans the dealer's QR invoice.
4. The farmer reviews and approves. The NGO LDK node pays only if the dealer node ID is whitelisted.
5. Once settled, the farmer app and NGO page show the payment and updated voucher balance.
6. A local field partner receives and values produce, then records a full or partial repayment in the NGO web page. The farmer sees the updated amount owed and repayment history in the app. This record does not independently verify physical delivery.
7. The farmer can open **My wallet** to demonstrate Send and Receive as advanced wallet functions.

## Functional requirements

| ID | Requirement | Priority | Component |
| --- | --- | --- | --- |
| F1 | NGO officer can create a voucher for a farmer with a naira amount. | Must | NGO service and web page |
| F2 | Farmer sees voucher balance and amount owed in naira first, sats second. | Must | Flutter app |
| F3 | Farmer can scan a dealer invoice and explicitly approve a payment. | Must | Flutter app, LDK |
| F4 | NGO node pays only dealer node IDs on the whitelist; unlisted IDs are refused. | Must | NGO service, LDK |
| F5 | NGO page shows payments and balances owed with prompt updates. | Must | NGO service and web page |
| F6 | A repayment recorded by the NGO operator updates amount owed and history in the app and web page; the farmer app has no repayment action. | Must | NGO web page/service, Flutter app |
| F7 | English/Hausa toggle works across all demo screens. | Must | Flutter app |
| F8 | Sat amounts are converted to naira using a live rate at payment time; the rate used is stored with the payment. | Must | Flutter app, NGO service |
| F9 | Send and Receive remain available under an advanced **My wallet** section. | Should | Flutter app, BDK, LDK |
| F10 | NGO treasury can be funded on-chain and used to fund the NGO node. | Should | BDK, NGO node |
| F11 | Payment states include pending, settled, and failed; never show success before settlement. | Must | Flutter app, NGO service |

## Architecture

### Chosen pilot architecture: NGO-side voucher and payment

The voucher balance and repayment ledger live in the NGO service. The farmer app requests a payment and displays the status; the NGO LDK node submits the Lightning payment to a whitelisted dealer. Only the NGO and dealer nodes require a channel for this voucher path. The NGO service owns authorization, payment idempotency, and reconciliation.

### Fallback architecture: sats sent to the farmer

If NGO-side payment cannot be made to work for the demo, the NGO can send sats to the farmer wallet and the app can permit payments only to whitelisted dealer node IDs. This reuses wallet sending code, but the whitelist rule lives on the client and can be bypassed. Treat this explicitly as a fallback with weaker enforcement, not an equivalent implementation of the chosen design.

### Components

| Component | Responsibility |
| --- | --- |
| Flutter farmer app | Voucher and debt display, repayment history, language, invoice scan, payment approval, advanced wallet. |
| NGO service | Voucher and repayment ledger, dealer whitelist, API for the app and web page, drives the NGO node, reconciles payment outcomes. |
| NGO LDK node | Lightning connectivity and payments to approved dealer nodes. |
| Dealer node or second phone | Produces the invoice and receives payment. |
| BDK | NGO on-chain treasury where available, farmer on-chain receive address, and recovery phrase wallet functions. |

The Flutter `bdk_flutter` and `ldk_node` plugins do not support Linux. The NGO node therefore needs a supported runtime, such as another Android device or a suitable server/runtime. Confirm the LDK Node bindings and operating requirements before committing to the deployment design.

## Data model

| Entity | Initial fields |
| --- | --- |
| Farmer | `id`, `name`, `phone`, `language`, `node_or_wallet_reference` |
| Dealer | `id`, `name`, `node_id`, `whitelisted` |
| Voucher | `id`, `farmer_id`, `naira_amount`, `naira_remaining`, `status` |
| Payment | `id`, `voucher_id`, `dealer_id`, `naira_amount`, `sats_amount`, `invoice`, `state`, `timestamp`, `rate_used` |
| Repayment | `id`, `voucher_id`, `naira_amount`, `type`, `note`, `request_id`, `timestamp` |

Voucher balances and debt are stored in naira. Dealer payments record their sats conversion rate; operator-entered repayments record their naira value, type, and optional note.

## NGO service interface

Names may change, but the app and web page need operations to:

- Create a voucher.
- List vouchers and remaining/owed balances.
- List payments.
- Register or update a dealer node ID whitelist entry.
- Request a dealer payment against a voucher.
- Record a repayment.

Every state-changing operation must be idempotent. Retrying a request must not create a duplicate repayment or pay a dealer twice.

## Non-functional requirements

- Mutinynet only. Show a visible test-network label and do not expose a mainnet path in the demo.
- Naira is primary on every farmer screen; sats are secondary.
- Use large touch targets, short labels, icons paired with text, and Hausa strings that fit.
- Show offline and syncing states. Explain network requirements before the user approves a payment.
- A payment remains pending until settlement is confirmed. Show failures plainly and reconcile interrupted requests without duplicate payments.
- Do not log recovery phrases, private keys, or other wallet secrets. Keep OS-backed secure storage and the recovery phrase confirmation flow.

## Build order

1. Confirm the app launches on the Pixel 7a, `ldk_node` starts, and the node connects to Mutinynet.
2. Stand up the NGO node and service, then open/verify a channel to the dealer node.
3. Build the voucher model and minimal NGO page: create vouchers, list payments, show balances owed.
4. Build the farmer home and **Pay dealer** flow end to end.
5. Add repayment and prompt updates on both sides.
6. Complete Hausa/English toggle coverage and naira-first displays.
7. Move Send and Receive under **My wallet**.
8. Fund and rehearse the demo setup, record a backup video, and practice the exact flow.

## Acceptance criteria

- A voucher created on the NGO page appears in the farmer app in naira within seconds.
- A payment to a whitelisted dealer settles on Mutinynet and appears on the NGO page.
- A payment to a non-whitelisted dealer node ID is refused.
- A repayment lowers the amount owed in both the farmer app and NGO page.
- The complete demo flow runs on the Pixel 7a without an app restart or manual database intervention.
- Every payment remains pending until settled; failures are shown plainly.

## Risks and fallbacks

| Risk | Response |
| --- | --- |
| `ldk_node 0.3.0` cannot open channels or send payments as required. | Check early. Consider a newer version only after estimating API changes and build/data cost. |
| NGO node cannot run on available hardware. | Use a second Android device or a suitable cloud server. |
| Lightning is unreliable on demo day. | Play a recorded video and show the NGO page and app screens. |
| Wi-Fi fails during the demo. | Pre-record the flow and prepare a second network. |
| Judges ask why not mobile money. | Explain the hypothesis being tested: direct donor-to-farmer program payments with fewer intermediaries and a shared record. Validate this with NGO partners; do not claim measured impact before the pilot. |

## Development environment constraints

- Manjaro Linux host; Android SDK at `/opt/android-sdk`; JDK 21 selected for Flutter and the system.
- NDK 28.2.13676358, CMake 3.22.1, and Android platforms 31, 33, and 35 are installed. Do not trigger additional SDK downloads without checking first.
- Keep the compile SDK 35 and namespace compatibility block in `android/build.gradle.kts`.
- Keep `ldk_node 0.3.0` and `bdk_flutter` versions fixed for the hackathon unless an explicit decision is made to change them. Do not run `flutter clean` or `flutter pub cache repair`; caches are expensive to rebuild on the current data plan.
- Use wireless debugging for the Pixel 7a. Prefer `/opt/android-sdk/platform-tools/adb` because the system `adb` may be broken.
- The real BDK/LDK wallet path can only be validated on Android, not Linux.

## Open decisions

- Validate that the NGO-side voucher architecture fits the chosen NGO's operational and governance model.
- Confirm the hosted/runtime environment for the NGO node and service.
- Confirm how liquidity and fees are provided for the NGO-to-dealer payment path.
- Confirm available live naira/sat rate source, update policy, and behavior when the rate service is unavailable.
- Validate the legal and regulatory position before any real-money lending or payment activity.
- Confirm the user-facing explanation of the distinction between NGO-managed voucher funds and a farmer-owned self-custodial wallet.
