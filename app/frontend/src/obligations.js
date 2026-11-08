// Taxes the API accepts, with the label shown to users.
export const TAXES = [
  { code: 'iva', label: 'IVA' },
  { code: 'retencion', label: 'Retención en la fuente' },
  { code: 'renta', label: 'Renta' },
  { code: 'ica', label: 'ICA' }
]

export const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

export function taxLabel (code) {
  const tax = TAXES.find(item => item.code === code)
  return tax ? tax.label : 'Sin impuesto'
}

function pad (value) {
  return value < 10 ? '0' + value : '' + value
}

// Dates travel as YYYY-MM-DD and are read in the time zone of the browser.
export function toIsoDate (date) {
  return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate())
}

export function fromIsoDate (value) {
  const parts = value.split('-').map(Number)
  return new Date(parts[0], parts[1] - 1, parts[2])
}

export function today () {
  const now = new Date()
  return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

export function daysUntil (value) {
  return Math.round((fromIsoDate(value) - today()) / 86400000)
}

export function formatDate (value) {
  const date = fromIsoDate(value)
  return date.getDate() + ' ' + MONTHS[date.getMonth()] + ' ' + date.getFullYear()
}

// Returns the text and tone of the due chip of an obligation.
export function dueState (value) {
  if (!value) {
    return { text: 'Sin fecha', tone: 'quiet' }
  }
  const days = daysUntil(value)
  if (days < 0) {
    return { text: days === -1 ? 'Venció ayer' : 'Venció hace ' + -days + ' días', tone: 'overdue' }
  }
  if (days === 0) {
    return { text: 'Vence hoy', tone: 'soon' }
  }
  if (days === 1) {
    return { text: 'Vence mañana', tone: 'soon' }
  }
  return { text: 'Vence en ' + days + ' días', tone: days <= 7 ? 'soon' : 'quiet' }
}
