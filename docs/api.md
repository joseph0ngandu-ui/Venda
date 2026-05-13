# API

## Base URLs

Local backend:

- `http://localhost:3000/api/v1`

Current built-in fallback used by the app:

- `https://venda.kynto.me/api/v1`

iOS override order:

1. `VENDA_API_BASE_URL` environment variable
2. `VENDA_API_BASE_URL` Info.plist key
3. `API_BASE_URL` Info.plist key
4. `venda.api.base.url` in `UserDefaults`
5. Built-in fallback URL

Provide a full absolute URL that already includes `/api/v1`. No App Transport Security exception is checked in for plain local `http://` endpoints.

## Auth Endpoints

### `POST /auth/register`

Accepted request fields:

- `business_name`
- `owner_name`
- `business_type`
- `phone`
- `pin`

Request body:

```json
{
  "business_name": "Shop Name",
  "owner_name": "Jane Banda",
  "business_type": "Retail",
  "phone": "260...",
  "pin": "1234"
}
```

Success response:

```json
{
  "message": "Merchant registered successfully",
  "auth_type": "merchant",
  "company_code": "VND-1234ABCD",
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name",
    "business_type": "Retail",
    "phone": "260...",
    "currency": "ZMW",
    "company_code": "VND-1234ABCD"
  },
  "staff": {
    "id": "uuid",
    "merchant_id": "uuid",
    "name": "Owner",
    "role": "admin",
    "company_code": "VND-1234ABCD",
    "is_active": true
  },
  "permissions": {
    "can_manage_team": true,
    "can_create_staff": true
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
  "auth_type": "merchant",
  "company_code": "VND-1234ABCD",
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name",
    "business_type": "Retail",
    "phone": "260...",
    "currency": "ZMW",
    "company_code": "VND-1234ABCD"
  },
  "staff": {
    "id": "uuid",
    "name": "Owner",
    "role": "admin",
    "is_active": true
  },
  "token": "jwt"
}
```

### `POST /auth/join`

Alias: `POST /auth/staff/login`

Request body:

```json
{
  "company_code": "VND-1234ABCD",
  "pin": "1234"
}
```

Success response:

```json
{
  "message": "Staff login successful",
  "auth_type": "staff",
  "company_code": "VND-1234ABCD",
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name"
  },
  "staff": {
    "id": "uuid",
    "merchant_id": "uuid",
    "name": "Cashier One",
    "role": "cashier",
    "company_code": "VND-1234ABCD",
    "is_active": true
  },
  "permissions": {
    "can_manage_team": false,
    "can_rotate_own_pin": true
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
  "authenticated": true,
  "company_code": "VND-1234ABCD",
  "merchant": {
    "id": "uuid",
    "business_name": "Shop Name",
    "business_type": "Retail",
    "phone": "260...",
    "currency": "ZMW"
  },
  "staff": {
    "id": "uuid",
    "merchant_id": "uuid",
    "name": "Owner",
    "role": "admin",
    "company_code": "VND-1234ABCD",
    "is_active": true,
    "last_login_at": "timestamp",
    "pin_updated_at": "timestamp",
    "deactivated_at": null
  },
  "permissions": {
    "can_manage_team": true,
    "can_create_staff": true,
    "can_rotate_own_pin": true
  }
}
```

## Staff Endpoints

All staff endpoints require `Authorization: Bearer <jwt>`.

### `GET /staff`

Returns:

```json
{
  "company_code": "VND-1234ABCD",
  "permissions": {
    "can_manage_team": true,
    "can_create_staff": true,
    "can_rotate_any_pin": true
  },
  "summary": {
    "total": 3,
    "active": 2,
    "inactive": 1,
    "admins": 1,
    "managers": 0,
    "cashiers": 2
  },
  "staff": [
    {
      "id": "uuid",
      "merchant_id": "uuid",
      "name": "Owner",
      "role": "admin",
      "company_code": "VND-1234ABCD",
      "is_active": true,
      "status": "active",
      "last_login_at": "timestamp",
      "pin_updated_at": "timestamp",
      "deactivated_at": null,
      "is_current_user": true
    }
  ]
}
```

### `POST /staff`

Admin-only request body:

```json
{
  "name": "Chanda",
  "role": "cashier",
  "pin": "2468"
}
```

### `PATCH /staff/:staffId`

Admin-only. Supports any combination of:

```json
{
  "name": "Updated Name",
  "role": "manager",
  "is_active": true
}
```

### `POST /staff/:staffId/pin`

Admins may rotate any staff PIN:

```json
{
  "pin": "4321"
}
```

Non-admin staff may rotate only their own PIN and must include:

```json
{
  "current_pin": "1234",
  "pin": "4321"
}
```

### `POST /staff/:staffId/deactivate`

Admin-only. Deactivates the target staff record unless that would remove the last active admin.

## Product Endpoints

All product endpoints require `Authorization: Bearer <jwt>`.

- `GET /products`: returns active products and low-stock summary
- `POST /products`: manager/admin create
- `PATCH /products/:productId`: manager/admin update
- `DELETE /products/:productId`: manager/admin archive via `is_active = false`

Product payload fields mirror sync columns: `name`, `category`, `pricing_type`, `suggested_price`, `min_price`, `max_price`, `stock_quantity`, `low_stock_threshold`, `track_stock`, and `is_service`.

## Sales Endpoints

All sales endpoints require `Authorization: Bearer <jwt>`.

- `GET /sales`: returns recent sales for the merchant
- `POST /sales`: creates a completed sale, inserts line items, and decrements tracked stock transactionally

Checkout request:

```json
{
  "payment_method": "Cash",
  "customer_phone": "260...",
  "items": [
    {
      "product_id": "uuid",
      "quantity": 2,
      "final_price": 150
    }
  ]
}
```

## Money Endpoints

All money endpoints require `Authorization: Bearer <jwt>`.

- `GET /money`: returns mobile-money totals, credit totals, recent MoMo, and credit entries
- `POST /money/momo`: logs a mobile-money transaction
- `PATCH /money/momo/:momoId`: updates mobile-money status/linkage
- `POST /money/momo/:momoId/match`: matches a MoMo transaction to a sale
- `POST /money/credits`: creates a credit entry
- `POST /money/credits/:creditId/repay`: records a repayment and updates credit status

### `POST /staff/:staffId/reactivate`

Admin-only. Reactivates a previously disabled staff record.

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

Staff rows returned from `GET /sync/pull` now exclude `pin_hash`. Staff creation and PIN rotation should happen through the dedicated `/staff` endpoints rather than generic sync payloads.
