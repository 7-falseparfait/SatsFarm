import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import './App.css'

type Screen = 'overview' | 'vouchers' | 'payments' | 'farmers' | 'dealers'
type PaymentState = 'Settled' | 'Pending' | 'Failed'

type Farmer = {
  id: string
  name: string
  location: string
  language: 'Hausa' | 'English'
  phoneNumber?: string | null
  supportAmount?: number | null
  balanceNgn?: number | null
  inviteCode?: string | null
  inviteExpiresAt?: string | null
  inviteStatus?: 'Invited' | 'Joined' | 'Expired'
}

type Voucher = {
  id: string
  farmerId: string
  purpose: string
  amount: number
  remainingNgn: number
  amountOwedNgn: number
  createdAt: string
  status: 'Active' | 'Spent' | 'Closed'
  kind: 'Grant' | 'Loan'
}

type Payment = {
  id: string
  farmerId: string
  dealer: string
  amountNgn: number
  amountSats: number
  state: PaymentState
  time: string
  paymentHash?: string
  preimage?: string
  errorReason?: string
  rateUsed?: number
  rateLabel?: string
  invoice?: string
  voucherId?: string
}

type Dealer = { name: string; location: string; nodeId: string; active: boolean }

type LnStatus = {
  network: string
  version?: string
  ready: boolean
  rateNgnPerSat: number
  rateLabel: string
  detail?: string
  funder?: {
    nodeId: string
    spendableOnchainSats: number
    totalOnchainSats: number
    lightningSats: number
    channels: {
      counterpartyNodeId: string
      channelValueSats: number
      outboundCapacitySats: number
      inboundCapacitySats: number
      confirmationsRequired: number | null
      isUsable: boolean
    }[]
    peers: string[]
  }
  dealer?: { nodeId: string }
}

type PaymentRequest = { idempotent: boolean; payment: Payment }
type FunderReceiveAddress = { address: string; network: string }
type RepaymentType = 'Grain' | 'Cash' | 'Transfer'
type DealerSale = { id: string; dealer: string; amountNgn: number; status: string; createdAt: string }
type DemoDealerLink = { slug: string; name: string; dealerKey: string }

const API_URL = import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:8787'
const DEMO_DEALER_SLUGS: Record<string, string> = {
  'Gidan Noma Agro': 'gidan-noma',
  'Northern Seeds Co.': 'northern-seeds',
}

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  })
  if (!response.ok) {
    const body = await response.json().catch(() => ({})) as { error?: string }
    throw new Error(body.error ?? `API request failed (${response.status})`)
  }
  return response.json() as Promise<T>
}

const naira = (amount: number) => new Intl.NumberFormat('en-NG', {
  style: 'currency', currency: 'NGN', maximumFractionDigits: 0,
}).format(amount)

const nairaConverted = (rateNgnPerSat: number) => new Intl.NumberFormat('en-NG', {
  maximumFractionDigits: 2,
}).format(rateNgnPerSat)

function newRepaymentRequestId() {
  return typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : `rep-${Date.now()}-${Math.random().toString(36).slice(2)}`
}

function isRepaymentType(value: string): value is RepaymentType {
  return value === 'Grain' || value === 'Cash' || value === 'Transfer'
}

function Icon({ name, size = 18 }: { name: string; size?: number }) {
  const common = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.7, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, 'aria-hidden': true as const }
  const paths: Record<string, ReactNode> = {
    grid: <><rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/></>,
    ticket: <><path d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v2a2.5 2.5 0 0 0 0 5v2a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 15.5v-2a2.5 2.5 0 0 0 0-5z"/><path d="M9 8v1m0 3v1m0 3v.01"/></>,
    arrow: <><path d="M7 7h10v10"/><path d="m7 17 10-10"/></>,
    users: <><path d="M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20"/><circle cx="10" cy="7.5" r="3.5"/><path d="M17 11a3.5 3.5 0 0 0 0-7m3 16v-1.5a3.5 3.5 0 0 0-2.5-3.35"/></>,
    store: <><path d="M3 10h18l-1.3-5H4.3L3 10Z"/><path d="M5 10v10h14V10M9 20v-6h6v6"/></>,
    search: <><circle cx="10.8" cy="10.8" r="6.3"/><path d="m16 16 4.5 4.5"/></>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    chevron: <path d="m9 18 6-6-6-6"/>,
    clock: <><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.5 2"/></>,
    check: <path d="m5 12 4 4L19 6"/>,
    warning: <><path d="m10.3 4.8-7 12.1A1.4 1.4 0 0 0 4.5 19h15a1.4 1.4 0 0 0 1.2-2.1l-7-12.1a1.9 1.9 0 0 0-3.4 0Z"/><path d="M12 9v4m0 3h.01"/></>,
    download: <><path d="M12 3v11m0 0 4-4m-4 4-4-4"/><path d="M5 17v3h14v-3"/></>,
    close: <><path d="m6 6 12 12M18 6 6 18"/></>,
    shield: <><path d="M12 3 20 6v5c0 5-3.4 8.3-8 10-4.6-1.7-8-5-8-10V6z"/><path d="m9 12 2 2 4-4"/></>,
    sprout: <><path d="M12 20v-8"/><path d="M12 12C6 12 4 8 4 4c5 0 8 2 8 8Zm0 1c0-5 3-8 8-8 0 5-2 8-8 8Z"/></>,
  }
  return <svg {...common}>{paths[name] ?? paths.grid}</svg>
}

