# SatsFarm Project Milestones (Hackathon PRD aligned)

*Revised October 18, 2026. This is a planning handoff. Milestone descriptions do not claim that features are implemented or production-ready.*

The detailed hackathon requirements live in [PRD](PRD.md). This roadmap includes both that MVP and later product phases.

## How this revision aligns with the hackathon PRD

The hackathon MVP is the NGO-side voucher → registered dealer payment → repayment flow. It is Mutinynet-only and naira-first. The farmer wallet remains available as an advanced **My wallet** feature; it is not the source of voucher funds in the chosen pilot design.

- The NGO page and service move into the first MVP slice.
- The NGO LDK node pays the dealer only after farmer approval and only when the dealer node ID is allowlisted.
- Vouchers and balances owed are recorded in naira; the sats amount and conversion rate used are recorded for each network payment.
- Season Goals, Esusu, treasury multisig, batch disbursement, and mainnet stay on the later roadmap.
- The Linux wallet limitation and Android build/cache caveats are recorded as current implementation risks.

## Product vision

SatsFarm helps NGOs reach smallholder farmers in Northern Nigeria with inputs and credit, and gives the farmer, NGO, and agro-dealer a shared record of voucher payments and repayments. The hackathon has two interfaces that share a brand and program data model:

- Farmer mobile app (Android, Flutter): voucher balance and amount owed in naira, repayment history, dealer payment approval, Hausa localization, and an advanced self-custodial wallet.
- Minimal NGO web page for the hackathon: create vouchers, view payments, record repayments, and see each farmer's amount owed. A local field partner can use this page; no separate agent app is planned.
See [Design Direction](DESIGN_DIRECTION.md) for the visual brief.

## Guiding decisions

1. Naira first. Every amount a farmer sees is in naira. Vouchers and loans are denominated in naira and converted to sats at the moment of payment, so farmers are not exposed to BTC volatility on what they owe.
2. The wallet cannot enforce repayment. A non-custodial app runs on the farmer's own phone, so code there is a convenience, not enforcement. Where repayment must be reliable, the registered buyer (off-taker) pays the NGO's share directly and the farmer receives the rest.
3. Inputs, not cash. Vouchers are spendable only at registered agro-dealers, so program money cannot be diverted.
4. Payment evidence is not impact evidence. A settled payment does not prove inputs were used or a harvest achieved.
5. Grants, loans, and savings stay separate in the product, in the data model, and in the language shown to farmers.
6. The pilot uses an NGO-side voucher ledger: the farmer approves a dealer payment and the NGO node pays the dealer. The self-custodial wallet is the advanced layer. Confirm this operating model with the pilot NGO before any real-money use.
7. Mainnet is a separate approval. All pilot work runs on Mutinynet, whose coins have no monetary value.

## Milestone 0: Architecture and foundation (mostly complete)

### Current state

- Flutter feature-first structure, theme, English and Hausa ARB localization with a language toggle, placeholder screens, state bindings, and wallet service boundaries for BDK (on-chain) and LDK (Lightning).
- Secure storage uses OS-backed storage with a recovery-phrase confirmation gate and restore on startup. Storage failure blocks wallet setup rather than falling back to plaintext.
- The Android debug build works on the development machine (Manjaro). Required setup: JDK 21 as the default and set in Flutter, NDK 28.2.13676358, CMake 3.22.1, Android platforms 31, 33 and 35, and the Rust target aarch64-linux-android.
- A subprojects block in android/build.gradle.kts sets compileSdk 35 for plugins and supplies a namespace to any plugin missing one. This replaced the manual edit made inside the pub cache, which is fragile.
- The current debug APK includes BDK and LDK native libraries after local CargoKit compatibility edits in the Pub cache. Those edits are machine-local and are not a reproducible project fix yet; preserve them while developing and track a project-owned/vendorized solution.
- Development network is Mutinynet (a custom Signet). On supported native platforms BDK and LDK use Mutinynet Esplora, and LDK uses its Rapid Gossip Sync endpoint.
- bdk_flutter 0.31.3 and ldk_node 0.3.0 do not support Linux. Linux uses local BIP39, BIP32 and BIP84 derivation for test receive addresses only, with no chain sync, Lightning, or invoices. The real wallet can only be tested on the Android device.
- Deploying to the Pixel 7a: USB debugging dropped repeatedly, so use wireless debugging.

