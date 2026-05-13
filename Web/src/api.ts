import type { AuthSession, MoneyState, Product, ReportsSummary, Sale, StaffProfile } from './types';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? '/api/v1';

type RequestOptions = {
  method?: string;
  token?: string;
  body?: unknown;
};

const buildUrl = (path: string) => {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${API_BASE_URL.replace(/\/$/, '')}${normalizedPath}`;
};

const request = async <T>(path: string, options: RequestOptions = {}): Promise<T> => {
  const response = await fetch(buildUrl(path), {
    method: options.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

  const payload = response.status === 204 ? null : await response.json().catch(() => null);

  if (!response.ok) {
    const message =
      payload && typeof payload === 'object' && 'error' in payload
        ? String((payload as { error: unknown }).error)
        : `Request failed with HTTP ${response.status}`;
    throw new Error(message);
  }

  return payload as T;
};

export const api = {
  register: (payload: {
    business_name: string;
    owner_name: string;
    business_type: string;
    phone: string;
    pin: string;
  }) => request<AuthSession>('/auth/register', { method: 'POST', body: payload }),
  login: (payload: { phone: string; pin: string }) =>
    request<AuthSession>('/auth/login', { method: 'POST', body: payload }),
  join: (payload: { company_code: string; pin: string }) =>
    request<AuthSession>('/auth/join', { method: 'POST', body: payload }),
  me: (token: string) => request<AuthSession>('/auth/me', { token }),
  products: (token: string) => request<{ summary: unknown; products: Product[] }>('/products', { token }),
  createProduct: (token: string, payload: Partial<Product>) =>
    request<{ product: Product }>('/products', { method: 'POST', token, body: payload }),
  updateProduct: (token: string, productId: string, payload: Partial<Product>) =>
    request<{ product: Product }>(`/products/${productId}`, { method: 'PATCH', token, body: payload }),
  deleteProduct: (token: string, productId: string) =>
    request<{ product: Product }>(`/products/${productId}`, { method: 'DELETE', token }),
  sales: (token: string) => request<{ sales: Sale[] }>('/sales', { token }),
  createSale: (
    token: string,
    payload: {
      payment_method: string;
      customer_phone?: string | null;
      notes?: string | null;
      items: Array<{
        product_id: string | null;
        quantity: number;
        final_price: number;
        original_price?: number | null;
      }>;
    }
  ) => request<{ sale: Sale }>('/sales', { method: 'POST', token, body: payload }),
  reports: (token: string, timeframe: 'week' | 'month' | 'year') =>
    request<ReportsSummary>(`/reports/summary?timeframe=${timeframe}`, { token }),
  money: (token: string) => request<MoneyState>('/money', { token }),
  createMoMo: (
    token: string,
    payload: { transaction_ref: string; sender_phone: string; amount: number; status?: string }
  ) => request('/money/momo', { method: 'POST', token, body: payload }),
  createCredit: (
    token: string,
    payload: { customer_name: string; customer_phone?: string; amount: number; due_date?: string | null }
  ) => request('/money/credits', { method: 'POST', token, body: payload }),
  repayCredit: (token: string, creditId: string, amount: number) =>
    request(`/money/credits/${creditId}/repay`, { method: 'POST', token, body: { amount } }),
  staff: (token: string) => request<{ staff: StaffProfile[]; summary: unknown; permissions: unknown }>('/staff', { token }),
  createStaff: (token: string, payload: { name: string; role: string; pin: string }) =>
    request<{ staff: StaffProfile }>('/staff', { method: 'POST', token, body: payload }),
};
