import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'

const rootElement = document.getElementById('root')
if (!rootElement) throw new Error('Application root element is missing.')

const root = createRoot(rootElement)
if (window.location.pathname.replace(/\/$/, '') === '/dealer') {
  void import('./DealerPage.tsx').then(({ default: DealerPage }) => {
    root.render(<StrictMode><DealerPage /></StrictMode>)
  })
} else {
  void import('./App.tsx').then(({ default: App }) => {
    root.render(<StrictMode><App /></StrictMode>)
  })
}