### Known risks

- BDK and LDK packages have incompatible freezed_annotation constraints and currently need an override.
- ldk_node 0.3.0 is old. Check which features it supports before planning around it, including channel opening and any liquidity-provider flow.
- The toolchain is very new compared with these plugins, so expect more compatibility fixes.

### Exit criteria

- Document supported platforms and the wallet capabilities available on each.
- Resolve or formally accept the package override risk.
- Confirm on the Pixel 7a that ldk_node starts, and that BDK syncs and the node connects on Mutinynet.
- Keep flutter analyze and the Android build green.

## Milestone 1: Field validation

Nothing has yet been tested against real users. Do this before building more screens.

### Scope

- Interview two or three smallholder farmers and at least one NGO field officer in the target area.
- Ask where money and inputs get stuck today, how repayment works day to day, what proof farmers and NGOs trust, and what phones, data, and agents are actually available.
- Ask the NGO why they would use this instead of a bank transfer or mobile money. Candidate answers to test: farmers without reliable bank accounts, and donors paying a farmer directly with no intermediaries.
- Confirm which language and literacy assumptions hold.
- Take Nigerian lending and microfinance regulation seriously and get legal advice before any real money moves.

### Exit criteria

- A one-page summary of findings that confirms or changes the Pilot slice.
- A named NGO or cooperative willing to pilot, or a clear reason none is yet.

## Milestone 2: Pilot slice (the MVP)

The hackathon MVP is the smallest thing that proves the idea: one NGO, one agro-dealer, about 20 farmers, one season, on Mutinynet. Its demo must work end to end on the Pixel 7a and the minimal NGO web page.

### Flow

1. The NGO officer issues a naira-valued voucher to a farmer, for example ₦50,000 of inputs.
2. The farmer sees the voucher and amount owed in naira, then scans a registered agro-dealer's Lightning invoice.
3. The farmer reviews and approves the payment. The NGO LDK node pays only when the dealer node ID is on the NGO service whitelist.
4. The NGO page records the payment, sats amount, naira amount, rate used, and settlement state; the farmer app reflects the updated voucher balance.
5. A local field partner receives and values produce, then records a full or partial repayment in the NGO page. The app and NGO page show the updated amount owed; the entry does not independently verify delivery.

### Scope

- Farmer home screen shows voucher balance and amount owed in naira first, plus clear dealer-payment actions and repayment history. Repayment entry is in the NGO page, not the farmer app.
- Farmer scans a dealer invoice and approves before the payment is submitted.
- Payment and repayment history uses plain language and distinguishes prepared, pending, settled, and failed states.
- Minimal NGO page and service: create a voucher, view payments, and see each farmer's amount owed. The NGO service owns the voucher/repayment ledger, dealer whitelist, payment authorization, and reconciliation.
- The voucher is an NGO-side record, not sats held in the farmer's wallet. The NGO node pays the dealer on approval, so this voucher flow does not require a farmer Lightning channel. The NGO node does need working connectivity and liquidity to pay the dealer.
- Record the live sat/naira conversion rate used on each payment. Vouchers and debt remain denominated in naira; operator-entered repayments record their type and optional note.
- Existing Send and Receive stay available under an advanced **My wallet** section.

### Out of scope for the pilot

Season Goals, Esusu, joint-liability cells, harvest auto-splitting enforced from the phone, weather insurance, Taproot Assets, and the multisig treasury.

### Stretch scope

- Fund the NGO treasury on-chain and use BDK to fund the NGO node, if the core voucher/payment/repayment flow is complete and stable.

### Exit criteria

- A voucher issued on the NGO page appears in the farmer app in naira within seconds.
- A payment to a whitelisted dealer settles on Mutinynet and appears on the NGO page; a non-whitelisted dealer node ID is refused.
- A repayment lowers the naira amount owed in both the farmer app and NGO page.
- The full flow runs on the Pixel 7a without restarting the app or manually editing the database.
- The NGO can reconcile vouchers, payments, and repayments against network outcomes without double counting. Retrying state-changing requests never double-pays.
- Payments never show as successful before settlement; failures are shown plainly.

## Milestone 3: Farmer wallet hardening

