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
            const items = {}
            for (const id of Object.keys(stored)) {
                items[id] = JSON.parse(stored[id])
            }
            res.json(items)
        } catch (err) {
            unavailable(res, err)
        }
    }

    async create (req, res) {
        const username = req.user.username
        try {
            const id = await this._incr(nextIdKey(username))
            const todo = {
                content: req.body.content,
                id: id
            }
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
