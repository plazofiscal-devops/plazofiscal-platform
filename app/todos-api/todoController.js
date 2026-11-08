'use strict';
const {promisify} = require('util');

const OPERATION_CREATE = 'CREATE',
      OPERATION_DELETE = 'DELETE';

// Each user has a hash of items keyed by id, and a counter that hands out ids.
function itemsKey (username) {
    return 'todos:' + username
}

function nextIdKey (username) {
    return 'todos:' + username + ':next-id'
}

const TAXES = ['iva', 'retencion', 'renta', 'ica']

// Returns the obligation fields from a request body, or an error message.
function readObligation (body) {
    const client = typeof body.client === 'string' ? body.client.trim() : ''
    const note = typeof body.note === 'string' ? body.note.trim() : ''
    if (!client || client.length > 120) {
        return {error: 'client is required, up to 120 characters'}
    }
    if (TAXES.indexOf(body.tax) === -1) {
        return {error: 'tax must be one of ' + TAXES.join(', ')}
    }
    if (!isDate(body.dueDate)) {
        return {error: 'dueDate must be a date as YYYY-MM-DD'}
    }
    if (note.length > 500) {
        return {error: 'note is limited to 500 characters'}
    }
    return {obligation: {client: client, tax: body.tax, dueDate: body.dueDate, note: note}}
}

function isDate (value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
        return false
    }
    const date = new Date(value + 'T00:00:00Z')
    return !isNaN(date) && date.toISOString().slice(0, 10) === value
}

// Earliest due date first. Items with no due date go last, and ties keep creation order.
function byDueDate (a, b) {
    const left = a.dueDate || '9999-12-31'
    const right = b.dueDate || '9999-12-31'
    if (left !== right) {
        return left < right ? -1 : 1
    }
    return a.id - b.id
}

function unavailable (res, err) {
    console.log('redis error: ' + err.message)
    res.status(503).json({message: 'storage is unavailable, please try again later'})
}

class TodoController {
    constructor({tracer, redisClient, logChannel}) {
        this._tracer = tracer;
        this._redisClient = redisClient;
        this._logChannel = logChannel;
        this._hgetall = promisify(redisClient.hgetall).bind(redisClient);
        this._hset = promisify(redisClient.hset).bind(redisClient);
        this._hdel = promisify(redisClient.hdel).bind(redisClient);
        this._incr = promisify(redisClient.incr).bind(redisClient);
    }

    async list (req, res) {
        try {
            const stored = await this._hgetall(itemsKey(req.user.username)) || {}
            const items = Object.keys(stored).map(id => JSON.parse(stored[id]))
            items.sort(byDueDate)
            res.json(items)
        } catch (err) {
            unavailable(res, err)
        }
    }

    async create (req, res) {
        const username = req.user.username
        const {obligation, error} = readObligation(req.body || {})
        if (error) {
            return res.status(400).json({message: error})
        }
        try {
            const id = await this._incr(nextIdKey(username))
            const todo = Object.assign({id: id}, obligation)
            await this._hset(itemsKey(username), id, JSON.stringify(todo))
            this._logOperation(OPERATION_CREATE, username, id)
            res.json(todo)
        } catch (err) {
            unavailable(res, err)
        }
    }

    async delete (req, res) {
        const username = req.user.username
        const id = req.params.taskId
        try {
            await this._hdel(itemsKey(username), id)
            this._logOperation(OPERATION_DELETE, username, id)
            res.status(204)
            res.send()
        } catch (err) {
            unavailable(res, err)
        }
    }

    _logOperation (opName, username, todoId) {
        this._tracer.scoped(() => {
            const traceId = this._tracer.id;
            this._redisClient.publish(this._logChannel, JSON.stringify({
                zipkinSpan: traceId,
                opName: opName,
                username: username,
                todoId: todoId,
            }))
        })
    }
}

module.exports = TodoController
