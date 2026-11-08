# Obligations API

This Node.js service creates, lists and deletes the obligations of each signed-in user. It keeps no data in its own memory. Every item lives in Redis, so any replica answers the same and a release loses nothing. Each create and delete also publishes a message on a Redis channel, which `log-message-processor` turns into the activity trail.

## Endpoints

| Method and path | Effect | Answer |
|---|---|---|
| `GET /todos` | Lists the obligations of the user, earliest due date first | 200 with an array |
| `POST /todos` | Creates an obligation | 200 with the new obligation, or 400 when a field is invalid |
| `DELETE /todos/:taskId` | Removes an obligation once it is presented | 204 |
| `GET /health` | Liveness, true while the process runs | 200 |
| `GET /ready` | Readiness, true while Redis answers | 200, or 503 when Redis is unreachable |

Every path except `/health` and `/ready` needs a token from the sign-in service in the `Authorization: Bearer` header. When Redis fails during a request, the answer is 503 and the process keeps running.

An obligation looks like this.

```json
{"id": 3, "client": "Ferreteria El Tornillo", "tax": "iva", "dueDate": "2026-11-12", "note": "Bimonthly return"}
```

| Field | Rule |
|---|---|
| `client` | Required, up to 120 characters |
| `tax` | One of `iva`, `retencion`, `renta` and `ica`, for value added tax, withholding, income tax and the municipal industry and commerce tax |
| `dueDate` | Required, a calendar date written as `YYYY-MM-DD` |
| `note` | Optional, up to 500 characters |

The list is sorted when it is read, by due date and then by creation order. Items saved before obligations had a due date appear last.

## Storage

| Redis key | Type | Content |
|---|---|---|
| `todos:<username>` | Hash | One field per item id, with the item as JSON |
| `todos:<username>:next-id` | String | Counter that hands out ids with `INCR` |

`INCR`, `HSET` and `HDEL` are atomic, so two replicas never hand out the same id or overwrite each other.

The activity message looks like this.

```json
{"opName": "CREATE", "username": "admin", "todoId": 3, "zipkinSpan": {}}
```

## Configuration

| Variable | Meaning |
|---|---|
| `JWT_SECRET` | Key that verifies tokens, shared with the sign-in and users services. The service refuses to start without it |
| `TODO_API_PORT` | Port to listen on, 8082 by default |
| `REDIS_HOST` and `REDIS_PORT` | Address of Redis |
| `REDIS_CHANNEL` | Channel for activity messages |
| `ZIPKIN_URL` | Endpoint that receives traces |

The service retries Redis while it starts, since Redis and the network policies can refuse a new pod for a few seconds.

## Running

The platform builds and deploys this service with `make up` from the repository root. To run it alone against a local Redis, use this.

```bash
npm ci
JWT_SECRET=<key> REDIS_HOST=127.0.0.1 node server.js
```
