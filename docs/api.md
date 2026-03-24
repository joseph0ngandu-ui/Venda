# API

## Base URLs

Local backend:

- `http://localhost:3000/api/v1`

Current hosted URL used by the app:

- `https://homeserver.taildbc5d3.ts.net/api/v1`

## Auth Endpoints

### `POST /auth/register`

Request body:

```json
{
  "business_name": "Shop Name",
  "business_type": "Retail",
  "phone": "260...",
  "pin": "1234"
}
```

Success response:

```json
{
  "message": "Merchant registered successfully",
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name",
    "business_type": "Retail",
    "phone": "260..."
  },
  "token": "jwt"
}
```

### `POST /auth/login`

Request body:

```json
{
  "phone": "260...",
  "pin": "1234"
}
```

Success response:

```json
{
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name",
    "business_type": "Retail",
    "phone": "260...",
    "currency": "ZMW"
  },
  "token": "jwt"
}
```

### `GET /auth/me`

Headers:

```http
Authorization: Bearer <jwt>
```

Success response:

```json
{
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name",
    "business_type": "Retail",
    "phone": "260...",
    "currency": "ZMW",
    "created_at": "timestamp"
  }
}
```

## Sync Endpoints

### `POST /sync/push`

Headers:

```http
Authorization: Bearer <jwt>
Content-Type: application/json
```

Request shape:

```json
{
  "products": [],
  "sales": [],
  "sale_line_items": [],
  "momo_transactions": [],
  "credit_entries": [],
  "staff": []
}
```

Success response:

```json
{
  "success": true,
  "message": "Batch sync complete"
}
```

### `GET /sync/pull`

Query string:

- `updated_after=<ISO-8601 timestamp>`

Headers:

```http
Authorization: Bearer <jwt>
```

Success response shape:

```json
{
  "timestamp": "2026-03-24T00:00:00.000Z",
  "data": {
    "products": [],
    "sales": [],
    "sale_line_items": [],
    "staff": [],
    "momo_transactions": [],
    "credit_entries": []
  }
}
```
