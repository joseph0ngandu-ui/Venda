import { describe, expect, it } from 'vitest';
import type { CartItem, Product } from '../src/types';
import { cartTotal, defaultSalePrice, isLowStock, normalizeCompanyCode, productDisplayPrice } from '../src/utils';

const baseProduct: Product = {
  id: 'product-1',
  name: 'Haircut',
  category: 'Services',
  pricing_type: 'fixed',
  suggested_price: 150,
  min_price: null,
  max_price: null,
  stock_quantity: 4,
  low_stock_threshold: 5,
  track_stock: true,
  is_service: false,
  is_active: true,
};

describe('Venda web commerce utilities', () => {
  it('calculates cart totals with quantities', () => {
    const items: CartItem[] = [
      {
        id: 'cart-1',
        product: baseProduct,
        name: baseProduct.name,
        category: baseProduct.category,
        quantity: 2,
        finalPrice: 125,
      },
      {
        id: 'cart-2',
        product: null,
        name: 'Manual item',
        category: 'Custom',
        quantity: 1.5,
        finalPrice: 40,
      },
    ];

    expect(cartTotal(items)).toBe(310);
  });

  it('uses suggested price then minimum price as default sale price', () => {
    expect(defaultSalePrice(baseProduct)).toBe(150);
    expect(defaultSalePrice({ ...baseProduct, suggested_price: null, min_price: 80 })).toBe(80);
    expect(defaultSalePrice({ ...baseProduct, suggested_price: null, min_price: null })).toBe(0);
  });

  it('flags low stock only for active tracked products', () => {
    expect(isLowStock(baseProduct)).toBe(true);
    expect(isLowStock({ ...baseProduct, is_service: true })).toBe(false);
    expect(isLowStock({ ...baseProduct, track_stock: false })).toBe(false);
    expect(isLowStock({ ...baseProduct, stock_quantity: 8 })).toBe(false);
  });

  it('formats range products and normalizes company codes', () => {
    expect(productDisplayPrice({ ...baseProduct, pricing_type: 'range', min_price: 50, max_price: 90 })).toContain('50');
    expect(normalizeCompanyCode(' vnd-abcd1234 ')).toBe('VND-ABCD1234');
  });
});
