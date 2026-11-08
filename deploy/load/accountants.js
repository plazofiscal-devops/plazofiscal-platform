// Simulates accountants during a filing window. Most requests list obligations,
// some create one and mark it as presented, and a few sign in again.
import http from 'k6/http'
import { check } from 'k6'

const BASE_URL = __ENV.BASE_URL || 'http://frontend:8080'
// A seeded demonstration user of the sign-in service.
const USERNAME = __ENV.LOAD_USERNAME || 'janed'
const PASSWORD = __ENV.LOAD_PASSWORD || 'ddd'
const TAXES = ['iva', 'retencion', 'renta', 'ica']

export const options = {
  scenarios: {
    accountants: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 15),
      timeUnit: '1s',
      duration: __ENV.DURATION || '3m',
      preAllocatedVUs: 20,
      maxVUs: 60
    }
  },
  thresholds: {
    http_req_failed: ['rate==0'],
    checks: ['rate==1']
  }
}

function signIn () {
  const response = http.post(`${BASE_URL}/login`,
    JSON.stringify({ username: USERNAME, password: PASSWORD }),
    { headers: { 'Content-Type': 'application/json' }, tags: { name: 'sign-in' } })
  check(response, { 'sign-in returns 200': r => r.status === 200 })
  return response.json('accessToken')
}

export function setup () {
  return { token: signIn() }
}

export default function (data) {
  const headers = { Authorization: `Bearer ${data.token}`, 'Content-Type': 'application/json' }
  const roll = Math.random()

  if (roll < 0.05) {
    signIn()
    return
  }

  if (roll < 0.20) {
    const due = new Date(Date.now() + Math.floor(Math.random() * 60) * 86400000).toISOString().slice(0, 10)
    const created = http.post(`${BASE_URL}/todos`, JSON.stringify({
      client: 'Load test client',
      tax: TAXES[Math.floor(Math.random() * TAXES.length)],
      dueDate: due
    }), { headers, tags: { name: 'create' } })
    check(created, { 'create returns 200': r => r.status === 200 })
    if (created.status === 200) {
      const presented = http.del(`${BASE_URL}/todos/${created.json('id')}`, null, { headers, tags: { name: 'present' } })
      check(presented, { 'present returns 204': r => r.status === 204 })
    }
    return
  }

  const listed = http.get(`${BASE_URL}/todos`, { headers, tags: { name: 'list' } })
  check(listed, { 'list returns 200': r => r.status === 200 })
}
