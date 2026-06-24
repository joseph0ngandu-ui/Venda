import { expect, test } from '@playwright/test';

const session = {
  token: 'test-token',
  token_type: 'Bearer',
  expires_at: '2099-01-01T00:00:00.000Z',
  auth_type: 'merchant',
  company_code: 'VENDA01',
  merchant: {
    id: 'merchant-1',
    business_name: 'Venda Market',
    business_type: 'Retail',
    phone: '+260970000000',
    currency: 'ZMW',
    company_code: 'VENDA01',
  },
  staff: {
    id: 'staff-1',
    merchant_id: 'merchant-1',
    name: 'Joseph Owner',
    role: 'admin',
    company_code: 'VENDA01',
    is_active: true,
    is_current_user: true,
  },
  user: {
    id: 'staff-1',
    merchant_id: 'merchant-1',
    name: 'Joseph Owner',
    role: 'admin',
    company_code: 'VENDA01',
    is_active: true,
    is_current_user: true,
  },
  permissions: {
    can_view_team: true,
    can_manage_team: true,
    can_create_staff: true,
    can_update_roles: true,
    can_rotate_any_pin: true,
    can_rotate_own_pin: true,
  },
};

const reports = {
  timeframe: 'week',
  generated_at: '2026-05-14T00:00:00.000Z',
  summary: { total_revenue: 120, sales_count: 2, average_sale: 60 },
  payment_breakdown: [{ method: 'Cash', amount: 120, sales_count: 2 }],
  top_products: [{ id: 'product-1', name: 'Rice', units_sold: 2, revenue: 120 }],
  trend: [{ label: 'Today', amount: 120, sales_count: 2, bucket: '2026-05-14' }],
  recent_sales: [],
};

const mockWorkspaceApi = async (page: import('@playwright/test').Page) => {
  let productRequests = 0;

  await page.route('**/api/v1/auth/me', async route => {
    await route.fulfill({
      json: {
        authenticated: true,
        auth_type: session.auth_type,
        company_code: session.company_code,
        merchant: session.merchant,
        staff: session.staff,
        user: session.user,
        permissions: session.permissions,
        session: { authenticated: true },
      },
    });
  });
  await page.route('**/api/v1/products', async route => {
    productRequests += 1;
    expect(route.request().headers().authorization).toBe('Bearer test-token');
    await route.fulfill({
      json: {
        summary: {},
        products: [
          {
            id: 'product-1',
            name: 'Rice',
            category: 'Pantry',
            pricing_type: 'fixed',
            suggested_price: 60,
            min_price: null,
            max_price: null,
            stock_quantity: 10,
            low_stock_threshold: 3,
            track_stock: true,
            is_service: false,
            is_active: true,
          },
        ],
      },
    });
  });
  await page.route('**/api/v1/sales', async route => route.fulfill({ json: { sales: [] } }));
  await page.route('**/api/v1/reports/summary**', async route => route.fulfill({ json: reports }));
  await page.route('**/api/v1/money', async route =>
    route.fulfill({
      json: {
        summary: {
          matched_momo: 0,
          pending_momo: 0,
          unmatched_momo: 0,
          outstanding_credit: 0,
          open_credit_customers: 0,
        },
        momo_transactions: [],
        credit_entries: [],
      },
    })
  );
  await page.route('**/api/v1/staff', async route => route.fulfill({ json: { staff: [session.staff], summary: {}, permissions: {} } }));

  await page.addInitScript(storedSession => {
    window.localStorage.setItem('venda.web.session', JSON.stringify(storedSession));
  }, session);

  return {
    productRequests: () => productRequests,
  };
};

test('renders installable Venda shell and manifest metadata', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'venda' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Set up my business' })).toBeVisible();

  const manifest = await page.evaluate(async () => {
    const response = await fetch('/manifest.webmanifest');
    return response.json();
  });

  expect(manifest.name).toBe('Venda');
  expect(manifest.display).toBe('standalone');
});

test('logged-in controls are reachable and keep the session token after profile refresh', async ({ page }) => {
  const apiState = await mockWorkspaceApi(page);

  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Point of Sale' })).toBeVisible();

  const requestsBeforeRefresh = apiState.productRequests();
  await page.getByRole('button', { name: 'Refresh workspace' }).click();
  await expect.poll(() => apiState.productRequests()).toBeGreaterThan(requestsBeforeRefresh);

  await page.getByRole('button', { name: 'Money' }).click();
  await page.getByRole('button', { name: 'Log MoMo' }).click();
  await expect(page.getByRole('dialog').getByRole('heading', { name: 'Log MoMo' })).toBeVisible();
  await page.getByRole('button', { name: 'Close' }).click();

  await page.getByRole('button', { name: 'Add credit' }).click();
  await expect(page.getByRole('dialog').getByRole('heading', { name: 'Add credit' })).toBeVisible();
  await page.getByRole('button', { name: 'Close' }).click();

  await page.getByRole('button', { name: /^(Settings|Me)$/ }).click();
  await expect(page.getByRole('heading', { name: 'Venda Market', level: 1 })).toBeVisible();
});
