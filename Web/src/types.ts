export type StaffRole = 'admin' | 'manager' | 'cashier';

export type Permissions = {
  can_view_team: boolean;
  can_manage_team: boolean;
  can_create_staff: boolean;
  can_update_roles: boolean;
  can_rotate_any_pin: boolean;
  can_rotate_own_pin: boolean;
};

export type MerchantProfile = {
  id: string;
  business_name: string;
  business_type: string;
  phone: string;
  currency: string;
  company_code: string;
};

export type StaffProfile = {
  id: string;
  merchant_id: string;
  name: string;
  role: StaffRole;
  company_code: string;
  is_active: boolean;
  status?: 'active' | 'inactive';
  is_current_user?: boolean;
  last_login_at?: string | null;
  pin_updated_at?: string | null;
};

export type AuthSession = {
  token: string;
  token_type: string;
  expires_at: string;
  auth_type: 'merchant' | 'staff';
  company_code: string;
  merchant: MerchantProfile;
  staff: StaffProfile;
  user: StaffProfile;
  permissions: Permissions;
};

export type Product = {
  id: string;
  merchant_id?: string;
  name: string;
  category: string;
  pricing_type: 'fixed' | 'flexible' | 'range' | 'open' | 'service';
  suggested_price: number | null;
  min_price: number | null;
  max_price: number | null;
  stock_quantity: number;
  low_stock_threshold: number;
  track_stock: boolean;
  is_service: boolean;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
};

export type CartItem = {
  id: string;
  product: Product | null;
  name: string;
  category: string;
  quantity: number;
  finalPrice: number;
};

export type SaleLineItem = {
  id: string;
  sale_id: string;
  product_id: string | null;
  quantity: number;
  unit_price: number;
  original_price: number | null;
  final_price: number;
  discount_amount: number;
  discount_reason: string | null;
};

export type Sale = {
  id: string;
  reference: string;
  total_amount: number;
  payment_method: string;
  customer_phone: string | null;
  status: string;
  staff_name: string;
  created_at: string;
  line_items?: SaleLineItem[];
};

export type ReportsSummary = {
  timeframe: 'week' | 'month' | 'year';
  generated_at: string;
  summary: {
    total_revenue: number;
    sales_count: number;
    average_sale: number;
  };
  payment_breakdown: Array<{
    method: string;
    amount: number;
    sales_count: number;
  }>;
  top_products: Array<{
    id: string | null;
    name: string;
    units_sold: number;
    revenue: number;
  }>;
  trend: Array<{
    label: string;
    amount: number;
    sales_count: number;
    bucket: string;
  }>;
  recent_sales: Sale[];
};

export type MoneyState = {
  summary: {
    matched_momo: number;
    pending_momo: number;
    unmatched_momo: number;
    outstanding_credit: number;
    open_credit_customers: number;
  };
  momo_transactions: Array<{
    id: string;
    transaction_ref: string;
    sender_phone: string;
    amount: number;
    status: string;
    received_at: string | null;
  }>;
  credit_entries: Array<{
    id: string;
    customer_name: string;
    customer_phone: string | null;
    amount: number;
    amount_repaid: number;
    amount_owed: number;
    due_date: string | null;
    status: string;
  }>;
};
