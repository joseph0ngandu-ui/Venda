import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import {
  Banknote,
  BarChart3,
  BookOpen,
  Boxes,
  Check,
  ChevronRight,
  CircleDollarSign,
  CreditCard,
  Home,
  LogOut,
  Menu,
  PackagePlus,
  Plus,
  ReceiptText,
  Search,
  Settings,
  ShieldCheck,
  Smartphone,
  Trash2,
  UserPlus,
  Users,
  X,
} from 'lucide-react';
import type { AuthSession, CartItem, MoneyState, Product, ReportsSummary, Sale, StaffProfile } from './types';
import { api } from './api';
import {
  cartTotal,
  defaultSalePrice,
  formatDateTime,
  formatZmw,
  initialsFor,
  isLowStock,
  normalizeCompanyCode,
  productDisplayPrice,
} from './utils';

type TabKey = 'sell' | 'stock' | 'money' | 'reports' | 'team' | 'settings';
type OnboardingView = 'welcome' | 'register' | 'pin' | 'firstProduct' | 'login' | 'join';
type Timeframe = 'week' | 'month' | 'year';

type RegistrationDraft = {
  business_name: string;
  owner_name: string;
  business_type: string;
  phone: string;
};

const SESSION_KEY = 'venda.web.session';
const paymentMethods = ['Cash', 'MTN MoMo', 'Airtel Money', 'Bank Transfer', 'Credit'];

const loadStoredSession = () => {
  try {
    const rawSession = localStorage.getItem(SESSION_KEY);
    return rawSession ? (JSON.parse(rawSession) as AuthSession) : null;
  } catch {
    return null;
  }
};

const persistSession = (session: AuthSession | null) => {
  if (session) {
    localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  } else {
    localStorage.removeItem(SESSION_KEY);
  }
};

const makeDraftProduct = (): Partial<Product> => ({
  name: '',
  category: '',
  pricing_type: 'fixed',
  suggested_price: 0,
  min_price: null,
  max_price: null,
  stock_quantity: 0,
  low_stock_threshold: 5,
  track_stock: true,
  is_service: false,
});

function App() {
  const [session, setSessionState] = useState<AuthSession | null>(() => loadStoredSession());
  const [activeTab, setActiveTab] = useState<TabKey>('sell');
  const [products, setProducts] = useState<Product[]>([]);
  const [sales, setSales] = useState<Sale[]>([]);
  const [reports, setReports] = useState<ReportsSummary | null>(null);
  const [money, setMoney] = useState<MoneyState | null>(null);
  const [staff, setStaff] = useState<StaffProfile[]>([]);
  const [timeframe, setTimeframe] = useState<Timeframe>('week');
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  const token = session?.token;

  const setSession = useCallback((nextSession: AuthSession | null) => {
    persistSession(nextSession);
    setSessionState(nextSession);
  }, []);

  const notify = useCallback((message: string) => {
    setToast(message);
    window.setTimeout(() => setToast(null), 2600);
  }, []);

  const loadWorkspace = useCallback(
    async (nextTimeframe = timeframe) => {
      if (!token) {
        return;
      }

      setIsLoading(true);
      setError(null);

      try {
        const [productResponse, saleResponse, reportResponse, moneyResponse, staffResponse] = await Promise.all([
          api.products(token),
          api.sales(token),
          api.reports(token, nextTimeframe),
          api.money(token),
          api.staff(token).catch(() => ({ staff: [] })),
        ]);

        setProducts(productResponse.products);
        setSales(saleResponse.sales);
        setReports(reportResponse);
        setMoney(moneyResponse);
        setStaff(staffResponse.staff);
      } catch (requestError) {
        setError(requestError instanceof Error ? requestError.message : 'Unable to load workspace');
      } finally {
        setIsLoading(false);
      }
    },
    [timeframe, token]
  );

  useEffect(() => {
    if (!token) {
      return;
    }

    api
      .me(token)
      .then(verifiedSession => {
        setSession(verifiedSession);
        void loadWorkspace();
      })
      .catch(() => {
        setSession(null);
      });
  }, [loadWorkspace, setSession, token]);

  const refreshReports = async (nextTimeframe: Timeframe) => {
    if (!token) {
      return;
    }

    setTimeframe(nextTimeframe);
    const reportResponse = await api.reports(token, nextTimeframe);
    setReports(reportResponse);
  };

  const handleCreateProduct = async (payload: Partial<Product>) => {
    if (!token) {
      return;
    }

    const response = await api.createProduct(token, payload);
    setProducts(current => [response.product, ...current]);
    notify('Product saved');
  };

  const handleUpdateProduct = async (productId: string, payload: Partial<Product>) => {
    if (!token) {
      return;
    }

    const response = await api.updateProduct(token, productId, payload);
    setProducts(current => current.map(product => (product.id === productId ? response.product : product)));
    notify('Product updated');
  };

  const handleDeleteProduct = async (productId: string) => {
    if (!token) {
      return;
    }

    await api.deleteProduct(token, productId);
    setProducts(current => current.filter(product => product.id !== productId));
    notify('Product archived');
  };

  const handleCheckout = async (paymentMethod: string, customerPhone?: string) => {
    if (!token || cartItems.length === 0) {
      return;
    }

    const response = await api.createSale(token, {
      payment_method: paymentMethod,
      customer_phone: customerPhone || null,
      items: cartItems.map(item => ({
        product_id: item.product?.id ?? null,
        quantity: item.quantity,
        final_price: item.finalPrice,
        original_price: item.product?.suggested_price ?? item.finalPrice,
      })),
    });

    setCartItems([]);
    setSales(current => [response.sale, ...current]);
    notify(`Sale ${response.sale.reference} completed`);
    await loadWorkspace();
  };

  const addToCart = (product: Product, price = defaultSalePrice(product), quantity = 1) => {
    setCartItems(current => [
      ...current,
      {
        id: crypto.randomUUID(),
        product,
        name: product.name,
        category: product.category,
        quantity,
        finalPrice: price,
      },
    ]);
  };

  const addManualItem = (name: string, category: string, finalPrice: number, quantity: number) => {
    setCartItems(current => [
      ...current,
      {
        id: crypto.randomUUID(),
        product: null,
        name,
        category: category || 'Manual item',
        quantity,
        finalPrice,
      },
    ]);
  };

  const logout = () => {
    setSession(null);
    setProducts([]);
    setSales([]);
    setReports(null);
    setMoney(null);
    setStaff([]);
    setCartItems([]);
  };

  if (!session) {
    return (
      <Onboarding
        onAuthenticated={nextSession => {
          setSession(nextSession);
          setActiveTab('sell');
        }}
      />
    );
  }

  return (
    <div className="app-shell">
      <DesktopRail
        activeTab={activeTab}
        onChange={setActiveTab}
        session={session}
      />
      <main className="workspace">
        <TopBar session={session} onRefresh={() => loadWorkspace()} isLoading={isLoading} />
        {error ? <InlineNotice tone="danger" message={error} onDismiss={() => setError(null)} /> : null}
        {activeTab === 'sell' ? (
          <SellScreen
            products={products}
            cartItems={cartItems}
            sales={sales}
            onAddToCart={addToCart}
            onAddManualItem={addManualItem}
            onRemoveCartItem={itemId => setCartItems(current => current.filter(item => item.id !== itemId))}
            onCheckout={handleCheckout}
          />
        ) : null}
        {activeTab === 'stock' ? (
          <StockScreen
            products={products}
            canManage={session.permissions.can_manage_team}
            onCreate={handleCreateProduct}
            onUpdate={handleUpdateProduct}
            onDelete={handleDeleteProduct}
          />
        ) : null}
        {activeTab === 'money' ? (
          <MoneyScreen
            money={money}
            token={token}
            onRefresh={() => loadWorkspace()}
          />
        ) : null}
        {activeTab === 'reports' ? (
          <ReportsScreen
            reports={reports}
            timeframe={timeframe}
            onTimeframeChange={refreshReports}
          />
        ) : null}
        {activeTab === 'team' ? (
          <TeamScreen
            staff={staff}
            session={session}
            token={token}
            onRefresh={() => loadWorkspace()}
          />
        ) : null}
        {activeTab === 'settings' ? <SettingsScreen session={session} onLogout={logout} /> : null}
      </main>
      <MobileTabs activeTab={activeTab} onChange={setActiveTab} />
      {toast ? <div className="toast">{toast}</div> : null}
    </div>
  );
}