This is the advanced **My wallet** area in the hackathon demo. It supports the product's self-custody story but is separate from the NGO-side voucher balance and debt ledger.

### Scope

- Create and restore a wallet with a safe recovery-phrase flow and clear self-custody explanations. Be honest that losing a phone without a backup means losing the funds.
- Show on-chain and Lightning balances separately and combined, with a clearly labeled naira estimate.
- Receive addresses and Lightning invoices where the platform supports them.
- Send flows with explicit amount, fee, destination, review, and final confirmation.
- Transaction states: pending, confirmed, failed, and offline.
- Platform capability checks so unsupported actions never appear available.

### Exit criteria

- Persistence and recovery verified across app restart and restore.
- Payment flows tested on Mutinynet.
- Security review covers key lifecycle, logging, backups, and recovery.

## Milestone 4: Hausa-first, accessible farmer experience

### Scope

- Complete Hausa and English copy for onboarding, vouchers, repayment, wallet, errors, and confirmations.
- Review Hausa wording with fluent speakers from the target region.
- Support low literacy with concise text, paired icons, clear state feedback, and optional audio or illustrations.
- Validate touch targets, contrast, font scaling, and layouts with longer Hausa strings.
- Design offline and weak-network behavior with clear sync status.

### Exit criteria

- Farmer usability sessions show common tasks can be completed without a facilitator.
- Offline limitations are clear before a network-dependent payment begins.

## Milestone 5: Liquidity and channels

For the chosen voucher architecture, the pilot payment is made by the NGO node, so farmers do not need channels to spend voucher value. The NGO node must be able to pay the registered dealer. Farmer channel provisioning matters only if the team falls back to sending sats to farmers or enables direct Lightning receiving in **My wallet**.

### Scope

- Confirm that `ldk_node 0.3.0` supports the NGO node's channel and payment requirements; decide whether an upgrade is needed and affordable.
- Open and verify a Mutinynet channel with sufficient outbound liquidity from the NGO node to the dealer.
- Define fees, who pays, and how the demo behaves when the NGO node or farmer is offline.
- If the fallback architecture is used, decide how channels and inbound liquidity are provisioned to farmer wallets.

### Exit criteria

- The NGO node can settle a payment to the allowlisted dealer on Mutinynet without manual channel steps during the demo.
- Costs, liquidity, and operational responsibility are written down and agreed.

## Milestone 6: Season Goals

### Scope

- A seasonal savings goal with crop and season label, target, deadline, and contribution history.
- Progress toward seed, fertilizer, land preparation, irrigation, harvest, transport, or storage needs.
- Optional staged funding, for example 40% for land preparation and planting, 30% after mid-season verification, and 30% for harvest and storage.
- A clear distinction between a personal savings goal, donor-controlled grant conditions, and a loan.
- A farmer-readable history of contributions, releases, evidence, and remaining target.
- Fiat-value stability for savings is an open problem. Taproot Assets appears to be built around LND rather than ldk_node, so verify feasibility before committing. The simple first step is to show naira value while holding sats and say plainly that the value moves with the Bitcoin price.

### Exit criteria

- Farmers understand which funds are theirs, which are conditional, and what evidence each release needs.
- Verification and appeal or correction flows are defined before any funds are restricted by a milestone.

## Milestone 7: Cooperative Esusu

### Scope

- Create or join a cooperative savings group with membership, contribution cadence, and transparent rules.
- Each member sees their own contribution record and the group-level pot status the policy permits.
- Define payout order, missed-payment handling, dispute process, and roles.
- Repayment schedules only if a cooperative program offers loans, kept separate from grants and savings.

### Exit criteria

- Group governance and permissions agreed and reflected in the product.
- Members can inspect and challenge incorrect records.
- Privacy defaults prevent disclosure beyond group policy and each person's authorization.

## Milestone 8: Full NGO and cooperative portal

Expands the minimal NGO page from Milestone 2. This portal is roadmap scope beyond the hackathon MVP.

### Audience

NGOs, agricultural grant providers, impact investors, government stakeholders, microfinance institutions, cooperative administrators, and authorized auditors.

### Treasury and program funding