function App() {
  const [screen, setScreen] = useState<Screen>('overview')
  const [vouchers, setVouchers] = useState<Voucher[]>([])
  const [farmers, setFarmers] = useState<Farmer[]>([])
  const [payments, setPayments] = useState<Payment[]>([])
  const [dealers, setDealers] = useState<Dealer[]>([])
  const [dealerSales, setDealerSales] = useState<DealerSale[]>([])
  const [demoDealerLinks, setDemoDealerLinks] = useState<Record<string, string>>({})
  const [dealerLinks, setDealerLinks] = useState<Record<string, string>>({})
  const [query, setQuery] = useState('')
  const [modalOpen, setModalOpen] = useState(false)
  const [farmerModalOpen, setFarmerModalOpen] = useState(false)
  const [payModalOpen, setPayModalOpen] = useState(false)
  const [repaymentVoucher, setRepaymentVoucher] = useState<Voucher | null>(null)
  const [notice, setNotice] = useState('')
  const [apiError, setApiError] = useState('')
  const [apiConnected, setApiConnected] = useState(false)
  const [lnStatus, setLnStatus] = useState<LnStatus | null>(null)
  const [funderAddress, setFunderAddress] = useState('')
  const [addressBusy, setAddressBusy] = useState(false)

  async function refreshData() {
    try {
      const [farmerData, voucherData, paymentData, dealerData, dealerSalesData, demoDealerData, lnData] = await Promise.all([
        api<Farmer[]>('/api/farmers'), api<Voucher[]>('/api/vouchers'),
        api<Payment[]>('/api/payments'), api<Dealer[]>('/api/dealers'),
        api<DealerSale[]>('/api/dealers/invoices'),
        api<DemoDealerLink[]>('/api/dealers/demo'),
        api<LnStatus>('/api/ln/status'),
      ])
      setFarmers(farmerData)
      setVouchers(voucherData)
      setPayments(paymentData)
      setDealers(dealerData)
      setDealerSales(dealerSalesData)
      setDemoDealerLinks(Object.fromEntries(demoDealerData.map(({ slug, dealerKey }) => [slug, dealerKey])))
      setLnStatus(lnData)
      setApiError('')
      setApiConnected(true)
    } catch (error) {
      setApiConnected(false)
      setApiError(error instanceof Error ? error.message : 'Could not reach the local API.')
    }
  }

  useEffect(() => { void refreshData() }, [])

  const farmerById = useMemo(() => new Map(farmers.map((farmer) => [farmer.id, farmer])), [farmers])
  const filteredVouchers = vouchers.filter((voucher) => {
    const farmer = farmerById.get(voucher.farmerId)
    const haystack = `${voucher.id} ${voucher.purpose} ${farmer?.name ?? ''} ${farmer?.location ?? ''}`.toLowerCase()
    return haystack.includes(query.toLowerCase())
  })
  const filteredPayments = payments.filter((payment) => {
    const farmer = farmerById.get(payment.farmerId)
    return `${payment.id} ${payment.dealer} ${farmer?.name ?? ''}`.toLowerCase().includes(query.toLowerCase())
  })

  const totalIssued = vouchers.reduce((sum, voucher) => sum + voucher.amount, 0)
  const totalGranted = vouchers.filter((voucher) => voucher.kind === 'Grant').reduce((sum, voucher) => sum + voucher.amount, 0)
  const grantOutstanding = vouchers.filter((voucher) => voucher.kind === 'Grant' && voucher.status === 'Active').reduce((sum, voucher) => sum + voucher.remainingNgn, 0)
  const loanOutstanding = vouchers.filter((voucher) => voucher.kind === 'Loan').reduce((sum, voucher) => sum + voucher.amountOwedNgn, 0)

  async function createVoucher(farmerId: string, amount: number, purpose: string, kind: 'Grant' | 'Loan') {
    try {
      await api<Voucher>('/api/vouchers', {
        method: 'POST', body: JSON.stringify({ farmerId, amount, purpose, kind }),
      })
      await refreshData()
      setModalOpen(false)
      setNotice(kind === 'Grant'
        ? 'Grant voucher recorded - no repayment will be expected. No funds moved yet.'
        : 'Loan voucher recorded - this balance is expected to be repaid. No funds moved yet.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not create the voucher.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  async function createFarmer(name: string, phoneNumber: string, supportAmount: number) {
    try {
      await api<Farmer>('/api/dashboard/farmers', {
        method: 'POST',
        body: JSON.stringify({ name, phoneNumber, supportAmount }),
      })
      await refreshData()
      setFarmerModalOpen(false)
      setNotice('Farmer added. Share the invite code or QR within 24 hours.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not add the farmer.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  async function regenerateInvite(farmerId: string) {
    try {
      await api<Farmer>(`/api/dashboard/farmers/${farmerId}/invite`, { method: 'POST' })
      await refreshData()
      setNotice('A new invite code is ready. The previous code no longer works.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not regenerate the invite code.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  async function requestVoucherPayment(voucherId: string, invoice: string) {
    try {
      const initial = await api<PaymentRequest>('/api/payments/request', {
        method: 'POST', body: JSON.stringify({ voucherId, invoice, idempotencyKey: crypto.randomUUID() }),
      })
      let payment = initial.payment
      let attempts = 0
      while (payment.state === 'Pending' && attempts < 12) {
        await new Promise((resolve) => window.setTimeout(resolve, 2500))
        payment = await api<Payment>(`/api/payments/${payment.id}`)
        attempts += 1
      }
      await refreshData()
      setPayModalOpen(false)
      if (payment.state === 'Settled') {
        setNotice(`Payment ${payment.id} settled on Mutinynet (test network): ${payment.amountSats.toLocaleString()} sats = ${naira(payment.amountNgn)} at the fixed demo rate.`)
      } else if (payment.state === 'Failed') {
        setApiError(`Payment ${payment.id} failed: ${payment.errorReason ?? 'node reported a failure'}`)
      } else {
        setNotice(`Payment ${payment.id} still pending on Mutinynet - check its state on the payments ledger.`)
      }
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not request the payment.')
    }
    window.setTimeout(() => setNotice(''), 6000)
  }

  async function recordRepayment(voucherId: string, amountNgn: number, repaymentType: RepaymentType, note: string, requestId: string) {
    try {
      await api(`/api/vouchers/${encodeURIComponent(voucherId)}/repayments`, {
        method: 'POST',
        body: JSON.stringify({ requestId, amountNgn, repaymentType, note: note || null }),
      })
      await refreshData()
      setRepaymentVoucher(null)
      setNotice(`Repayment recorded: ${naira(amountNgn)} by ${repaymentType.toLowerCase()}.`)
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not record the repayment.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  async function resetDemo() {
    try {
      await api('/api/demo/reset', { method: 'POST' })
      await refreshData()
      setNotice('Local demo records reset.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not reset demo data.')
    }
    window.setTimeout(() => setNotice(''), 3000)
  }

  async function generateFunderAddress() {
    setAddressBusy(true)
    setApiError('')
    try {
      const result = await api<FunderReceiveAddress>('/api/funder/receive-address', {
        method: 'POST',
      })
      setFunderAddress(result.address)
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not generate the funder receive address.')
    } finally {
      setAddressBusy(false)
    }
  }

  async function copyFunderAddress() {
    try {
      await navigator.clipboard.writeText(funderAddress)
      setNotice('Funder receive address copied.')
    } catch {
      setApiError('Could not copy the address. Select and copy it manually.')
    }
    window.setTimeout(() => setNotice(''), 3000)
  }

  async function whitelistDealer(nodeId: string, active: boolean, name?: string) {
    try {
      const result = await api<{ dealerKey?: string | null }>('/api/dealers/whitelist', {
        method: 'POST', body: JSON.stringify({ nodeId, active, ...(name ? { name } : {}) }),
      })
      const issuedKey = result.dealerKey
      if (issuedKey) {
        setDealerLinks((current) => ({ ...current, [nodeId]: issuedKey }))
      } else {
        setDealerLinks((current) => {
          const next = { ...current }
          delete next[nodeId]
          return next
        })
      }
      await refreshData()
      setNotice(active ? 'Dealer node ID added to the payment whitelist.' : 'Dealer node ID removed from the payment whitelist.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not update the whitelist.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  async function regenerateDealerKey(nodeId: string) {
    try {
      const result = await api<{ dealerKey: string }>(`/api/dealers/${encodeURIComponent(nodeId)}/key/regenerate`, { method: 'POST' })
      setDealerLinks((current) => ({ ...current, [nodeId]: result.dealerKey }))
      await refreshData()
      setNotice('A new vendor link is ready. The previous link no longer works.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not regenerate the dealer link.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  async function regenerateDemoDealerKey(slug: string) {
    try {
      await api(`/api/dealers/demo/${encodeURIComponent(slug)}/key/regenerate`, { method: 'POST' })
      await refreshData()
      setNotice('The demo dealer link was refreshed.')
    } catch (error) {
      setApiError(error instanceof Error ? error.message : 'Could not refresh the demo dealer link.')
    }
    window.setTimeout(() => setNotice(''), 4200)
  }

  const pageTitle: Record<Screen, string> = {
    overview: 'Program overview',
    vouchers: 'Vouchers',
    payments: 'Payments',
    farmers: 'Farmers',
    dealers: 'Registered dealers',
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <a className="brand" href="#overview" onClick={() => setScreen('overview')} aria-label="SatsFarm Program Desk home">
          <span className="brand-mark"><Icon name="sprout" size={21} /></span>
          <span><strong>SatsFarm</strong><small>PROGRAM DESK</small></span>
        </a>

        <div className="workspace-label">WORKSPACE</div>
        <nav className="side-nav" aria-label="Main navigation">
          <NavItem active={screen === 'overview'} icon="grid" label="Overview" onClick={() => setScreen('overview')} />
          <NavItem active={screen === 'vouchers'} icon="ticket" label="Vouchers" count={vouchers.length} onClick={() => setScreen('vouchers')} />
          <NavItem active={screen === 'payments'} icon="arrow" label="Payments" onClick={() => setScreen('payments')} />
          <NavItem active={screen === 'farmers'} icon="users" label="Farmers" count={farmers.length} onClick={() => setScreen('farmers')} />
          <NavItem active={screen === 'dealers'} icon="store" label="Dealers" onClick={() => setScreen('dealers')} />
        </nav>

        <div className="sidebar-bottom">
          <div className="network-card">
            <span className={`network-dot${apiConnected && lnStatus?.ready ? '' : ' offline'}`} />
            <div>
              <strong>Local API {apiConnected ? 'connected' : 'offline'}</strong>
              <small>
                {lnStatus?.ready
                  ? `Mutinynet node ready · ${nairaConverted(lnStatus.rateNgnPerSat)} NGN/sat demo rate`
                  : lnStatus
                    ? 'Lightning node bootstrapping…'
                    : 'Payment node not connected'}
              </small>
            </div>
          </div>
          <div className="account-row"><span className="avatar avatar-admin">NG</span><span><strong>Program officer</strong><small>Demo workspace</small></span><button className="icon-button account-menu" aria-label="Account menu"><span>•••</span></button></div>
        </div>
      </aside>

      <main className="main-area">
        <header className="topbar">
          <div className="breadcrumbs"><span>Program</span><Icon name="chevron" size={14} /><strong>{pageTitle[screen]}</strong></div>
          <div className="topbar-actions">
            <span className="demo-pill"><span /> DEMO DATA</span>
            <button className="icon-button notification-button" aria-label="Notifications"><span className="bell-icon">◌</span><i /></button>
            <span className="avatar avatar-admin top-avatar">NG</span>
          </div>
        </header>

        <div className="page-content">
          <div className="demo-notice"><Icon name="shield" size={17} /><span><strong>Local demo ledger {lnStatus?.network ? `· ${lnStatus.network}` : ''}</strong> — voucher changes persist in SQLite. Payment rows marked SEED are examples; voucher-funded rows pay out on the Mutinynet test network at the fixed demo rate. Nothing touches mainnet.</span><button onClick={resetDemo}>Reset demo data</button></div>
          {apiError && <div className="api-error" role="alert"><span><strong>Cannot reach SatsFarm API.</strong> {apiError} Start it with <code>cd ngo-api && cargo run</code>.</span><button className="text-button" onClick={() => void refreshData()}>Retry</button></div>}

          <section className="page-heading">
            <div><p className="eyebrow">PROGRAM DESK · MUTINYNET TEST NETWORK</p><h1>{pageTitle[screen]}</h1><p className="heading-copy">Track support, invite codes, and program payments in one place.</p></div>
            <div className="heading-actions">{screen === 'farmers' && <button className="button button-secondary" onClick={() => setFarmerModalOpen(true)}><Icon name="plus" size={16} /> Add farmer</button>}<button className="button button-secondary" onClick={() => setScreen('payments')}><Icon name="download" size={16} /> Export report</button><button className="button button-primary" onClick={() => setModalOpen(true)}><Icon name="plus" size={17} /> Create voucher</button></div>
          </section>

          {screen === 'overview' && <Overview vouchers={vouchers} payments={filteredPayments} farmers={farmers} dealers={dealers} farmerById={farmerById} totalIssued={totalIssued} totalGranted={totalGranted} grantOutstanding={grantOutstanding} loanOutstanding={loanOutstanding} lnStatus={lnStatus} funderAddress={funderAddress} addressBusy={addressBusy} generateFunderAddress={generateFunderAddress} copyFunderAddress={copyFunderAddress} openVouchers={() => setScreen('vouchers')} openPayments={() => setScreen('payments')} create={() => setModalOpen(true)} />}
          {screen === 'vouchers' && <VoucherView vouchers={filteredVouchers} farmerById={farmerById} query={query} setQuery={setQuery} create={() => setModalOpen(true)} recordRepayment={(voucher) => { setApiError(''); setRepaymentVoucher(voucher) }} />}
          {screen === 'payments' && <PaymentView payments={filteredPayments} farmerById={farmerById} query={query} setQuery={setQuery} create={() => setPayModalOpen(true)} lnStatus={lnStatus} />}
          {screen === 'farmers' && <FarmerView farmers={farmers} onRegenerate={regenerateInvite} />}
          {screen === 'dealers' && <DealerView dealers={dealers} dealerSales={dealerSales} dealerLinks={dealerLinks} demoDealerLinks={demoDealerLinks} lnStatus={lnStatus} onWhitelist={whitelistDealer} onRegenerateKey={regenerateDealerKey} onRegenerateDemoKey={regenerateDemoDealerKey} />}

          <footer className="page-footer"><span>© 2026 SatsFarm · Program records for demonstration only</span><span>Target network: {lnStatus?.network ?? 'Mutinynet'}{lnStatus?.ready ? ' · node ready' : ' · node disconnected'}</span></footer>
        </div>
      </main>

      {modalOpen && <VoucherModal farmers={farmers} onClose={() => setModalOpen(false)} onCreate={createVoucher} />}
      {farmerModalOpen && <FarmerModal onClose={() => setFarmerModalOpen(false)} onCreate={createFarmer} />}
      {payModalOpen && <PayModal vouchers={vouchers} lnStatus={lnStatus} onClose={() => setPayModalOpen(false)} onSubmit={requestVoucherPayment} />}
      {repaymentVoucher && <RepaymentModal voucher={repaymentVoucher} error={apiError} onClose={() => setRepaymentVoucher(null)} onSubmit={recordRepayment} />}
      {notice && <div className="toast" role="status"><Icon name="check" size={17} />{notice}</div>}
    </div>
  )
}

function NavItem({ active, icon, label, count, onClick }: { active: boolean; icon: string; label: string; count?: number; onClick: () => void }) {
  return <button className={`nav-item${active ? ' active' : ''}`} onClick={onClick}><Icon name={icon} size={18} /><span>{label}</span>{count !== undefined && <small>{count}</small>}</button>
}

function sats(amountNgn: number, rateNgnPerSat: number | null | undefined) {
  if (!rateNgnPerSat || rateNgnPerSat <= 0) return '— sats'
  return `${Math.floor(amountNgn / rateNgnPerSat).toLocaleString()} sats`
}

function Overview({ vouchers, payments, farmers, dealers, farmerById, totalIssued, totalGranted, grantOutstanding, loanOutstanding, lnStatus, funderAddress, addressBusy, generateFunderAddress, copyFunderAddress, openVouchers, openPayments, create }: {
  vouchers: Voucher[]; payments: Payment[]; farmers: Farmer[]; dealers: Dealer[]; farmerById: Map<string, Farmer>; totalIssued: number; totalGranted: number; grantOutstanding: number; loanOutstanding: number; lnStatus: LnStatus | null; funderAddress: string; addressBusy: boolean; generateFunderAddress: () => void; copyFunderAddress: () => void; openVouchers: () => void; openPayments: () => void; create: () => void
}) {
  const spendableLightningSats = lnStatus?.funder?.channels
    .filter((channel) => channel.isUsable)
    .reduce((sum, channel) => sum + channel.outboundCapacitySats, 0) ?? 0
  const spendableLightningNgn = lnStatus?.rateNgnPerSat
    ? Math.floor(spendableLightningSats * lnStatus.rateNgnPerSat)
    : null
  return <>
    <section className="metrics-grid" aria-label="Program summary">
      <Metric label="Grant vouchers issued" value={naira(totalGranted)} detail={`${vouchers.filter((v) => v.kind === 'Grant').length} records · no repayment`} icon="ticket" trend="This season" />
      <Metric label="Loan balance outstanding" value={naira(loanOutstanding)} detail={`${sats(loanOutstanding, lnStatus?.rateNgnPerSat)} · active vouchers`} icon="clock" trend="Repayable" />
      <Metric label="Grant balance outstanding" value={naira(grantOutstanding)} detail={`${sats(grantOutstanding, lnStatus?.rateNgnPerSat)} · active vouchers`} icon="clock" trend="Not repayable" />
      <Metric label="Payments settled" value={String(payments.filter((payment) => payment.state === 'Settled' && payment.paymentHash).length).padStart(2, '0')} detail={`${payments.filter((payment) => payment.state === 'Pending' && payment.paymentHash).length} pending · Mutinynet`} icon="arrow" trend="Test network" />
      <Metric label="Funder Lightning available" value={`${spendableLightningSats.toLocaleString()} sats`} detail={spendableLightningNgn === null ? 'NGN estimate unavailable' : `${naira(spendableLightningNgn)} at demo rate`} icon="arrow" trend={lnStatus?.ready ? 'Mutinynet' : 'Node offline'} />
    </section>

    <section className="panel full-panel funder-funding-panel">
      <div className="list-toolbar">
        <div><h2>Fund the program node</h2><p>Receive address for the API funder node · Mutinynet test network only</p></div>
        <button className="button button-primary" onClick={generateFunderAddress} disabled={addressBusy || !lnStatus?.ready}>
          <Icon name="plus" size={16} /> {addressBusy ? 'Generating…' : funderAddress ? 'Generate new address' : 'Get receive address'}
        </button>
      </div>
      <div className="funder-funding-content">
        {funderAddress
          ? <><QRCodeSVG value={funderAddress} size={144} includeMargin aria-label="QR code for the program funder receive address" />
            <div className="funder-address-details"><strong>Program funder on-chain address</strong><p>Send Mutinynet testnet funds only. This is not a mainnet address and is not your farmer wallet.</p>
              <code className="funder-address">{funderAddress}</code>
              <button className="button button-secondary" onClick={copyFunderAddress}><Icon name="check" size={15} /> Copy address</button>
            </div></>
          : <p>{lnStatus?.ready ? 'Generate an address to request additional Mutinynet test funds for the program node.' : 'The funder node must finish starting before it can generate a receive address.'}</p>}
      </div>
      <div className="panel-bottom"><span>On-chain funds do not automatically add Lightning channel capacity.</span><span className="subtle-text">Mutinynet only · no mainnet funds</span></div>
    </section>

    <section className="content-grid">
      <div className="panel recent-panel">
        <PanelHeader title="Recent vouchers" subtitle="Latest program allocations" action="View all" onAction={openVouchers} />
        <div className="table-scroll"><table><thead><tr><th>VOUCHER</th><th>FARMER</th><th>PURPOSE</th><th>VALUE</th><th>STATUS</th></tr></thead><tbody>
        {vouchers.slice(0, 4).map((voucher) => <tr key={voucher.id}><td><strong className="mono">{voucher.id}</strong><small>{voucher.createdAt}</small></td><td><Person farmer={farmerById.get(voucher.farmerId)} /></td><td>{voucher.purpose}</td><td className="amount-cell">{naira(voucher.amount)}</td><td><StatusPill status={voucher.status} /></td></tr>)}
        </tbody></table></div>
        <div className="panel-bottom"><span>Showing {Math.min(vouchers.length, 4)} of {vouchers.length} demo vouchers</span><button className="text-button" onClick={openVouchers}>View voucher ledger <Icon name="chevron" size={14} /></button></div>
      </div>

      <div className="panel season-panel">
        <PanelHeader title="Season at a glance" subtitle="2026 inputs program" />
        <div className="season-summary"><div><span className="soft-label">ALLOCATED</span><strong>{naira(totalIssued)}</strong></div><span className="season-icon"><Icon name="sprout" size={20} /></span></div>
        <div className="progress-label"><span>Award value issued</span><strong>{totalIssued ? Math.min(Math.round(totalIssued / 400000 * 100), 100) : 0}%</strong></div>
        <div className="progress-track"><span style={{ width: `${totalIssued ? Math.min(Math.round(totalIssued / 400000 * 100), 100) : 0}%` }} /></div>
        <div className="goal-foot"><span>Grants {naira(totalGranted)} · Loans {naira(totalIssued - totalGranted)}</span><strong>{naira(400000)}</strong></div>
        <div className="season-divider" />
        <div className="season-detail"><span className="detail-icon"><Icon name="users" size={16} /></span><span><strong>{farmers.length} farmers</strong><small>Enrolled in this program</small></span><Icon name="chevron" size={16} /></div>
        <div className="season-detail"><span className="detail-icon"><Icon name="store" size={16} /></span><span><strong>{dealers.length} dealers</strong><small>Sample dealer registry</small></span><Icon name="chevron" size={16} /></div>
      </div>
    </section>

    <section className="panel payment-panel">
      <PanelHeader title="Dealer payments" subtitle="Payment state examples · not live network data" action="View payments" onAction={openPayments} />
      <div className="table-scroll"><table><thead><tr><th>PAYMENT</th><th>FARMER</th><th>DEALER</th><th>NAIRA VALUE</th><th>SATS</th><th>STATE</th></tr></thead><tbody>
        {payments.slice(0, 4).map((payment) => <tr key={payment.id}><td><strong className="mono">{payment.id}</strong><small>{payment.time}</small></td><td><Person farmer={farmerById.get(payment.farmerId)} compact /></td><td>{payment.dealer}</td><td className="amount-cell">{naira(payment.amountNgn)}</td><td className="mono secondary-cell">{payment.amountSats.toLocaleString()} sats</td><td><StatusPill status={payment.state} /></td></tr>)}
      </tbody></table></div>
      <div className="panel-bottom"><span>Sample payment records are not confirmations from Mutinynet.</span><button className="text-button" onClick={create}>Issue a voucher <Icon name="plus" size={14} /></button></div>
    </section>
  </>
}

function VoucherView({ vouchers, farmerById, query, setQuery, create, recordRepayment }: { vouchers: Voucher[]; farmerById: Map<string, Farmer>; query: string; setQuery: (value: string) => void; create: () => void; recordRepayment: (voucher: Voucher) => void }) {
  return <section className="panel full-panel">
    <div className="list-toolbar"><div><h2>Voucher ledger</h2><p>Voucher balances are demo records denominated in naira.</p></div><div className="toolbar-actions"><SearchBox value={query} onChange={setQuery} placeholder="Search vouchers or farmers" /><button className="button button-primary" onClick={create}><Icon name="plus" size={16} /> Create voucher</button></div></div>
    <div className="table-scroll"><table><thead><tr><th>VOUCHER</th><th>FARMER</th><th>INPUT PURPOSE</th><th>AWARD TYPE</th><th>NAIRA VALUE</th><th>LOAN OWED</th><th>ISSUED</th><th>STATUS</th><th /></tr></thead><tbody>
      {vouchers.map((voucher) => <tr key={voucher.id}><td><strong className="mono">{voucher.id}</strong></td><td><Person farmer={farmerById.get(voucher.farmerId)} /></td><td>{voucher.purpose}</td><td><span className={`award-kind ${voucher.kind === 'Loan' ? 'loan' : 'grant'}`}>{voucher.kind}</span></td><td className="amount-cell">{naira(voucher.amount)}</td><td className="amount-cell">{voucher.kind === 'Loan' ? naira(voucher.amountOwedNgn) : '—'}</td><td>{voucher.createdAt}</td><td><StatusPill status={voucher.status} /></td><td>{voucher.kind === 'Loan' && voucher.amountOwedNgn > 0 && <button className="button button-secondary" onClick={() => recordRepayment(voucher)}>Record repayment</button>}</td></tr>)}
    </tbody></table>{vouchers.length === 0 && <EmptyState message="No vouchers match that search." />}</div>
    <div className="panel-bottom"><span>{vouchers.length} voucher records · saved in local SQLite</span><span className="subtle-text">Demo ledger · no funds issued</span></div>
  </section>
}

function RepaymentModal({ voucher, error, onClose, onSubmit }: {
  voucher: Voucher
  error: string
  onClose: () => void
  onSubmit: (voucherId: string, amount: number, type: RepaymentType, note: string, requestId: string) => void
}) {
  const [amount, setAmount] = useState('')
  const [type, setType] = useState<RepaymentType>('Grain')
  const [note, setNote] = useState('')
  const [requestId, setRequestId] = useState(newRepaymentRequestId)
  const amountValue = Number(amount)
  const canSubmit = Number.isSafeInteger(amountValue) && amountValue > 0 && amountValue <= voucher.amountOwedNgn

  function changed() {
    setRequestId(newRepaymentRequestId())
  }

  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="modal" role="dialog" aria-modal="true" aria-labelledby="repayment-modal-title"><div className="modal-header"><div><span className="eyebrow">LOAN REPAYMENT</span><h2 id="repayment-modal-title">Record repayment</h2></div><button className="icon-button" onClick={onClose} aria-label="Close"><Icon name="close" size={19} /></button></div><p className="modal-copy">{voucher.id} · {voucher.purpose}<br />Amount owed: <strong>{naira(voucher.amountOwedNgn)}</strong></p>{error && <div className="api-error" role="alert">{error}</div>}<form onSubmit={(event) => { event.preventDefault(); if (canSubmit) onSubmit(voucher.id, amountValue, type, note.trim(), requestId) }}>
    <label className="field-label">Amount received <span className="field-hint">NGN</span><div className="amount-input"><span>₦</span><input inputMode="numeric" type="number" min="1" max={voucher.amountOwedNgn} step="1" placeholder="10,000" value={amount} onChange={(event) => { setAmount(event.target.value); changed() }} required /></div></label>
    <label className="field-label">Type<select value={type} onChange={(event) => { if (isRepaymentType(event.target.value)) { setType(event.target.value); changed() } }}><option>Grain</option><option>Cash</option><option>Transfer</option></select></label>
    <label className="field-label">Note <span className="field-hint">Optional</span><textarea rows={3} maxLength={500} value={note} onChange={(event) => { setNote(event.target.value); changed() }} placeholder="Quantity, agreed value, or receipt reference" /></label>
    <div className="modal-actions"><button type="button" className="button button-secondary" onClick={onClose}>Cancel</button><button type="submit" className="button button-primary" disabled={!canSubmit}><Icon name="check" size={16} /> Record repayment</button></div>
  </form></section></div>
}

function PaymentView({ payments, farmerById, query, setQuery, create, lnStatus }: {
  payments: Payment[]; farmerById: Map<string, Farmer>; query: string; setQuery: (value: string) => void; create: () => void; lnStatus: LnStatus | null
}) {
  const seeded = (payment: Payment) => !payment.paymentHash
  return <section className="panel full-panel">
    <div className="list-toolbar"><div><h2>Payment activity</h2><p>SEED rows are storied examples. Voucher rows are paid on the Mutinynet test network at the fixed demo rate; settled rows carry a strokeable payment hash and preimage.</p></div><div className="toolbar-actions"><SearchBox value={query} onChange={setQuery} placeholder="Search payment, farmer, dealer" /><button className="button button-primary" onClick={create} disabled={!lnStatus?.ready}><Icon name="plus" size={16} /> Request payment</button></div></div>
    <div className="table-scroll"><table><thead><tr><th>PAYMENT</th><th>FARMER</th><th>DEALER</th><th>NAIRA VALUE</th><th>SATS</th><th>TIME</th><th>STATE</th></tr></thead><tbody>
      {payments.map((payment) => <tr key={payment.id} title={payment.paymentHash ? `Hash ${payment.paymentHash}\nPreimage ${payment.preimage ?? '—'}\n${payment.rateLabel ?? ''}` : undefined}>
        <td><strong className="mono">{payment.id}</strong><small>{seeded(payment) ? 'seed example' : `Mutinynet · ${payment.rateUsed ?? ''} NGN/sat`}</small></td>
        <td><Person farmer={farmerById.get(payment.farmerId)} compact /></td>
        <td>{payment.dealer}</td>
        <td className="amount-cell">{naira(payment.amountNgn)}</td>
        <td className="mono secondary-cell">{payment.amountSats.toLocaleString()}</td>
        <td>{payment.time}</td>
        <td><StatusPill status={payment.state} /></td>
      </tr>)}
    </tbody></table>{payments.length === 0 && <EmptyState message="No sample payments match that search." />}</div>
    <div className="panel-bottom"><span>{lnStatus?.rateLabel ?? 'Payment rate unavailable until the Lightning node is ready.'}</span><span className="subtle-text">{lnStatus?.ready ? 'Payments from the funder node · Mutinynet' : 'Payment actions disabled: node not ready'}</span></div>
  </section>
}

function FarmerView({ farmers, onRegenerate }: { farmers: Farmer[]; onRegenerate: (farmerId: string) => void }) {
  return <section className="panel full-panel"><div className="list-toolbar"><div><h2>Farmers and invitations</h2><p>Share a single-use invite code or scan its QR. Codes expire after 24 hours.</p></div></div><div className="table-scroll"><table><thead><tr><th>FARMER</th><th>PHONE</th><th>SUPPORT</th><th>INVITE CODE / QR</th><th>STATUS</th><th /></tr></thead><tbody>
    {farmers.map((farmer) => {
      const joined = farmer.inviteStatus === 'Joined'
      const code = farmer.inviteCode
      return <tr key={farmer.id}>
        <td><span className="person"><span className="avatar avatar-farmer">{farmer.name.split(' ').map((part) => part[0]).join('')}</span><span><strong>{farmer.name}</strong></span></span></td>
        <td>{farmer.phoneNumber || '—'}</td>
        <td><strong>{naira(farmer.supportAmount ?? 0)}</strong><small className="cell-subtext">{naira(farmer.balanceNgn ?? 0)} remaining</small></td>
        <td>{!joined && code ? <div className="invite-cell"><QRCodeSVG value={`satsfarm://join?code=${encodeURIComponent(code)}`} size={84} includeMargin /><span><strong className="mono invite-code">{code}</strong><small className="cell-subtext">{farmer.inviteExpiresAt ? `Expires ${new Date(farmer.inviteExpiresAt).toLocaleString()}` : 'Single use'}</small></span></div> : <span className="subtle-text">{joined ? 'Farmer linked' : 'No active code'}</span>}</td>
        <td><StatusPill status={farmer.inviteStatus ?? 'Expired'} /></td>
        <td>{!joined && <button className="button button-secondary" onClick={() => onRegenerate(farmer.id)}>Regenerate code</button>}</td>
      </tr>
    })}
  </tbody></table>{farmers.length === 0 && <EmptyState message="No farmers yet. Add a farmer to create an invite." />}</div><div className="panel-bottom"><span>{farmers.length} profiles shown</span><span className="subtle-text">Only name, phone number, and support amount are collected for new farmers.</span></div></section>
}

function DealerView({ dealers, dealerSales, dealerLinks, demoDealerLinks, lnStatus, onWhitelist, onRegenerateKey, onRegenerateDemoKey }: {
  dealers: Dealer[]
  dealerSales: DealerSale[]
  dealerLinks: Record<string, string>
  demoDealerLinks: Record<string, string>
  lnStatus: LnStatus | null
  onWhitelist: (nodeId: string, active: boolean, name?: string) => void
  onRegenerateKey: (nodeId: string) => void
  onRegenerateDemoKey: (slug: string) => void
}) {
  const [nodeId, setNodeId] = useState('')
  const [dealerName, setDealerName] = useState('')
  const trimmed = nodeId.trim()
  const canSubmit = trimmed.length === 66 && /^[0-9a-fA-F]+$/.test(trimmed)
  return <><section className="panel full-panel"><div className="list-toolbar"><div><h2>Registered dealers</h2><p>Dealer payments are limited to whitelisted Lightning node IDs. The API refuses invoices from any other payee.</p></div><span className="whitelist-label"><Icon name="shield" size={15} /> Whitelist enforced by API</span></div>
    <form className="whitelist-form" onSubmit={(event) => { event.preventDefault(); if (canSubmit) { onWhitelist(trimmed, true, dealerName.trim() || undefined); setNodeId(''); setDealerName('') } }}>
      <label className="field-label field-wide">Lightning node ID (66 hex chars)<input value={nodeId} onChange={(event) => setNodeId(event.target.value)} placeholder="03cbb72e874aa46e495288e212823774318369ee8ee594095f146296bc4b78874e" className="mono" />{lnStatus?.dealer?.nodeId && <button type="button" className="text-button demo-node-button" onClick={() => setNodeId(lnStatus.dealer!.nodeId)}>Use demo dealer node ID</button>}</label>
      <label className="field-label">Dealer name <span className="field-hint">optional</span><input value={dealerName} onChange={(event) => setDealerName(event.target.value)} placeholder="Kano Farm Inputs" /></label>
      <button type="submit" className="button button-primary" disabled={!canSubmit}><Icon name="shield" size={15} /> Add to whitelist</button>
    </form>
    <div className="table-scroll"><table><thead><tr><th>DEALER</th><th>LOCATION</th><th>NODE ID</th><th>PAYMENT ACCESS</th><th>VENDOR LINK</th></tr></thead><tbody>
    {dealers.map((dealer) => {
      const dealerKey = dealerLinks[dealer.nodeId]
      const demoSlug = DEMO_DEALER_SLUGS[dealer.name]
      return <tr key={`${dealer.nodeId}-${dealer.name}`}><td><span className="dealer-name"><span className="dealer-avatar"><Icon name="store" size={16} /></span><strong>{dealer.name}</strong></span></td><td>{dealer.location}</td><td className="mono">{dealer.nodeId}</td><td>
      {demoSlug || dealer.nodeId.includes('…') ? <StatusPill status={dealer.active ? 'Allowlisted · demo' : 'Inactive'} /> :
        <button className="text-button" onClick={() => onWhitelist(dealer.nodeId, !dealer.active)}>{dealer.active ? 'Deactivate' : 'Activate'}</button>}
    </td><td>{dealer.active && demoSlug && dealer.nodeId === lnStatus?.dealer?.nodeId
      ? <span className="vendor-link-actions">{demoDealerLinks[demoSlug]
        ? <a className="text-button" href={`/dealer?key=${encodeURIComponent(demoDealerLinks[demoSlug])}`} target="_blank" rel="noreferrer">Open vendor page</a>
        : <span className="subtle-text">Dealer link is loading.</span>}<button className="text-button" onClick={() => onRegenerateDemoKey(demoSlug)}>Regenerate link</button></span>
      : dealer.active && dealer.nodeId === lnStatus?.dealer?.nodeId
        ? <span className="vendor-link-actions">{dealerKey
        ? <a className="text-button" href={`/dealer?key=${encodeURIComponent(dealerKey)}`} target="_blank" rel="noreferrer">Open vendor page</a>
        : <span className="subtle-text">Link key hidden; generate a new link to share.</span>}<button className="text-button" onClick={() => onRegenerateKey(dealer.nodeId)}>{dealerKey ? 'Regenerate link' : 'Generate / rotate vendor link'}</button></span>
        : <span className="subtle-text">{dealer.active ? 'Vendor page is available for the configured demo dealer node only.' : 'Activate to create a vendor link.'}</span>}</td></tr>
    })}
  </tbody></table></div><div className="inline-note"><Icon name="warning" size={17} /><span>Whitelisted node IDs unlock real Mutinynet test-network payments from the funder node. Use the deactivate control to refuse a dealer for testing.</span></div></section>
    <section className="panel full-panel dealer-sales-panel"><div className="list-toolbar"><div><h2>Vendor payment activity</h2><p>Invoices created by the dealer page and their latest payment status.</p></div></div><div className="table-scroll"><table><thead><tr><th>SALE</th><th>DEALER</th><th>AMOUNT</th><th>CREATED</th><th>STATUS</th></tr></thead><tbody>
      {dealerSales.map((sale) => <tr key={sale.id}><td className="mono">{sale.id.slice(0, 12)}</td><td>{sale.dealer}</td><td className="amount-cell">{naira(sale.amountNgn)}</td><td>{sale.createdAt}</td><td><StatusPill status={sale.status} /></td></tr>)}
    </tbody></table>{dealerSales.length === 0 && <EmptyState message="No vendor payment requests yet." />}</div></section></>
}

function Metric({ label, value, detail, icon, trend }: { label: string; value: string; detail: string; icon: string; trend: string }) {
  return <article className="metric-card"><div className="metric-top"><span>{label}</span><span className="metric-icon"><Icon name={icon} size={18} /></span></div><strong className="metric-value">{value}</strong><div className="metric-foot"><span>{detail}</span><small>{trend}</small></div></article>
}

function PanelHeader({ title, subtitle, action, onAction }: { title: string; subtitle: string; action?: string; onAction?: () => void }) {
  return <div className="panel-header"><div><h2>{title}</h2><p>{subtitle}</p></div>{action && <button className="text-button" onClick={onAction}>{action}<Icon name="chevron" size={14} /></button>}</div>
}

function Person({ farmer, compact = false }: { farmer?: Farmer; compact?: boolean }) {
  if (!farmer) return <span className="subtle-text">Unknown farmer</span>
  const initials = farmer.name.split(' ').map((part) => part[0]).join('')
  return <span className={`person${compact ? ' compact' : ''}`}><span className="avatar avatar-farmer">{initials}</span><span><strong>{farmer.name}</strong>{!compact && <small>{farmer.id}</small>}</span></span>
}

function StatusPill({ status }: { status: string }) {
  const style = status.toLowerCase().includes('settled') || status === 'Received' || status === 'Active' || status === 'Joined' ? 'success' : status === 'Pending' || status === 'Invited' ? 'pending' : status === 'Failed' || status === 'Inactive' || status === 'Expired' ? 'danger' : 'neutral'
  return <span className={`status-pill ${style}`}><i />{status}</span>
}

function SearchBox({ value, onChange, placeholder }: { value: string; onChange: (value: string) => void; placeholder: string }) {
  return <label className="search-box"><Icon name="search" size={17} /><input value={value} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} /></label>
}

function EmptyState({ message }: { message: string }) {
  return <div className="empty-state"><Icon name="search" size={22} /><span>{message}</span></div>
}

function FarmerModal({ onClose, onCreate }: {
  onClose: () => void
  onCreate: (name: string, phoneNumber: string, supportAmount: number) => void
}) {
  const [name, setName] = useState('')
  const [phoneNumber, setPhoneNumber] = useState('')
  const [supportAmount, setSupportAmount] = useState('')
  const amount = Number(supportAmount)
  const canCreate = name.trim().length > 0 && phoneNumber.trim().length > 0 &&
    Number.isInteger(amount) && amount > 0 && amount <= 10_000_000

  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="modal" role="dialog" aria-modal="true" aria-labelledby="farmer-modal-title"><div className="modal-header"><div><span className="eyebrow">FARMER INVITATION</span><h2 id="farmer-modal-title">Add a farmer</h2></div><button className="icon-button" onClick={onClose} aria-label="Close"><Icon name="close" size={19} /></button></div><p className="modal-copy">Create the farmer record and initial support balance. The invite code is single-use and expires in 24 hours.</p><form onSubmit={(event) => { event.preventDefault(); if (canCreate) onCreate(name.trim(), phoneNumber.trim(), amount) }}>
    <label className="field-label">Farmer name<input value={name} onChange={(event) => setName(event.target.value)} maxLength={60} autoComplete="name" required /></label>
    <label className="field-label">Phone number<input type="tel" value={phoneNumber} onChange={(event) => setPhoneNumber(event.target.value)} maxLength={30} autoComplete="tel" required /></label>
    <label className="field-label">Support amount <span className="field-hint">NGN</span><div className="amount-input"><span>₦</span><input inputMode="numeric" type="number" min="1" max="10000000" step="1" placeholder="50,000" value={supportAmount} onChange={(event) => setSupportAmount(event.target.value)} required /></div></label>
    <div className="modal-actions"><button type="button" className="button button-secondary" onClick={onClose}>Cancel</button><button type="submit" className="button button-primary" disabled={!canCreate}><Icon name="plus" size={16} /> Create farmer and invite</button></div>
  </form></section></div>
}

function VoucherModal({ farmers, onClose, onCreate }: { farmers: Farmer[]; onClose: () => void; onCreate: (farmerId: string, amount: number, purpose: string, kind: 'Grant' | 'Loan') => void }) {
  const [farmerId, setFarmerId] = useState(farmers[0]?.id ?? '')
  const [amount, setAmount] = useState('')
  const [purpose, setPurpose] = useState('Seeds and fertilizer')
  const [kind, setKind] = useState<'Grant' | 'Loan'>('Grant')
  const amountValue = Number(amount)
  const canCreate = farmerId !== '' && amountValue > 0 && Number.isFinite(amountValue)

  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="modal" role="dialog" aria-modal="true" aria-labelledby="voucher-modal-title"><div className="modal-header"><div><span className="eyebrow">PROGRAM ALLOCATION</span><h2 id="voucher-modal-title">Create voucher</h2></div><button className="icon-button" onClick={onClose} aria-label="Close"><Icon name="close" size={19} /></button></div><p className="modal-copy">Record the award in the local NGO demo API, then pay dealer invoices from its balance. Grants are the default and never expect repayment.</p><form onSubmit={(event) => { event.preventDefault(); if (canCreate) onCreate(farmerId, amountValue, purpose, kind) }}>
    <label className="field-label">Farmer<select value={farmerId} onChange={(event) => setFarmerId(event.target.value)}>{farmers.map((farmer) => <option key={farmer.id} value={farmer.id}>{farmer.name} · {farmer.location}</option>)}</select></label>
    <div className="award-toggle" role="group" aria-label="Award type">
      <button type="button" className={kind === 'Grant' ? 'award-option active' : 'award-option'} onClick={() => setKind('Grant')}><strong>GRANT</strong><small>Credited outright. Unspent value never becomes a debt. Primary mode.</small></button>
      <button type="button" className={kind === 'Loan' ? 'award-option active loan' : 'award-option loan'} onClick={() => setKind('Loan')}><strong>LOAN</strong><small>Repayable support. The farmer's loan balance grows and must be repaid.</small></button>
    </div>
    <label className="field-label">Input category<select value={purpose} onChange={(event) => setPurpose(event.target.value)}><option>Seeds and fertilizer</option><option>Maize seed</option><option>Fertilizer</option><option>Land preparation</option><option>Irrigation supplies</option></select></label>
    <label className="field-label">Voucher value <span className="field-hint">NGN</span><div className="amount-input"><span>₦</span><input inputMode="numeric" type="number" min="1" step="1" placeholder="50,000" value={amount} onChange={(event) => setAmount(event.target.value)} required /></div></label>
    {amountValue > 0 && <div className="allocation-preview"><span>{kind} voucher value</span><strong>{naira(amountValue)}</strong><small>{kind === 'Grant' ? 'Redeemed value is written off — the farmer owes nothing.' : 'Redeemed value is expected to be repaid by the farmer.'}</small></div>}
    <div className="modal-actions"><button type="button" className="button button-secondary" onClick={onClose}>Cancel</button><button type="submit" className="button button-primary" disabled={!canCreate}><Icon name="plus" size={16} /> Create {kind.toLowerCase()} voucher</button></div>
  </form></section></div>
}

function PayModal({ vouchers, lnStatus, onClose, onSubmit }: {
  vouchers: Voucher[]; lnStatus: LnStatus | null; onClose: () => void; onSubmit: (voucherId: string, invoice: string) => void
}) {
  const activeVouchers = vouchers.filter((voucher) => voucher.status === 'Active' && voucher.remainingNgn > 0)
  const [voucherId, setVoucherId] = useState(activeVouchers[0]?.id ?? '')
  const [invoice, setInvoice] = useState('')
  const invoiceValue = invoice.trim()
  const rate = lnStatus?.ready ? lnStatus.rateNgnPerSat : null
  const canSubmit = voucherId !== '' && invoiceValue.length > 80 && rate !== null

  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><section className="modal" role="dialog" aria-modal="true" aria-labelledby="pay-modal-title"><div className="modal-header"><div><span className="eyebrow">MUTINYNET TEST NETWORK</span><h2 id="pay-modal-title">Request dealer payment</h2></div><button className="icon-button" onClick={onClose} aria-label="Close"><Icon name="close" size={19} /></button></div>
  <p className="modal-copy">{lnStatus?.ready ? `Paste the BOLT11 invoice from the vendor page. Payment is sent from the funder node on ${lnStatus.network}.` : 'Waiting for the Lightning node to finish bootstrapping.'}</p>
  <form onSubmit={(event) => { event.preventDefault(); if (canSubmit && rate !== null) onSubmit(voucherId, invoiceValue) }}>
    <label className="field-label">Voucher<select value={voucherId} onChange={(event) => setVoucherId(event.target.value)}>{activeVouchers.map((item) => <option key={item.id} value={item.id}>{item.id} · {item.purpose} · {naira(item.remainingNgn)} left</option>)}</select></label>
    <label className="field-label">Dealer BOLT11 invoice<textarea className="invoice-box" rows={4} value={invoice} onChange={(event) => setInvoice(event.target.value)} placeholder="lntbs…" spellCheck={false} /></label>
    <div className="modal-actions"><button type="button" className="button button-secondary" onClick={onClose}>Cancel</button><button type="submit" className="button button-primary" disabled={!canSubmit}><Icon name="arrow" size={16} /> Pay from funder node</button></div>
  </form></section></div>
}

export default App
