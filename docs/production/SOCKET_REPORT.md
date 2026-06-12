# Socket.io Report

## Connection

- **Path**: `/ws` (not default `/socket.io`)
- **Auth**: JWT in `handshake.auth.token` (required)
- **CORS**: `CORS_ORIGINS`; null origin blocked in production by default

## Auto-Joined Rooms

| Room | Pattern |
|------|---------|
| Personal | `user:{userId}` |
| Role | `role:{admin\|customer\|delivery}` |
| Broadcast | `public` |

## Client → Server Events

| Event | Auth | Purpose |
|-------|------|---------|
| `ping` | JWT | Health check |
| `join_customer_room` | JWT customer | `customer_{userId}` |
| `join_admin_room` | JWT admin | `admin_room` |
| `join_delivery_room` | JWT delivery | `delivery_{userId}` |
| `rider_location` | JWT delivery | GPS update |

## Server → Client Events (key)

| Event | Rooms | Trigger |
|-------|-------|---------|
| `order:status_updated` | customer, admin | Order state change |
| `delivery:location` | customer | Rider GPS |
| `order:assigned` | rider, admin | Assignment |
| `notification:new` | role-based | Push event |
| `catalog:products_changed` | public | Admin catalog update |

## Reconnect Flow

Client (Flutter `SocketService`) reconnects with fresh JWT. Server re-joins default rooms on connect.

## Nginx Requirements

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection 'upgrade';
proxy_read_timeout 86400;
```

## Known Limitations

- Rider location cache is in-memory (lost on restart)
- Notifications stored in-memory Map