function Onboarding({ onAuthenticated }: { onAuthenticated: (session: AuthSession) => void }) {
  const [view, setView] = useState<OnboardingView>('welcome');
  const [registrationDraft, setRegistrationDraft] = useState<RegistrationDraft | null>(null);
  const [pendingSession, setPendingSession] = useState<AuthSession | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const runAction = async (action: () => Promise<void>) => {
    setIsSubmitting(true);
    setError(null);

    try {
      await action();
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to complete request');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <main className="onboarding">
      <section className="onboarding-panel">
        {view === 'welcome' ? (
          <WelcomeScreen
            onRegister={() => setView('register')}
            onJoin={() => setView('join')}
            onLogin={() => setView('login')}
          />
        ) : null}
        {view === 'register' ? (
          <RegisterScreen
            onBack={() => setView('welcome')}
            onNext={draft => {
              setRegistrationDraft(draft);
              setView('pin');
            }}
          />
        ) : null}
        {view === 'pin' && registrationDraft ? (
          <PinSetupScreen
            isSubmitting={isSubmitting}
            onBack={() => setView('register')}
            onSubmit={pin =>
              runAction(async () => {
                const session = await api.register({ ...registrationDraft, pin });
                setPendingSession(session);
                setView('firstProduct');
              })
            }
          />
        ) : null}
        {view === 'firstProduct' && pendingSession ? (
          <FirstProductScreen
            isSubmitting={isSubmitting}
            onSkip={() => onAuthenticated(pendingSession)}
            onSubmit={product =>
              runAction(async () => {
                await api.createProduct(pendingSession.token, product);
                onAuthenticated(pendingSession);
              })
            }
          />
        ) : null}
        {view === 'login' ? (
          <LoginScreen
            isSubmitting={isSubmitting}
            onBack={() => setView('welcome')}
            onSubmit={(phone, pin) =>
              runAction(async () => {
                onAuthenticated(await api.login({ phone, pin }));
              })
            }
          />
        ) : null}
        {view === 'join' ? (
          <JoinScreen
            isSubmitting={isSubmitting}
            onBack={() => setView('welcome')}
            onSubmit={(companyCode, pin) =>
              runAction(async () => {
                onAuthenticated(await api.join({ company_code: normalizeCompanyCode(companyCode), pin }));
              })
            }
          />
        ) : null}
        {error ? <InlineNotice tone="danger" message={error} onDismiss={() => setError(null)} /> : null}
      </section>
    </main>
  );
}

function WelcomeScreen({
  onRegister,
  onJoin,
  onLogin,
}: {
  onRegister: () => void;
  onJoin: () => void;
  onLogin: () => void;
}) {
  return (
    <div className="welcome-screen">
      <div className="welcome-logo">
        <img src="/venda-logo.png" alt="" />
        <h1>venda</h1>
        <p>Run your business from your phone.</p>
      </div>
      <div className="feature-stack">
        <FeaturePill icon={<ReceiptText />} label="Track every sale" />
        <FeaturePill icon={<CreditCard />} label="Cash and mobile money" />
        <FeaturePill icon={<BarChart3 />} label="See what is working" />
      </div>
      <div className="welcome-actions">
        <Button tone="inverse" onClick={onRegister}>
          Set up my business
        </Button>
        <Button tone="glass" onClick={onJoin}>
          Join existing business
        </Button>
        <button className="link-button light" onClick={onLogin}>
          I already have an account
        </button>
      </div>
    </div>
  );
}

function RegisterScreen({
  onBack,
  onNext,
}: {
  onBack: () => void;
  onNext: (draft: RegistrationDraft) => void;
}) {
  const [businessName, setBusinessName] = useState('');
  const [ownerName, setOwnerName] = useState('');
  const [businessType, setBusinessType] = useState('Retail');
  const [phone, setPhone] = useState('');

  const submit = (event: FormEvent) => {
    event.preventDefault();
    onNext({
      business_name: businessName,
      owner_name: ownerName,
      business_type: businessType,
      phone,
    });
  };

  return (
    <FormScreen title="Your business" subtitle="Create the owner workspace." onBack={onBack}>
      <form className="form-stack" onSubmit={submit}>
        <TextField label="Business name" value={businessName} onChange={setBusinessName} required />
        <TextField label="Owner name" value={ownerName} onChange={setOwnerName} required />
        <TextField label="Phone" value={phone} onChange={setPhone} inputMode="tel" required />
        <SelectField
          label="Business type"
          value={businessType}
          onChange={setBusinessType}
          options={['Retail', 'Services', 'Food and drink', 'Salon', 'Market stall', 'Other']}
        />
        <Button type="submit" icon={<ChevronRight />}>
          Continue
        </Button>
      </form>
    </FormScreen>
  );
}

function PinSetupScreen({
  onBack,
  onSubmit,
  isSubmitting,
}: {
  onBack: () => void;
  onSubmit: (pin: string) => void;
  isSubmitting: boolean;
}) {
  const [pin, setPin] = useState('');

  return (
    <FormScreen title="Secure PIN" subtitle="Use this PIN to sign in." onBack={onBack}>
      <form
        className="form-stack"
        onSubmit={event => {
          event.preventDefault();
          onSubmit(pin);
        }}
      >
        <TextField label="PIN" value={pin} onChange={setPin} inputMode="numeric" type="password" required />
        <Button type="submit" disabled={pin.length < 4 || isSubmitting} icon={<ShieldCheck />}>
          Create workspace
        </Button>
      </form>
    </FormScreen>
  );
}

function FirstProductScreen({
  onSubmit,
  onSkip,
  isSubmitting,
}: {
  onSubmit: (product: Partial<Product>) => void;
  onSkip: () => void;
  isSubmitting: boolean;
}) {
  return (
    <FormScreen title="First product" subtitle="Start with one thing you sell.">
      <ProductEditor
        initialProduct={makeDraftProduct()}
        submitLabel="Finish setup"
        isSubmitting={isSubmitting}
        onSubmit={onSubmit}
      />
      <button className="link-button" onClick={onSkip}>
        Skip for now
      </button>
    </FormScreen>
  );
}

function LoginScreen({
  onBack,
  onSubmit,
  isSubmitting,
}: {
  onBack: () => void;
  onSubmit: (phone: string, pin: string) => void;
  isSubmitting: boolean;
}) {
  const [phone, setPhone] = useState('');
  const [pin, setPin] = useState('');

  return (
    <FormScreen title="Welcome back" subtitle="Sign in as the owner." onBack={onBack}>
      <form
        className="form-stack"
        onSubmit={event => {
          event.preventDefault();
          onSubmit(phone, pin);
        }}
      >
        <TextField label="Phone" value={phone} onChange={setPhone} inputMode="tel" required />
        <TextField label="PIN" value={pin} onChange={setPin} inputMode="numeric" type="password" required />
        <Button type="submit" disabled={isSubmitting} icon={<ShieldCheck />}>
          Sign in
        </Button>
      </form>
    </FormScreen>
  );
}

function JoinScreen({
  onBack,
  onSubmit,
  isSubmitting,
}: {
  onBack: () => void;
  onSubmit: (companyCode: string, pin: string) => void;
  isSubmitting: boolean;
}) {
  const [companyCode, setCompanyCode] = useState('');
  const [pin, setPin] = useState('');

  return (
    <FormScreen title="Join business" subtitle="Use the company code and PIN." onBack={onBack}>
      <form
        className="form-stack"
        onSubmit={event => {
          event.preventDefault();
          onSubmit(companyCode, pin);
        }}
      >
        <TextField label="Company code" value={companyCode} onChange={setCompanyCode} required />
        <TextField label="PIN" value={pin} onChange={setPin} inputMode="numeric" type="password" required />
        <Button type="submit" disabled={isSubmitting} icon={<Users />}>
          Join workspace
        </Button>
      </form>
    </FormScreen>
  );
}

function SellScreen({
  products,
  cartItems,
  sales,
  onAddToCart,
  onAddManualItem,
  onRemoveCartItem,
  onCheckout,
}: {
  products: Product[];
  cartItems: CartItem[];
  sales: Sale[];
  onAddToCart: (product: Product, price?: number, quantity?: number) => void;
  onAddManualItem: (name: string, category: string, price: number, quantity: number) => void;
  onRemoveCartItem: (itemId: string) => void;
  onCheckout: (paymentMethod: string, customerPhone?: string) => Promise<void>;
}) {
  const [search, setSearch] = useState('');
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [manualOpen, setManualOpen] = useState(false);
  const filteredProducts = products.filter(product => {
    const query = search.toLowerCase();
    return (
      product.is_active &&
      (!query || product.name.toLowerCase().includes(query) || product.category.toLowerCase().includes(query))
    );
  });

  return (
    <section className="screen-grid sell-layout">
      <div className="primary-pane">
        <ScreenHeader title="Point of Sale" subtitle="Search products, add to cart, and checkout quickly." />
        <MetricGrid>
          <MetricCard label="Products" value={String(products.filter(product => product.is_active).length)} detail="Ready to sell" icon={<Boxes />} tone="forest" />
          <MetricCard label="In cart" value={String(cartItems.length)} detail="Queued items" icon={<ReceiptText />} tone="ochre" />
          <MetricCard label="Checkout" value={formatZmw(cartTotal(cartItems))} detail="Current total" icon={<CircleDollarSign />} tone="ember" />
        </MetricGrid>
        <SearchField value={search} onChange={setSearch} placeholder="Search products" />
        <div className="product-grid">
          {filteredProducts.map(product => (
            <button className="product-tile" key={product.id} onClick={() => setSelectedProduct(product)}>
              <span className={`tile-icon ${product.is_service ? 'ochre' : 'forest'}`}>
                {product.is_service ? <Smartphone /> : <Boxes />}
              </span>
              <Badge>{product.pricing_type}</Badge>
              <strong>{product.name}</strong>
              <span>{product.category}</span>
              <b>{productDisplayPrice(product)}</b>
            </button>
          ))}
          <button className="product-tile manual" onClick={() => setManualOpen(true)}>
            <span className="tile-icon ochre">
              <Plus />
            </span>
            <strong>Manual item</strong>
            <span>Add something not in stock</span>
          </button>
        </div>
      </div>
      <aside className="side-pane cart-pane">
        <CartPanel
          cartItems={cartItems}
          recentSales={sales.slice(0, 5)}
          onRemove={onRemoveCartItem}
          onCheckout={onCheckout}
        />
      </aside>
      {selectedProduct ? (
        <PriceModal
          product={selectedProduct}
          onClose={() => setSelectedProduct(null)}
          onAdd={(price, quantity) => {
            onAddToCart(selectedProduct, price, quantity);
            setSelectedProduct(null);
          }}
        />
      ) : null}
      {manualOpen ? (
        <ManualItemModal
          onClose={() => setManualOpen(false)}
          onAdd={(name, category, price, quantity) => {
            onAddManualItem(name, category, price, quantity);
            setManualOpen(false);
          }}
        />
      ) : null}
    </section>
  );
}

function StockScreen({
  products,
  canManage,
  onCreate,
  onUpdate,
  onDelete,
}: {
  products: Product[];
  canManage: boolean;
  onCreate: (payload: Partial<Product>) => Promise<void>;
  onUpdate: (productId: string, payload: Partial<Product>) => Promise<void>;
  onDelete: (productId: string) => Promise<void>;
}) {
  const [search, setSearch] = useState('');
  const [editorProduct, setEditorProduct] = useState<Product | null>(null);
  const [showCreate, setShowCreate] = useState(false);
  const filteredProducts = products.filter(product => {
    const query = search.toLowerCase();
    return !query || product.name.toLowerCase().includes(query) || product.category.toLowerCase().includes(query);
  });

  return (
    <section className="screen-stack">
      <div className="screen-title-row">
        <ScreenHeader title="Inventory" subtitle={`${products.length} products`} />
        {canManage ? (
          <IconButton label="Add product" onClick={() => setShowCreate(true)}>
            <Plus />
          </IconButton>
        ) : null}
      </div>
      <MetricGrid>
        <MetricCard label="Active" value={String(products.filter(product => product.is_active).length)} detail="In catalog" icon={<Boxes />} tone="forest" />
        <MetricCard label="Low stock" value={String(products.filter(isLowStock).length)} detail="Needs attention" icon={<PackagePlus />} tone="ember" />
        <MetricCard label="Services" value={String(products.filter(product => product.is_service).length)} detail="Non-stock items" icon={<Smartphone />} tone="ochre" />
      </MetricGrid>
      <SearchField value={search} onChange={setSearch} placeholder="Search products" />
      <div className="data-list">
        {filteredProducts.map(product => (
          <button className="list-row" key={product.id} onClick={() => setEditorProduct(product)}>
            <span className={`row-icon ${isLowStock(product) ? 'ember' : 'forest'}`}>
              <Boxes />
            </span>
            <span className="row-main">
              <strong>{product.name}</strong>
              <span>{product.category}</span>
            </span>
            <span className="row-meta">
              <b>{productDisplayPrice(product)}</b>
              <small>{product.track_stock && !product.is_service ? `${product.stock_quantity} in stock` : product.pricing_type}</small>
            </span>
          </button>
        ))}
      </div>
      {showCreate ? (
        <Modal title="Add product" onClose={() => setShowCreate(false)}>
          <ProductEditor
            initialProduct={makeDraftProduct()}
            submitLabel="Add product"
            onSubmit={async product => {
              await onCreate(product);
              setShowCreate(false);
            }}
          />
        </Modal>
      ) : null}
      {editorProduct ? (
        <Modal title="Edit product" onClose={() => setEditorProduct(null)}>
          <ProductEditor
            initialProduct={editorProduct}
            submitLabel="Save changes"
            onSubmit={async product => {
              await onUpdate(editorProduct.id, product);
              setEditorProduct(null);
            }}
          />
          {canManage ? (
            <Button tone="danger" icon={<Trash2 />} onClick={() => onDelete(editorProduct.id)}>
              Archive product
            </Button>
          ) : null}
        </Modal>
      ) : null}
    </section>
  );
}

function MoneyScreen({
  money,
  token,
  onRefresh,
}: {
  money: MoneyState | null;
  token?: string;
  onRefresh: () => Promise<void> | void;
}) {
  const [showMomo, setShowMomo] = useState(false);
  const [showCredit, setShowCredit] = useState(false);

  return (
    <section className="screen-stack">
      <div className="screen-title-row">
        <ScreenHeader title="Money" subtitle="Mobile money and credit health" />
        <div className="button-row">
          <IconButton label="Log MoMo" onClick={() => setShowMomo(true)}>
            <Smartphone />
          </IconButton>
          <IconButton label="Add credit" onClick={() => setShowCredit(true)}>
            <BookOpen />
          </IconButton>
        </div>
      </div>
      <MetricGrid>
        <MetricCard label="Matched MoMo" value={formatZmw(money?.summary.matched_momo ?? 0)} detail={`${money?.momo_transactions.filter(item => item.status === 'matched').length ?? 0} transactions`} icon={<Check />} tone="forest" />
        <MetricCard label="Pending MoMo" value={formatZmw(money?.summary.pending_momo ?? 0)} detail="Needs matching" icon={<Smartphone />} tone="ochre" />
        <MetricCard label="Outstanding Credit" value={formatZmw(money?.summary.outstanding_credit ?? 0)} detail={`${money?.summary.open_credit_customers ?? 0} customers`} icon={<BookOpen />} tone="ember" />
      </MetricGrid>
      <div className="two-column">
        <Panel title="Recent MoMo">
          <div className="data-list compact">
            {(money?.momo_transactions ?? []).map(transaction => (
              <div className="list-row static" key={transaction.id}>
                <span className="row-icon forest">
                  <Smartphone />
                </span>
                <span className="row-main">
                  <strong>{transaction.transaction_ref}</strong>
                  <span>{transaction.sender_phone}</span>
                </span>
                <span className="row-meta">
                  <b>{formatZmw(transaction.amount)}</b>
                  <small>{transaction.status}</small>
                </span>
              </div>
            ))}
          </div>
        </Panel>
        <Panel title="Credit Book">
          <div className="data-list compact">
            {(money?.credit_entries ?? []).map(entry => (
              <div className="list-row static" key={entry.id}>
                <span className="row-icon ochre">
                  <BookOpen />
                </span>
                <span className="row-main">
                  <strong>{entry.customer_name}</strong>
                  <span>{entry.status}</span>
                </span>
                <span className="row-meta">
                  <b>{formatZmw(entry.amount_owed)}</b>
                  <small>{entry.due_date ? formatDateTime(entry.due_date) : 'No due date'}</small>
                </span>
              </div>
            ))}
          </div>
        </Panel>
      </div>
      {showMomo && token ? (
        <MoMoModal token={token} onClose={() => setShowMomo(false)} onSaved={onRefresh} />
      ) : null}
      {showCredit && token ? (
        <CreditModal token={token} onClose={() => setShowCredit(false)} onSaved={onRefresh} />
      ) : null}
    </section>
  );
}

function ReportsScreen({
  reports,
  timeframe,
  onTimeframeChange,
}: {
  reports: ReportsSummary | null;
  timeframe: Timeframe;
  onTimeframeChange: (timeframe: Timeframe) => Promise<void>;
}) {
  const maxTrend = Math.max(...(reports?.trend.map(point => point.amount) ?? [1]), 1);

  return (
    <section className="screen-stack">
      <div className="screen-title-row">
        <ScreenHeader title="Reports" subtitle="Revenue, payments, and products" />
        <Segmented
          value={timeframe}
          options={[
            ['week', 'Week'],
            ['month', 'Month'],
            ['year', 'Year'],
          ]}
          onChange={value => onTimeframeChange(value as Timeframe)}
        />
      </div>
      <MetricGrid>
        <MetricCard label="Revenue" value={formatZmw(reports?.summary.total_revenue ?? 0)} detail={`${reports?.summary.sales_count ?? 0} sales`} icon={<Banknote />} tone="forest" />
        <MetricCard label="Average sale" value={formatZmw(reports?.summary.average_sale ?? 0)} detail="Basket value" icon={<ReceiptText />} tone="ochre" />
        <MetricCard label="Payment methods" value={String(reports?.payment_breakdown.length ?? 0)} detail="In use" icon={<CreditCard />} tone="ember" />
      </MetricGrid>
      <Panel title="Trend">
        <div className="trend-chart">
          {(reports?.trend ?? []).map(point => (
            <div className="trend-column" key={point.bucket}>
              <span style={{ height: `${Math.max(8, (point.amount / maxTrend) * 100)}%` }} />
              <small>{point.label}</small>
            </div>
          ))}
        </div>
      </Panel>
      <div className="two-column">
        <Panel title="Payment mix">
          <div className="data-list compact">
            {(reports?.payment_breakdown ?? []).map(item => (
              <div className="list-row static" key={item.method}>
                <span className="row-icon forest">
                  <CreditCard />
                </span>
                <span className="row-main">
                  <strong>{item.method}</strong>
                  <span>{item.sales_count} sales</span>
                </span>
                <span className="row-meta">
                  <b>{formatZmw(item.amount)}</b>
                </span>
              </div>
            ))}
          </div>
        </Panel>
        <Panel title="Top products">
          <div className="data-list compact">
            {(reports?.top_products ?? []).map(item => (
              <div className="list-row static" key={item.id ?? item.name}>
                <span className="row-icon ochre">
                  <Boxes />
                </span>
                <span className="row-main">
                  <strong>{item.name}</strong>
                  <span>{item.units_sold} sold</span>
                </span>
                <span className="row-meta">
                  <b>{formatZmw(item.revenue)}</b>
                </span>
              </div>
            ))}
          </div>
        </Panel>
      </div>
    </section>
  );
}

function TeamScreen({
  staff,
  session,
  token,
  onRefresh,
}: {
  staff: StaffProfile[];
  session: AuthSession;
  token?: string;
  onRefresh: () => Promise<void> | void;
}) {
  const [showCreate, setShowCreate] = useState(false);

  return (
    <section className="screen-stack">
      <div className="screen-title-row">
        <ScreenHeader title="Team" subtitle={`${session.company_code} staff directory`} />
        {session.permissions.can_create_staff ? (
          <IconButton label="Add staff" onClick={() => setShowCreate(true)}>
            <UserPlus />
          </IconButton>
        ) : null}
      </div>
      <MetricGrid>
        <MetricCard label="Active" value={String(staff.filter(member => member.is_active).length)} detail="Can sign in" icon={<Users />} tone="forest" />
        <MetricCard label="Admins" value={String(staff.filter(member => member.role === 'admin').length)} detail="Full access" icon={<ShieldCheck />} tone="ochre" />
        <MetricCard label="Cashiers" value={String(staff.filter(member => member.role === 'cashier').length)} detail="POS access" icon={<ReceiptText />} tone="ember" />
      </MetricGrid>
      {staff.length === 0 ? (
        <EmptyState title="Team access is limited" detail="Managers and admins can view the staff directory." icon={<Users />} />
      ) : (
        <div className="data-list">
          {staff.map(member => (
            <div className="list-row static" key={member.id}>
              <span className="avatar">{initialsFor(member.name)}</span>
              <span className="row-main">
                <strong>{member.name}</strong>
                <span>{member.is_current_user ? 'Current user' : member.status ?? 'active'}</span>
              </span>
              <span className="row-meta">
                <Badge>{member.role}</Badge>
                <small>{member.last_login_at ? formatDateTime(member.last_login_at) : 'No login yet'}</small>
              </span>
            </div>
          ))}
        </div>
      )}
      {showCreate && token ? (
        <StaffModal
          token={token}
          onClose={() => setShowCreate(false)}
          onSaved={onRefresh}
        />
      ) : null}
    </section>
  );
}

function SettingsScreen({ session, onLogout }: { session: AuthSession; onLogout: () => void }) {
  return (
    <section className="screen-stack">
      <ProfileCard session={session} />
      <MetricGrid>
        <MetricCard label="Session" value="Active" detail={session.merchant.phone} icon={<ShieldCheck />} tone="forest" />
        <MetricCard label="Role" value={session.staff.role} detail={session.staff.name} icon={<Users />} tone="ochre" />
        <MetricCard label="Company" value={session.company_code} detail={session.merchant.business_name} icon={<Home />} tone="ember" />
      </MetricGrid>
      <Panel title="Account">
        <div className="settings-list">
          <span>Business</span>
          <b>{session.merchant.business_name}</b>
          <span>Type</span>
          <b>{session.merchant.business_type}</b>
          <span>Currency</span>
          <b>{session.merchant.currency}</b>
        </div>
      </Panel>
      <Button tone="danger" icon={<LogOut />} onClick={onLogout}>
        Sign Out
      </Button>
    </section>
  );
}

function ProductEditor({
  initialProduct,
  submitLabel,
  onSubmit,
  isSubmitting = false,
}: {
  initialProduct: Partial<Product>;
  submitLabel: string;
  onSubmit: (product: Partial<Product>) => Promise<void> | void;
  isSubmitting?: boolean;
}) {
  const [name, setName] = useState(initialProduct.name ?? '');
  const [category, setCategory] = useState(initialProduct.category ?? '');
  const [pricingType, setPricingType] = useState<Product['pricing_type']>(initialProduct.pricing_type ?? 'fixed');
  const [suggestedPrice, setSuggestedPrice] = useState(String(initialProduct.suggested_price ?? ''));
  const [minPrice, setMinPrice] = useState(String(initialProduct.min_price ?? ''));
  const [maxPrice, setMaxPrice] = useState(String(initialProduct.max_price ?? ''));
  const [stockQuantity, setStockQuantity] = useState(String(initialProduct.stock_quantity ?? 0));
  const [isService, setIsService] = useState(Boolean(initialProduct.is_service));

  return (
    <form
      className="form-stack"
      onSubmit={event => {
        event.preventDefault();
        onSubmit({
          name,
          category,
          pricing_type: pricingType,
          suggested_price: suggestedPrice ? Number(suggestedPrice) : null,
          min_price: minPrice ? Number(minPrice) : null,
          max_price: maxPrice ? Number(maxPrice) : null,
          stock_quantity: Number(stockQuantity || 0),
          low_stock_threshold: initialProduct.low_stock_threshold ?? 5,
          track_stock: !isService,
          is_service: isService || pricingType === 'service',
        });
      }}
    >
      <TextField label="Product name" value={name} onChange={setName} required />
      <TextField label="Category" value={category} onChange={setCategory} required />
      <SelectField
        label="Pricing"
        value={pricingType}
        onChange={value => setPricingType(value as Product['pricing_type'])}
        options={['fixed', 'flexible', 'range', 'open', 'service']}
      />
      {pricingType === 'range' ? (
        <div className="split-fields">
          <TextField label="Min price" value={minPrice} onChange={setMinPrice} inputMode="decimal" />
          <TextField label="Max price" value={maxPrice} onChange={setMaxPrice} inputMode="decimal" />
        </div>
      ) : pricingType !== 'open' ? (
        <TextField label="Price" value={suggestedPrice} onChange={setSuggestedPrice} inputMode="decimal" />
      ) : null}
      <div className="split-fields">
        <TextField label="Stock" value={stockQuantity} onChange={setStockQuantity} inputMode="numeric" />
        <label className="toggle-field">
          <input type="checkbox" checked={isService} onChange={event => setIsService(event.target.checked)} />
          Service
        </label>
      </div>
      <Button type="submit" disabled={!name || isSubmitting} icon={<Check />}>
        {submitLabel}
      </Button>
    </form>
  );
}

function PriceModal({
  product,
  onClose,
  onAdd,
}: {
  product: Product;
  onClose: () => void;
  onAdd: (price: number, quantity: number) => void;
}) {
  const [price, setPrice] = useState(String(defaultSalePrice(product)));
  const [quantity, setQuantity] = useState('1');

  return (
    <Modal title={product.name} onClose={onClose}>
      <form
        className="form-stack"
        onSubmit={event => {
          event.preventDefault();
          onAdd(Number(price), Number(quantity));
        }}
      >
        <TextField label="Final price" value={price} onChange={setPrice} inputMode="decimal" required />
        <TextField label="Quantity" value={quantity} onChange={setQuantity} inputMode="decimal" required />
        <Button type="submit" icon={<Plus />}>
          Add to cart
        </Button>
      </form>
    </Modal>
  );
}

function ManualItemModal({
  onClose,
  onAdd,
}: {
  onClose: () => void;
  onAdd: (name: string, category: string, price: number, quantity: number) => void;
}) {
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('1');

  return (
    <Modal title="Manual item" onClose={onClose}>
      <form
        className="form-stack"
        onSubmit={event => {
          event.preventDefault();
          onAdd(name, category, Number(price), Number(quantity));
        }}
      >
        <TextField label="Item name" value={name} onChange={setName} required />
        <TextField label="Category" value={category} onChange={setCategory} />
        <TextField label="Price" value={price} onChange={setPrice} inputMode="decimal" required />
        <TextField label="Quantity" value={quantity} onChange={setQuantity} inputMode="decimal" required />
        <Button type="submit" icon={<Plus />}>
          Add to cart
        </Button>
      </form>
    </Modal>
  );
}

function CartPanel({
  cartItems,
  recentSales,
  onRemove,
  onCheckout,
}: {
  cartItems: CartItem[];
  recentSales: Sale[];
  onRemove: (itemId: string) => void;
  onCheckout: (paymentMethod: string, customerPhone?: string) => Promise<void>;
}) {
  const [paymentMethod, setPaymentMethod] = useState('Cash');
  const [customerPhone, setCustomerPhone] = useState('');
  const total = cartTotal(cartItems);

  return (
    <div className="cart-panel">
      <Panel title="Cart">
        {cartItems.length === 0 ? (
          <EmptyState title="Cart is empty" detail="Add products to start a sale." icon={<ReceiptText />} compact />
        ) : (
          <div className="cart-list">
            {cartItems.map(item => (
              <div className="cart-row" key={item.id}>
                <span>
                  <strong>{item.name}</strong>
                  <small>
                    {item.quantity} x {formatZmw(item.finalPrice)}
                  </small>
                </span>
                <button aria-label="Remove item" onClick={() => onRemove(item.id)}>
                  <X />
                </button>
              </div>
            ))}
          </div>
        )}
        <div className="checkout-box">
          <span>Total</span>
          <strong>{formatZmw(total)}</strong>
        </div>
        <SelectField label="Payment" value={paymentMethod} onChange={setPaymentMethod} options={paymentMethods} />
        <TextField label="Customer phone" value={customerPhone} onChange={setCustomerPhone} inputMode="tel" />
        <Button disabled={cartItems.length === 0} icon={<CreditCard />} onClick={() => onCheckout(paymentMethod, customerPhone)}>
          Checkout
        </Button>
      </Panel>
      <Panel title="Recent sales">
        <div className="data-list compact">
          {recentSales.map(sale => (
            <div className="list-row static" key={sale.id}>
              <span className="row-icon forest">
                <ReceiptText />
              </span>
              <span className="row-main">
                <strong>{sale.reference}</strong>
                <span>{sale.payment_method}</span>
              </span>
              <span className="row-meta">
                <b>{formatZmw(sale.total_amount)}</b>
                <small>{formatDateTime(sale.created_at)}</small>
              </span>
            </div>
          ))}
        </div>
      </Panel>
    </div>
  );
}

function MoMoModal({ token, onClose, onSaved }: { token: string; onClose: () => void; onSaved: () => Promise<void> | void }) {
  const [reference, setReference] = useState('');
  const [phone, setPhone] = useState('');
  const [amount, setAmount] = useState('');

  return (
    <Modal title="Log MoMo" onClose={onClose}>
      <form
        className="form-stack"
        onSubmit={async event => {
          event.preventDefault();
          await api.createMoMo(token, {
            transaction_ref: reference,
            sender_phone: phone,
            amount: Number(amount),
          });
          await onSaved();
          onClose();
        }}
      >
        <TextField label="Reference" value={reference} onChange={setReference} required />
        <TextField label="Sender phone" value={phone} onChange={setPhone} inputMode="tel" required />
        <TextField label="Amount" value={amount} onChange={setAmount} inputMode="decimal" required />
        <Button type="submit" icon={<Smartphone />}>
          Save transaction
        </Button>
      </form>
    </Modal>
  );
}

function CreditModal({ token, onClose, onSaved }: { token: string; onClose: () => void; onSaved: () => Promise<void> | void }) {
  const [customerName, setCustomerName] = useState('');
  const [customerPhone, setCustomerPhone] = useState('');
  const [amount, setAmount] = useState('');
  const [dueDate, setDueDate] = useState('');

  return (
    <Modal title="Add credit" onClose={onClose}>
      <form
        className="form-stack"
        onSubmit={async event => {
          event.preventDefault();
          await api.createCredit(token, {
            customer_name: customerName,
            customer_phone: customerPhone,
            amount: Number(amount),
            due_date: dueDate || null,
          });
          await onSaved();
          onClose();
        }}
      >
        <TextField label="Customer" value={customerName} onChange={setCustomerName} required />
        <TextField label="Phone" value={customerPhone} onChange={setCustomerPhone} inputMode="tel" />
        <TextField label="Amount" value={amount} onChange={setAmount} inputMode="decimal" required />
        <TextField label="Due date" value={dueDate} onChange={setDueDate} type="date" />
        <Button type="submit" icon={<BookOpen />}>
          Save credit
        </Button>
      </form>
    </Modal>
  );
}

function StaffModal({ token, onClose, onSaved }: { token: string; onClose: () => void; onSaved: () => Promise<void> | void }) {
  const [name, setName] = useState('');
  const [role, setRole] = useState('cashier');
  const [pin, setPin] = useState('');

  return (
    <Modal title="Add staff" onClose={onClose}>
      <form
        className="form-stack"
        onSubmit={async event => {
          event.preventDefault();
          await api.createStaff(token, { name, role, pin });
          await onSaved();
          onClose();
        }}
      >
        <TextField label="Name" value={name} onChange={setName} required />
        <SelectField label="Role" value={role} onChange={setRole} options={['cashier', 'manager', 'admin']} />
        <TextField label="PIN" value={pin} onChange={setPin} inputMode="numeric" type="password" required />
        <Button type="submit" icon={<UserPlus />}>
          Create staff
        </Button>
      </form>
    </Modal>
  );
}

function DesktopRail({
  activeTab,
  onChange,
  session,
}: {
  activeTab: TabKey;
  onChange: (tab: TabKey) => void;
  session: AuthSession;
}) {
  return (
    <aside className="desktop-rail">
      <div className="rail-brand">
        <img src="/venda-logo.png" alt="" />
        <span>venda</span>
      </div>
      <nav>
        {tabs.map(tab => (
          <button
            key={tab.key}
            className={activeTab === tab.key ? 'active' : ''}
            onClick={() => onChange(tab.key)}
          >
            {tab.icon}
            <span>{tab.label}</span>
          </button>
        ))}
      </nav>
      <ProfileMini session={session} />
    </aside>
  );
}

function MobileTabs({ activeTab, onChange }: { activeTab: TabKey; onChange: (tab: TabKey) => void }) {
  return (
    <nav className="mobile-tabs">
      {tabs.slice(0, 5).map(tab => (
        <button key={tab.key} className={activeTab === tab.key ? 'active' : ''} onClick={() => onChange(tab.key)}>
          {tab.icon}
          <span>{tab.shortLabel ?? tab.label}</span>
        </button>
      ))}
    </nav>
  );
}

function TopBar({ session, onRefresh, isLoading }: { session: AuthSession; onRefresh: () => void; isLoading: boolean }) {
  return (
    <header className="top-bar">
      <div>
        <span className="eyebrow">{session.company_code}</span>
        <h2>{session.merchant.business_name}</h2>
      </div>
      <button className="refresh-button" onClick={onRefresh} disabled={isLoading}>
        <Menu />
        {isLoading ? 'Syncing' : 'Refresh'}
      </button>
    </header>
  );
}

function ProfileCard({ session }: { session: AuthSession }) {
  return (
    <section className="profile-card">
      <span className="avatar large">{initialsFor(session.staff.name)}</span>
      <div>
        <Badge>{session.staff.role}</Badge>
        <h1>{session.merchant.business_name}</h1>
        <p>
          {session.staff.name} under {session.company_code}
        </p>
      </div>
    </section>
  );
}

function ProfileMini({ session }: { session: AuthSession }) {
  return (
    <div className="profile-mini">
      <span className="avatar">{initialsFor(session.staff.name)}</span>
      <span>
        <strong>{session.staff.name}</strong>
        <small>{session.staff.role}</small>
      </span>
    </div>
  );
}

function FormScreen({
  title,
  subtitle,
  children,
  onBack,
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
  onBack?: () => void;
}) {
  return (
    <div className="form-screen">
      {onBack ? (
        <button className="back-button" onClick={onBack}>
          Back
        </button>
      ) : null}
      <div className="form-heading">
        <img src="/venda-logo.png" alt="" />
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>
      {children}
    </div>
  );
}

function FeaturePill({ icon, label }: { icon: React.ReactNode; label: string }) {
  return (
    <span className="feature-pill">
      {icon}
      {label}
    </span>
  );
}

function ScreenHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="screen-header">
      <h1>{title}</h1>
      <p>{subtitle}</p>
    </div>
  );
}

