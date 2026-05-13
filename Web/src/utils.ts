import type { CartItem, Product } from './types';

export const formatZmw = (value: number | null | undefined) => {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat('en-ZM', {
    style: 'currency',
    currency: 'ZMW',
    maximumFractionDigits: amount % 1 === 0 ? 0 : 2,
  }).format(amount);
};

export const formatDateTime = (value: string | null | undefined) => {
  if (!value) {
    return 'Not recorded';
  }

  return new Intl.DateTimeFormat('en-ZM', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
};

export const productDisplayPrice = (product: Product) => {
  switch (product.pricing_type) {
    case 'range':
      if (product.min_price !== null && product.max_price !== null) {
        return `${formatZmw(product.min_price)} - ${formatZmw(product.max_price)}`;
      }
      return 'Range';
    case 'open':
      return 'Open price';
    case 'service':
      return product.suggested_price ? formatZmw(product.suggested_price) : 'Service';
    case 'flexible':
      return product.suggested_price ? `${formatZmw(product.suggested_price)} suggested` : 'Flexible';
    case 'fixed':
    default:
      return formatZmw(product.suggested_price ?? 0);
  }
};

export const defaultSalePrice = (product: Product) => {
  if (product.suggested_price !== null) {
    return product.suggested_price;
  }

  if (product.min_price !== null) {
    return product.min_price;
  }

  return 0;
};

export const isLowStock = (product: Product) => {
  return (
    product.is_active &&
    product.track_stock &&
    !product.is_service &&
    product.stock_quantity <= product.low_stock_threshold
  );
};

export const cartTotal = (items: CartItem[]) => {
  return items.reduce((total, item) => total + item.finalPrice * item.quantity, 0);
};

export const initialsFor = (name: string) => {
  const letters = name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase())
    .join('');

  return letters || 'V';
};

export const normalizeCompanyCode = (value: string) => {
  return value.trim().toUpperCase();
};
