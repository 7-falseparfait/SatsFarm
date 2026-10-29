import { useEffect, useState, type FormEvent } from 'react'
import { QRCodeSVG } from 'qrcode.react'
import { decode } from '@gandlaf21/bolt11-decode'
import './dealer.css'

const API_URL = import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:8787'
const RATE_STEP_NGN = 5
const DECODER_URL = 'https://www.lndecoder.com/'

type Invoice = {
  id: string
  invoice: string
  amountNgn: number
  status: 'Pending' | 'Received' | 'Expired' | 'Failed'
}

type Settlement = {
  id: string
  amountNgn: number
  amountSats: number
  status: 'Pending' | 'Received' | 'Expired' | 'Failed'
  createdAt: number
  invoice: string
  paymentHash: string | null
  preimage: string | null
}

type DemoDealer = {
  slug: string
  name: string
  dealerKey: string
}

class DealerApiError extends Error {
  readonly status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

async function dealerRequest<T>(path: string, key: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      'X-Dealer-Key': key,
      ...init?.headers,
    },
  })
  if (!response.ok) {
    const body = await response.json().catch(() => ({})) as { error?: string }
    throw new DealerApiError(body.error ?? 'Could not complete the request.', response.status)
  }
  return response.json() as Promise<T>
}

const naira = (amount: number) => new Intl.NumberFormat('en-NG', {
  style: 'currency',
  currency: 'NGN',
  maximumFractionDigits: 0,
}).format(amount)

const when = (epoch: number) => new Date(epoch * 1000).toLocaleString('en-GB', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
})

const abbr = (value: string) => `${value.slice(0, 10)}…${value.slice(-8)}`

function decodeBoltToolStrip(invoice: string) {
  const asHex = (value: unknown): string | null => {
    if (typeof value === 'string') return value
    const bytes = (value as { type?: string; data?: number[] })?.type === 'Buffer'
      ? (value as { data: number[] }).data
      : Array.isArray(value)
        ? value as number[]
        : null
    return bytes
      ? bytes.map((byte) => byte.toString(16).padStart(2, '0')).join('')
      : null
  }
  try {
    const details = decode(invoice) as { sections?: Array<{ name: string; value?: unknown }> }
    const section = (name: string) => details.sections?.find((item) => item.name === name)?.value
    return {
      amountMsat: section('amount') ?? null,
      paymentHashHex: asHex(section('payment_hash')),
      expirySeconds: section('expiry') ?? null,
    }
  } catch {
    return { amountMsat: null, paymentHashHex: null, expirySeconds: null }
  }
}

function SettlementDetails({ settlement }: { settlement: Settlement }) {
  const [copied, setCopied] = useState('')
  const decoded = decodeBoltToolStrip(settlement.invoice)
  async function copy(field: string, value: string) {
    try {
      await navigator.clipboard.writeText(value)
      setCopied(field)
      window.setTimeout(() => setCopied(''), 1800)
    } catch {
      setCopied('')
    }
  }
  return <>
    <ul className="dealer-proof-list">
      <li>
        <span>Payment hash</span>
        <button type="button" onClick={() => settlement.paymentHash && void copy('hash', settlement.paymentHash)}>
          {settlement.paymentHash ? abbr(settlement.paymentHash) : '—'} {copied === 'hash' ? '(copied)' : ''}
        </button>
      </li>
      {settlement.preimage && <li>
        <span>Preimage (proof of payment)</span>
        <button type="button" onClick={() => void copy('preimage', settlement.preimage ?? '')}>
          {abbr(settlement.preimage)} {copied === 'preimage' ? '(copied)' : ''}
        </button>
      </li>}
      <li>
        <span>Amount</span>
        <strong>
          {Number(decoded.amountMsat ?? settlement.amountSats * 1000) / 1000} sats
        </strong>
      </li>
      {decoded.expirySeconds != null && <li><span>Invoice expiry</span><strong>{Number(decoded.expirySeconds)}s</strong></li>}
    </ul>
    {settlement.preimage && <p className="dealer-proof-note">
      Preimage-hash link (hash of preimage equals the invoice payment hash) proves settlement.
    </p>}
    <a
      className="dealer-explorer-link"
      href={DECODER_URL}
      target="_blank"
      rel="noreferrer"
    >Inspect invoice in BOLT11 decoder ↗</a>
    {settlement.paymentHash && <button
      className="dealer-proof-link-button"
      type="button"
      onClick={() => void copy('prooflink', `${API_URL}/api/ln/payment/${settlement.paymentHash}`)}
    >
      {copied === 'prooflink' ? 'Proof link copied' : 'Copy public payment-proof link'}
    </button>}
  </>
}