function MetricGrid({ children }: { children: React.ReactNode }) {
  return <div className="metric-grid">{children}</div>;
}

function MetricCard({
  label,
  value,
  detail,
  icon,
  tone,
}: {
  label: string;
  value: string;
  detail: string;
  icon: React.ReactNode;
  tone: 'forest' | 'ochre' | 'ember';
}) {
  return (
    <article className="metric-card">
      <span className={`metric-icon ${tone}`}>{icon}</span>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{detail}</small>
    </article>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="panel">
      <h2>{title}</h2>
      {children}
    </section>
  );
}

function EmptyState({
  title,
  detail,
  icon,
  compact = false,
}: {
  title: string;
  detail: string;
  icon: React.ReactNode;
  compact?: boolean;
}) {
  return (
    <div className={`empty-state ${compact ? 'compact' : ''}`}>
      {icon}
      <strong>{title}</strong>
      <span>{detail}</span>
    </div>
  );
}

function InlineNotice({
  tone,
  message,
  onDismiss,
}: {
  tone: 'danger' | 'success';
  message: string;
  onDismiss: () => void;
}) {
  return (
    <div className={`inline-notice ${tone}`}>
      <span>{message}</span>
      <button onClick={onDismiss} aria-label="Dismiss">
        <X />
      </button>
    </div>
  );
}

