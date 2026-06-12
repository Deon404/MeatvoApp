/**
 * Database Type Definitions
 * Shared types for database entities
 */

export interface User {
  id: string;
  phone: string;
  name: string;
  email?: string;
  role: 'customer' | 'admin' | 'rider';
  is_verified: boolean;
  created_at: string;
  updated_at: string;
}

export interface Address {
  id: string;
  user_id: string;
  label: string;
  address_line1: string;
  address_line2?: string;
  city: string;
  state: string;
  pincode: string;
  latitude?: number;
  longitude?: number;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductVariant {
  id: string;
  product_id: string;
  weight: string;
  price: number;
  stock: number;
  sku?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Product {
  id: string;
  category: string;
  name: string;
  description?: string;
  base_price: number;
  unit: string;
  stock: number;
  image_url?: string;
  images?: string[];
  nutritional_info?: any;
  tags?: string[];
  is_active: boolean;
  featured: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface ProductWithVariants extends Product {
  variants: ProductVariant[];
}

export interface CartItem {
  id: string;
  user_id: string;
  product_id: string;
  variant_id?: string;
  quantity: number;
  created_at: string;
  updated_at: string;
  product?: ProductWithVariants;
  variant?: ProductVariant;
}

export interface Order {
  id: string;
  user_id: string;
  order_number: string;
  status: OrderStatus;
  payment_method: 'online' | 'cod';
  payment_status: 'pending' | 'paid' | 'failed' | 'refunded';
  subtotal: number;
  delivery_fee: number;
  discount: number;
  total: number;
  delivery_address: Address;
  items: OrderItem[];
  rider_id?: string;
  delivery_otp?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
  delivered_at?: string;
}

export interface OrderItem {
  id: string;
  order_id: string;
  product_id: string;
  variant_id?: string;
  product_name: string;
  variant_name?: string;
  quantity: number;
  price: number;
  subtotal: number;
}

export type OrderStatus =
  | 'placed'
  | 'confirmed'
  | 'preparing'
  | 'ready'
  | 'assigned'
  | 'picked_up'
  | 'out_for_delivery'
  | 'nearby'
  | 'delivered'
  | 'cancelled';

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  sort_order: number;
  is_active: boolean;
}

export interface Banner {
  id: string;
  title: string;
  description?: string;
  image_url?: string;
  link?: string;
  color: string;
  is_active: boolean;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export interface OTPVerification {
  phone: string;
  token: string;
}

export interface CartSummary {
  items: CartItem[];
  subtotal: number;
  delivery_fee: number;
  discount: number;
  total: number;
  item_count: number;
}
