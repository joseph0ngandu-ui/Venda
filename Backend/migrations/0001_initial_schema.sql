CREATE TABLE IF NOT EXISTS merchants (
    id UUID PRIMARY KEY,
    business_name VARCHAR(255) NOT NULL,
    business_type VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    pin_hash VARCHAR(255) NOT NULL,
    currency VARCHAR(10) DEFAULT 'ZMW',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staff (
    id UUID PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    pin_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE staff
    ADD COLUMN IF NOT EXISTS created_by_staff_id UUID REFERENCES staff(id) ON DELETE SET NULL;

ALTER TABLE staff
    ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE staff
    ADD COLUMN IF NOT EXISTS pin_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE staff
    ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMP WITH TIME ZONE;

UPDATE staff
SET pin_updated_at = COALESCE(pin_updated_at, created_at, CURRENT_TIMESTAMP)
WHERE pin_updated_at IS NULL;

UPDATE staff
SET deactivated_at = CASE
    WHEN is_active = FALSE AND deactivated_at IS NULL THEN updated_at
    ELSE deactivated_at
END
WHERE is_active = FALSE;

CREATE INDEX IF NOT EXISTS idx_staff_merchant_id ON staff(merchant_id);
CREATE INDEX IF NOT EXISTS idx_staff_merchant_active_role ON staff(merchant_id, is_active, role);

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    pricing_type VARCHAR(50) NOT NULL,
    suggested_price DECIMAL(12, 2),
    min_price DECIMAL(12, 2),
    max_price DECIMAL(12, 2),
    stock_quantity INTEGER DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 5,
    track_stock BOOLEAN DEFAULT TRUE,
    is_service BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
    reference VARCHAR(50) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    customer_phone VARCHAR(20),
    status VARCHAR(50) DEFAULT 'completed',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(merchant_id, reference)
);

CREATE TABLE IF NOT EXISTS sale_line_items (
    id UUID PRIMARY KEY,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    quantity DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    original_price DECIMAL(12, 2),
    final_price DECIMAL(12, 2) NOT NULL,
    discount_amount DECIMAL(12, 2) DEFAULT 0,
    discount_reason VARCHAR(255),
    price_override_by VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS momo_transactions (
    id UUID PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
    transaction_ref VARCHAR(100) NOT NULL,
    sender_phone VARCHAR(20) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'unmatched',
    received_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(merchant_id, transaction_ref)
);

CREATE TABLE IF NOT EXISTS credit_entries (
    id UUID PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    sale_id UUID REFERENCES sales(id) ON DELETE CASCADE,
    customer_name VARCHAR(255) NOT NULL,
    customer_phone VARCHAR(20),
    amount DECIMAL(12, 2) NOT NULL,
    amount_repaid DECIMAL(12, 2) DEFAULT 0,
    due_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'outstanding',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    server_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['merchants', 'staff', 'products', 'sales', 'sale_line_items', 'momo_transactions', 'credit_entries']
    LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS server_updated_at TIMESTAMP WITH TIME ZONE', t);
        EXECUTE format('UPDATE %I SET server_updated_at = COALESCE(server_updated_at, updated_at, created_at, CURRENT_TIMESTAMP) WHERE server_updated_at IS NULL', t);
        EXECUTE format('ALTER TABLE %I ALTER COLUMN server_updated_at SET DEFAULT CURRENT_TIMESTAMP', t);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    NEW.server_updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DO $$
DECLARE
    t text;
BEGIN
    FOR t IN
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name IN ('merchants', 'staff', 'products', 'sales', 'sale_line_items', 'momo_transactions', 'credit_entries')
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS update_%I_updated_at ON %I;
            CREATE TRIGGER update_%I_updated_at
            BEFORE UPDATE ON %I
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
        ', t, t, t, t);
    END LOOP;
END;
$$;