- Create a program and record funding source, budget, region, eligibility criteria, and grant or loan classification.
- Evaluate a 2-of-3 multisignature treasury or a dedicated Lightning liquidity pool. Do not assume a custody model until governance, security, legal, and liquidity reviews are complete.
- Record funding and allocation with approvals, reconciliation, and audit history.

### Disbursement

- Select eligible farmers or cohorts under approved rules.
- Preview recipients, amounts, fees, totals, and failed or duplicate recipients before a batch is submitted.
- Track each payment as prepared, approved, submitted, settled, failed, or requiring reconciliation.
- Provide idempotency and recovery for interrupted batches.

### Conditional funding and verification

- Staged plans verified by cooperative leads or extension workers with explicit scope and timestamps.
- Capture evidence without collecting more sensitive farmer data than necessary.
- Include correction, appeal, and exception paths.

### Reporting and audit

- Totals such as value allocated or disbursed, farmer count, goal completion, and repayment status, each with basis, time range, source, and freshness. Figures such as 45,000,000 naira or 1.2 BTC in mock designs are examples, not results.
- Privacy-preserving aggregates by program, region, crop, and stage, with small-group suppression.
- A tamper-evident audit trail for setup, approvals, disbursements, decisions, corrections, and repayments.
- Distinguish payment evidence from real-world impact evidence.

### Later credit mechanisms

Joint-liability cells, harvest-linked repayment through registered buyers, and parametric weather insurance are second-stage ideas. They depend on field staff, buyer contracts, and licensed partners, and should only be scoped after the pilot shows what the NGO actually needs.

### Exit criteria

- Roles and permission boundaries approved and tested.
- Batch payments reconcile against network outcomes with no double disbursement.
- Donor reporting does not reveal individual wallets or balances by default.
- Treasury custody and loan operations receive independent security, governance, and legal review.

## Milestone 9: Controlled pilot and operational readiness

### Scope

- Run a controlled test-network pilot with a small number of farmers, one agro-dealer, and cooperative or NGO staff.
- Validate onboarding, language, payment status, recovery, offline states, and the NGO workflows for issuing, reconciling, and reporting.
- Establish support procedures for lost devices, mistaken payments, failed disbursements, disputes, and key recovery.
- Define monitoring, incident response, backup, reconciliation, and release procedures.

### Exit criteria

- Pilot findings resolved or explicitly accepted by project owners.
- Threat model, privacy review, and operational runbooks complete.
- Mainnet launch is a separate approval after independent wallet and treasury review.

## Visual and interaction direction

Use the supplied farm-management and wallet images as visual references: authentic agricultural photography, forest and olive green, warm light surfaces, restrained lime accents, rounded information cards, map and field views, and readable progress visuals. Keep the farmer app calm and simple, and let the NGO portal be denser and more analytical. Do not reproduce unrelated sample branding, locations, metrics, or images. Details are in [Design Direction](DESIGN_DIRECTION.md).

## Sequencing summary

1. Finish foundation checks: app launches on Pixel 7a; BDK initializes; the NGO LDK node starts and connects to Mutinynet.
2. Validate the problem and the NGO-side voucher architecture with farmers and an NGO officer.
3. Stand up the NGO node/service and verify the dealer channel and whitelist.
4. Build the pilot slice: voucher creation, farmer approval, dealer payment, repayment, and minimal NGO page.
5. Complete Hausa/English and naira-first displays; move Send and Receive under **My wallet**.
6. Fund and rehearse the Mutinynet demo; prepare a backup video and network connection.
7. After pilot evidence, harden the wallet, then scope Season Goals and Cooperative Esusu.
8. Expand the NGO portal with treasury, disbursement, verification, and reporting.
9. Run a controlled pilot, complete security and operations review, and make a separate mainnet decision.

## Open decisions

- Confirm the NGO-side voucher flow with the pilot NGO before implementation is treated as settled for real-world use.
- Confirm whether a demo fallback that sends sats to the farmer is necessary; it has weaker whitelist enforcement than the chosen architecture.
- Validate why the NGO would choose this over bank transfer or mobile money.
- Confirm NGO node hosting, dealer channel liquidity, fees, and payment operations.
- Select a live naira/sat rate source and fallback behavior.
- Whether to upgrade ldk_node and bdk_flutter, and the cost of the API changes.
- Regulatory position on lending and digital payments in Nigeria.