function DealerPage() {
  const [initialKey] = useState(() => new URLSearchParams(window.location.search).get('key')?.trim() ?? '')
  const [requestedDealerSlug] = useState(() => new URLSearchParams(window.location.search).get('dealer'))
  const [key, setKey] = useState(initialKey)
  const [demoDealers, setDemoDealers] = useState<DemoDealer[]>([])
  const [authorized, setAuthorized] = useState(false)
  const [checking, setChecking] = useState(true)
  const [amount, setAmount] = useState('')
  const [invoice, setInvoice] = useState<Invoice | null>(null)
  const [page, setPage] = useState<'amount' | 'waiting' | 'result'>('amount')
  const [history, setHistory] = useState<Settlement[]>([])
  const [error, setError] = useState('')
  const [pollError, setPollError] = useState('')
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    document.title = 'SatsFarm | Dealer'
  }, [])

  useEffect(() => {
    let active = true
    void dealerRequest<DemoDealer[]>('/api/dealers/demo', '').then((dealers) => {
      if (!active) return
      setDemoDealers(dealers)
      if (!initialKey && requestedDealerSlug) {
        const selected = dealers.find((dealer) => dealer.slug === requestedDealerSlug)
        if (selected) {
          setKey(selected.dealerKey)
        } else {
          setError('Demo dealer was not found.')
          setChecking(false)
        }
      }
      if (!initialKey && !requestedDealerSlug) setChecking(false)
    }).catch((requestError: unknown) => {
      if (!active) return
      setError(requestError instanceof Error ? requestError.message : 'Could not load demo dealers.')
      setChecking(false)
    })
    return () => { active = false }
  }, [initialKey, requestedDealerSlug])

  useEffect(() => {
    let active = true
    if (!key) return () => { active = false }

    void dealerRequest<{ ok: boolean }>('/api/dealers/verify', key, { method: 'POST' })
      .then(() => {
        if (active) {
          setAuthorized(true)
          setError('')
        }
      })
      .catch((requestError: unknown) => {
        if (!active) return
        setError(requestError instanceof DealerApiError && requestError.status === 403
          ? 'Not a registered dealer.'
          : requestError instanceof Error
            ? requestError.message
            : 'Could not verify dealer access.')
      })
      .finally(() => { if (active) setChecking(false) })

    return () => { active = false }
  }, [key])

  useEffect(() => {
    if (!authorized || !key) return
    let active = true

    void dealerRequest<Settlement[]>('/api/dealers/invoices/history', key)
      .then((rows) => { if (active) setHistory(rows) })
      .catch(() => { if (active) setHistory([]) })

    return () => { active = false }
  }, [authorized, key, page])

  useEffect(() => {
    if (page !== 'waiting' || !invoice || !key) return
    let active = true
    let timeout: number | undefined

    const poll = async () => {
      try {
        const status = await dealerRequest<Pick<Invoice, 'id' | 'amountNgn' | 'status'>>(
          `/api/dealers/invoices/${encodeURIComponent(invoice.id)}`,
          key,
        )
        if (!active) return
        setPollError('')
        if (status.status === 'Received' || status.status === 'Expired' || status.status === 'Failed') {
          setInvoice((current) => current ? { ...current, status: status.status } : current)
          setPage('result')
          return
        }
      } catch (requestError) {
        if (!active) return
        if (requestError instanceof DealerApiError && requestError.status === 403) {
          setAuthorized(false)
          setError('Not a registered dealer.')
          setPage('amount')
          return
        }
        setPollError('Could not check payment. Retrying…')
      }
      timeout = window.setTimeout(() => { void poll() }, 2000)
    }

    void poll()
    return () => {
      active = false
      if (timeout !== undefined) window.clearTimeout(timeout)
    }
  }, [invoice, key, page])

  const amountValue = Number(amount)
  const canCreate = Number.isSafeInteger(amountValue)
    && amountValue >= RATE_STEP_NGN
    && amountValue <= 500_000
    && amountValue % RATE_STEP_NGN === 0

  async function createPayment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!canCreate) return
    setError('')
    try {
      const created = await dealerRequest<Invoice>('/api/dealers/invoices', key, {
        method: 'POST',
        body: JSON.stringify({ amountNgn: amountValue }),
      })
      setInvoice(created)
      setPage('waiting')
      setPollError('')
    } catch (requestError) {
      if (requestError instanceof DealerApiError && requestError.status === 403) {
        setAuthorized(false)
        setError('Not a registered dealer.')
      } else {
        setError(requestError instanceof Error ? requestError.message : 'Could not create the payment.')
      }
    }
  }

  async function copyInvoice() {
    if (!invoice) return
    try {
      await navigator.clipboard.writeText(invoice.invoice)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      setError('Could not copy the payment invoice. Please scan the QR code instead.')
    }
  }

  function startNewSale() {
    setInvoice(null)
    setAmount('')
    setError('')
    setPollError('')
    setPage('amount')
  }

  const received = invoice?.status === 'Received'

  function chooseDemoDealer(dealer: DemoDealer) {
    setKey(dealer.dealerKey)
    setError('')
    setChecking(true)
    window.history.replaceState(null, '', `/dealer?key=${encodeURIComponent(dealer.dealerKey)}`)
  }

  return <main className="dealer-shell">
    <header className="dealer-header">
      <div className="dealer-brand" aria-label="SatsFarm dealer">
        <span className="dealer-mark">S</span>
        <span><strong>SatsFarm</strong><small>DEALER PAYMENTS</small></span>
      </div>
      <span className="dealer-network">MUTINYNET TEST NETWORK</span>
    </header>

    <section className="dealer-card">
      {checking
        ? <p className="dealer-message" role="status">Checking dealer access…</p>
        : !authorized
          ? !key && demoDealers.length > 0
            ? <div className="dealer-amount-view">
              <span className="dealer-eyebrow">MUTINYNET DEMO</span>
              <h1>Choose your shop</h1>
              <p className="dealer-subtitle">Select a registered demo dealer to start a sale.</p>
              <div className="dealer-options">{demoDealers.map((dealer) => <button
                className="dealer-option"
                key={dealer.slug}
                onClick={() => chooseDemoDealer(dealer)}
              ><span className="dealer-option-icon">▣</span><span><strong>{dealer.name}</strong><small>Open dealer payments</small></span><span className="dealer-option-arrow">›</span></button>)}</div>
              {error && <p className="dealer-inline-error" role="alert">{error}</p>}
            </div>
            : <div className="dealer-access-error" role="alert">
              <span className="dealer-error-mark">!</span>
              <h1>{error === 'Not a registered dealer.' ? error : 'Dealer page unavailable'}</h1>
              <p>{error || 'This vendor link is invalid or has been replaced.'}</p>
            </div>
          : page === 'amount'
            ? <div className="dealer-amount-view">
              <span className="dealer-eyebrow">NEW SALE</span>
              <h1>Enter sale amount</h1>
              <p className="dealer-subtitle">Create a Mutinynet test-network payment request.</p>
              <form onSubmit={(event) => void createPayment(event)}>
                <label className="dealer-amount-label" htmlFor="sale-amount">Amount in naira</label>
                <div className="dealer-amount-input"><span>₦</span><input
                  id="sale-amount"
                  autoFocus
                  inputMode="numeric"
                  type="number"
                  min="5"
                  max="500000"
                  step="5"
                  placeholder="0"
                  value={amount}
                  onChange={(event) => setAmount(event.target.value)}
                  required
                /></div>
                <button className="dealer-primary-button" type="submit" disabled={!canCreate}>Create payment</button>
                <p className="dealer-hint">Enter an amount between ₦5 and ₦500,000.</p>
              </form>
              {error && <p className="dealer-inline-error" role="alert">{error}</p>}
            </div>
            : page === 'waiting' && invoice
              ? <div className="dealer-waiting-view">
                <span className="dealer-eyebrow">PAYMENT REQUEST</span>
                <h1>{naira(invoice.amountNgn)}</h1>
                <div className="dealer-qr"><QRCodeSVG value={invoice.invoice} size={232} level="M" includeMargin /></div>
                <p className="dealer-waiting-label"><span className="dealer-spinner" />Waiting for payment</p>
                <button className="dealer-copy-button" type="button" onClick={() => void copyInvoice()}>{copied ? 'Invoice copied' : 'Copy invoice'}</button>
                {pollError && <p className="dealer-poll-error" role="status">{pollError}</p>}
              </div>
              : <div className={`dealer-result-view${received ? ' is-received' : ' is-failed'}`}>
                <span className="dealer-result-icon">{received ? '✓' : '!'}</span>
                <h1>{received ? 'Received' : invoice?.status === 'Expired' ? 'Payment expired' : 'Payment not completed'}</h1>
                <strong className="dealer-result-amount">{naira(invoice?.amountNgn ?? amountValue)}</strong>
                <p>{received ? 'Payment confirmed on Mutinynet test network.' : 'The payment could not be completed. Create a new payment to try again.'}</p>
                <button className="dealer-primary-button" type="button" onClick={startNewSale}>{received ? 'New sale' : 'Try again'}</button>
                {received && (() => {
                  const settlement = history.find((row) => row.id === invoice?.id)
                  return settlement && settlement.preimage
                    ? <div className="dealer-evidence">
                      <span className="dealer-eyebrow">SETTLEMENT EVIDENCE</span>
                      <SettlementDetails settlement={settlement} />
                    </div>
                    : null
                })()}
                {history.length > 0 && <section className="dealer-recent">
                  <span className="dealer-eyebrow">RECENT SALES</span>
                  <ul className="dealer-history">
                    {history.map((row) => {
                      const settled = row.status === 'Received' && row.preimage
                      return <li key={row.id} className={settled ? 'is-settled' : ''}>
                        <span className="dealer-history-when">{when(row.createdAt)}</span>
                        <strong>{naira(row.amountNgn)}</strong>
                        <span className={`dealer-status${settled ? ' is-ok' : ''}`}>{row.status}</span>
                        {settled && row.paymentHash && row.preimage && <span
                          className="dealer-hash"
                          title={`hash ${row.paymentHash} · preimage ${row.preimage}`}
                        >{abbr(row.preimage)}</span>}
                      </li>
                    })}
                  </ul>
                </section>}
              </div>}
    </section>
    <footer className="dealer-footer">Payments run on Mutinynet test network only.</footer>
  </main>
}

export default DealerPage
