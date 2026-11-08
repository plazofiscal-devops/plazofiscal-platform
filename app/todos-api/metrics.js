'use strict';
const client = require('prom-client');
const {promisify} = require('util');

const register = new client.Registry();
client.collectDefaultMetrics({register});

const obligationsCreated = new client.Counter({
    name: 'plazofiscal_obligations_created_total',
    help: 'Obligations registered, by tax.',
    labelNames: ['tax'],
    registers: [register],
});

const obligationsDeleted = new client.Counter({
    name: 'plazofiscal_obligations_deleted_total',
    help: 'Obligations removed.',
    registers: [register],
});

const requestDuration = new client.Histogram({
    name: 'plazofiscal_http_request_duration_seconds',
    help: 'Duration of the HTTP requests served by the obligations service.',
    labelNames: ['method', 'route', 'status'],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
    registers: [register],
});

// Today in the time zone of the business, as YYYY-MM-DD.
function today () {
    return new Intl.DateTimeFormat('en-CA', {timeZone: 'America/Bogota'}).format(new Date())
}

function addDays (date, days) {
    const value = new Date(date + 'T00:00:00Z')
    value.setUTCDate(value.getUTCDate() + days)
    return value.toISOString().slice(0, 10)
}

// Counts every stored obligation by due status each time Prometheus scrapes. The pilot holds a few thousand at most.
function watchObligations (redisClient) {
    const scan = promisify(redisClient.scan).bind(redisClient)
    const hgetall = promisify(redisClient.hgetall).bind(redisClient)
    new client.Gauge({
        name: 'plazofiscal_obligations',
        help: 'Stored obligations by due status and tax. Due soon means within the next 7 days.',
        labelNames: ['status', 'tax'],
        registers: [register],
        async collect () {
            const now = today()
            const soon = addDays(now, 7)
            const counts = {}
            let cursor = '0'
            do {
                const [next, keys] = await scan(cursor, 'MATCH', 'todos:*', 'COUNT', 200)
                cursor = next
                for (const key of keys.filter(k => !k.endsWith(':next-id'))) {
                    const items = await hgetall(key) || {}
                    for (const raw of Object.values(items)) {
                        const item = JSON.parse(raw)
                        const status = item.dueDate < now ? 'overdue' : item.dueDate <= soon ? 'due_soon' : 'later'
                        const label = status + '|' + (item.tax || 'none')
                        counts[label] = (counts[label] || 0) + 1
                    }
                }
            } while (cursor !== '0')
            this.reset()
            for (const [label, value] of Object.entries(counts)) {
                const [status, tax] = label.split('|')
                this.set({status, tax}, value)
            }
        },
    })
}

// Records the duration of every request once the response is sent, labelled by the matched route.
function timeRequests (req, res, next) {
    const end = requestDuration.startTimer()
    res.on('finish', function () {
        const route = req.route ? req.baseUrl + req.route.path : 'unmatched'
        end({method: req.method, route: route, status: String(res.statusCode)})
    })
    next()
}

module.exports = {register, obligationsCreated, obligationsDeleted, watchObligations, timeRequests}