function Button({
  children,
  icon,
  tone = 'primary',
  type = 'button',
  disabled,
  onClick,
}: {
  children: React.ReactNode;
  icon?: React.ReactNode;
  tone?: 'primary' | 'inverse' | 'glass' | 'danger' | 'secondary';
  type?: 'button' | 'submit';
  disabled?: boolean;
  onClick?: () => void;
}) {
  return (
    <button className={`venda-button ${tone}`} type={type} disabled={disabled} onClick={onClick}>
      {icon}
      {children}
    </button>
  );
}

function IconButton({
  label,
  children,
  onClick,
}: {
  label: string;
  children: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button className="icon-button" aria-label={label} title={label} onClick={onClick}>
      {children}
    </button>
  );
}

function TextField({
  label,
  value,
  onChange,
  type = 'text',
  inputMode,
  required,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  inputMode?: React.HTMLAttributes<HTMLInputElement>['inputMode'];
  required?: boolean;
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <input
        type={type}
        value={value}
        required={required}
        inputMode={inputMode}
        onChange={event => onChange(event.target.value)}
      />
    </label>
  );
}

function SelectField({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: string[];
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <select value={value} onChange={event => onChange(event.target.value)}>
        {options.map(option => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    </label>
  );
}

function SearchField({ value, onChange, placeholder }: { value: string; onChange: (value: string) => void; placeholder: string }) {
  return (
    <label className="search-field">
      <Search />
      <input value={value} placeholder={placeholder} onChange={event => onChange(event.target.value)} />
      {value ? (
        <button aria-label="Clear search" onClick={() => onChange('')}>
          <X />
        </button>
      ) : null}
    </label>
  );
}

function Badge({ children }: { children: React.ReactNode }) {
  return <span className="badge">{children}</span>;
}

function Segmented({
  value,
  options,
  onChange,
}: {
  value: string;
  options: Array<[string, string]>;
  onChange: (value: string) => void;
}) {
  return (
    <div className="segmented">
      {options.map(([optionValue, label]) => (
        <button key={optionValue} className={value === optionValue ? 'active' : ''} onClick={() => onChange(optionValue)}>
          {label}
        </button>
      ))}
    </div>
  );
}

function Modal({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <section className="modal-panel">
        <div className="modal-handle" />
        <header>
          <h2>{title}</h2>
          <IconButton label="Close" onClick={onClose}>
            <X />
          </IconButton>
        </header>
        {children}
      </section>
    </div>
  );
}

const tabs: Array<{ key: TabKey; label: string; shortLabel?: string; icon: React.ReactNode }> = [
  { key: 'sell', label: 'Sell', icon: <Home /> },
  { key: 'stock', label: 'Stock', icon: <Boxes /> },
  { key: 'money', label: 'Money', icon: <Banknote /> },
  { key: 'reports', label: 'Reports', shortLabel: 'Stats', icon: <BarChart3 /> },
  { key: 'team', label: 'Team', icon: <Users /> },
  { key: 'settings', label: 'Settings', icon: <Settings /> },
];

export default App;
