# SatsFarm Design Direction

This is a handoff for the future design and implementation agent. It records the visual direction in the farmer and farm-management reference images supplied by the project owner. It is not a request to implement or redesign screens now.

## Product shape

SatsFarm has two related products with different users and information needs:

1. **Farmer mobile app:** a simple, mobile-first wallet and farm companion for smallholder farmers in Northern Nigeria.
2. **NGO and cooperative web portal:** a desktop workspace for funders, cooperative administrators, and authorized field staff to coordinate and report on programs.

Use a shared visual identity, but do not force the same density or navigation model onto both products.

## Visual cues from the supplied images

- Lead with agricultural imagery: fields, crops, soil, harvests, and people working on farms.
- Use a grounded palette of deep forest and olive greens, warm off-white or sand surfaces, and restrained bright lime for primary actions or progress.
- Pair soft, calm backgrounds with crisp, high-contrast text and controls. Reserve dark translucent panels for map or photo overlays where text needs contrast.
- Use rounded cards, clear spacing, simple icons, and compact visual summaries. Charts and metric cards should feel like farm tools rather than financial trading screens.
- Field maps, crop cards, weather summaries, task lists, alerts, and progress indicators are useful patterns for the farmer app.
- The web portal can use denser dashboards, map views, charts, filters, and tables, while retaining the same agricultural colors and restrained card styling.
- Treat the reference images as mood and layout references, not assets to reproduce. Their locations, crops, weather, branding, and example data are not SatsFarm content.

## Farmer mobile experience

### Design goals

- Make common tasks understandable at a glance: check balance, receive, send, save toward a goal, and see the next farm action.
- Support low literacy and Hausa-first use. Prefer short labels, familiar icons paired with text, clear confirmation states, and optional audio or illustrated guidance where it helps.
- Keep controls large, forgiving, and comfortable for one-handed use on lower-cost phones.
- Show money in sats and a clearly marked NGN estimate. Do not present a mock conversion rate as a live market quote.
- Design for intermittent connectivity: show offline or syncing state, preserve safe local progress, and explain which actions need a network before the user commits.
- Keep wallet security understandable: recovery phrase handling, self-custody, and transaction confirmation must be clear and deliberate.

### Visual hierarchy

1. Balance and its sats/NGN context.
2. The primary action for the current screen, such as Receive or Send.
3. Farm-related goals, cooperative activity, or useful field reminders.
4. Secondary wallet and farm information.

Do not put farm telemetry, market charts, or advanced wallet details ahead of the core money actions unless research shows they are more useful to farmers.

## NGO and cooperative web portal

### Users and tasks

- **NGO or donor program staff:** create a program, fund its treasury, define eligibility and grant or loan rules, schedule disbursements, and review aggregated outcomes.
- **Cooperative leaders:** enroll or verify members, coordinate group savings, review repayments, and confirm program milestones within their authority.
- **Extension workers or field verifiers:** submit limited evidence that an agreed farm milestone was met.
- **Auditors:** inspect authorized program-level allocation, payment, verification, and correction records.

### Portal design principles

- Optimize for desktop review and operational work: a clear sidebar, program selector, date and geography filters, searchable tables, and contextual detail panels.
- Surface program health and the most useful totals first: allocated, disbursed, outstanding, farmer count, goal progress, and repayment status.
- Use maps and charts to explain distribution and progress, not as decoration. Provide an accessible table or text equivalent for each important chart.
- Make roles, approval state, and audit history visible around high-impact actions such as funding, batch disbursement, and milestone approval.
- Separate aggregated donor reporting from identifiable farmer records. Default donor views to aggregated, privacy-preserving data.
- Show source, date, and status for each metric. Distinguish on-chain confirmation, Lightning payment status, field attestation, and program estimate.

## Shared design system direction

- **Color:** forest/olive green for trust and navigation; sand/off-white for calm surfaces; lime for primary actions and positive progress; amber/orange for warnings; red only for errors or high-risk actions.
- **Photography:** authentic Northern Nigerian farming and community contexts, with consent and respectful representation. Avoid implying that stock imagery depicts actual SatsFarm members.
- **Typography:** highly legible, with support for Hausa diacritics and clear numeric forms. Use expressive display type sparingly; body and financial text must remain plain and easy to scan.
- **Motion:** subtle feedback for success, progress, and navigation. Avoid motion that slows repeated tasks or depends on high-end devices.
- **Accessibility:** high contrast, scalable text, semantic labels, keyboard access on web, and non-color indicators for status.
- **Localization:** English and Hausa are first-class. Check line wrapping and button sizing with real Hausa strings, not just English layouts.

## UX and trust constraints

- Never imply that a payment is reversible, guaranteed, or confirmed before its actual payment state supports that message.
- A Lightning payment, an on-chain transaction, a field verification, and a grant approval are different events; label them distinctly.
- Do not expose a farmer's wallet balance, identity, location, or transaction history to a donor by default.
- Avoid promising that Bitcoin transaction records alone prove real-world use of funds or agricultural impact. Pair payment evidence with carefully scoped program records and attestations.
- Present 2-of-3 treasury custody, a Lightning pool, grant controls, and loan terms as program choices requiring governance and legal/security review—not as settled product behavior.

## Later design handoff

Before polishing screens, prepare mobile flows for onboarding/recovery, home, receive/send, season goals, and Asusu; and web flows for program setup, treasury, batch disbursement, milestone review, repayments, and reporting. Validate these flows with farmers and cooperative staff in the intended regions before treating the reference compositions as final layouts.
