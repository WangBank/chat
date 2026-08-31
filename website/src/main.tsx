import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { errorMessageStore } from './stores/error-message.store'

window.addEventListener('error', (event) => {
  errorMessageStore.add('网页运行时', event.message || '页面运行错误')
})

window.addEventListener('unhandledrejection', (event) => {
  const reason = event.reason instanceof Error ? event.reason.message : String(event.reason ?? '')
  if (reason.trim()) errorMessageStore.add('网页异步任务', reason)
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
