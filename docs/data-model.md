# Data Model

## Shared Business Entities

Both the iOS Core Data model and the backend PostgreSQL schema cover the same business concepts:

- merchant
- staff
- product
- sale
- sale line item
- mobile money transaction
- credit entry

## iOS Core Data Model

Source:

- `Venda/Models/VendaModel.xcdatamodeld/VendaModel.xcdatamodel/contents`

Entities defined in the app:

- `Merchant`
- `Staff`
- `Product`
- `Sale`
- `SaleLineItem`
- `MoMoTransaction`
- `CreditEntry`

Common attributes across entities:

- `id`
- `createdAt`
- `updatedAt`
- `syncedAt`

Important entity-specific fields:

- `Merchant`: business name, business type, phone, currency, pin
- `Staff`: name, role, pin, active status
- `Product`: pricing type, suggested/min/max price, stock quantity, service flag
- `Sale`: reference, payment method, customer phone, total amount, status
- `SaleLineItem`: quantity, unit price, final price, discount fields
- `MoMoTransaction`: transaction reference, sender phone, amount, status, received date
- `CreditEntry`: customer identity, amount owed, amount repaid, due date, status

## Backend PostgreSQL Schema

Source:

- `Backend/migrations/0001_initial_schema.sql`

Tables created by the checked-in bootstrap schema:

- `merchants`
- `staff`
- `products`
- `sales`
- `sale_line_items`
- `momo_transactions`
- `credit_entries`

Shared schema patterns:

- UUID primary keys
- foreign keys for merchant, sale, and product relationships
- `created_at` and `updated_at` timestamps
- update triggers to keep `updated_at` fresh

Key uniqueness rules:

- `merchants.phone` is unique
- `sales` enforces unique `(merchant_id, reference)`
- `momo_transactions` enforces unique `(merchant_id, transaction_ref)`

## Mapping Notes

- The Core Data model includes `updatedAt` for local mutation tracking and `syncedAt` for client-side sync bookkeeping.
- The backend schema uses `updated_at` for mutation timestamps and `server_updated_at` as the internal incremental-sync propagation cursor.
- Entity naming is conceptually aligned between app and backend, but not every UI flow writes into Core Data or sync payloads yet.
- Staff roles are normalized to `admin`, `manager`, and `cashier` in current app/backend responses, while compatibility code still maps legacy `owner` values to `admin`.
