export interface PlatformAdvertisement {
  id: string;
  title: string;
  description?: string | null;
  image_url: string;
  video_url?: string | null;
  target_url: string;
  placement: string;
  click_url: string;
}

export interface Category {
  id: string;
  slug: string;
  name_en: string;
  name_fr: string;
  name_ar: string;
  icon: string;
}

export interface SellerSummary {
  id: string;
  business_name: string;
  description: string;
  city: string;
  latitude: number;
  longitude: number;
  cover_image_url: string;
  logo_image_url?: string;
  achievement_stars: number;
  average_rating: number;
  review_count: number;
  golden_crowns?: number;
  is_premium: boolean;
  verification_status: string;
  avg_response_minutes?: number;
  categories: Category[];
}

export interface ProductOut {
  id: string;
  name: string;
  description: string;
  price_mad: number | null;
  price_negotiable?: boolean;
  image_url: string;
  media_urls?: string[];
  category_slug: string;
  is_available: boolean;
  delivery_available?: boolean;
  pickup_only?: boolean;
  availability_note?: string;
  warranty_note?: string;
}

export interface ServiceOut {
  id: string;
  name: string;
  description: string;
  price_mad: number | null;
  price_negotiable?: boolean;
  image_url: string;
  category_slug: string;
  is_available: boolean;
  coverage_areas?: string[];
}

export interface SellerDetail extends SellerSummary {
  address: string;
  phone: string;
  opening_hours: Record<string, unknown>;
  website_url: string;
  instagram_url: string;
  facebook_url: string;
  tiktok_url: string;
  whatsapp_number: string;
  payment_methods: string[];
  delivery_methods: string[];
  service_areas: string[];
  products: ProductOut[];
  services: ServiceOut[];
  follower_count?: number;
  favorite_count?: number;
}

export interface ProductSearchOut {
  id: string;
  seller_id: string;
  seller_name: string;
  seller_city: string;
  seller_verified: boolean;
  seller_premium: boolean;
  seller_rating: number;
  name: string;
  description: string;
  price_mad: number | null;
  price_negotiable?: boolean;
  image_url: string;
  category_slug: string;
  is_available: boolean;
}

export interface ServiceListItem {
  id: string;
  seller_id: string;
  seller_name: string;
  seller_city: string;
  seller_verified: boolean;
  seller_premium: boolean;
  seller_rating: number;
  name: string;
  description: string;
  price_mad: number | null;
  price_negotiable?: boolean;
  image_url: string;
  category_slug: string;
  is_available: boolean;
}

export interface ServiceSearchOut {
  id: string;
  seller_id: string;
  seller_name: string;
  seller_city: string;
  seller_verified: boolean;
  seller_premium: boolean;
  seller_rating: number;
  name: string;
  description: string;
  price_mad: number | null;
  price_negotiable?: boolean;
  image_url: string;
  category_slug: string;
  is_available: boolean;
}

export interface SearchPage {
  sellers: SellerSummary[];
  products: ProductSearchOut[];
  services: ServiceSearchOut[];
  total_sellers: number;
  total_products: number;
  total_services: number;
  limit: number;
  offset: number;
  has_more: boolean;
}

export interface ServiceListPage {
  items: ServiceListItem[];
  total: number;
  limit: number;
  offset: number;
  has_more: boolean;
}

export interface SellerContext {
  id: string;
  business_name: string;
  city: string;
  verified: boolean;
  premium: boolean;
  average_rating: number;
  review_count: number;
  verification_status: string;
}

export interface ProductPublicOut {
  product: ProductOut;
  seller: SellerContext;
}

export interface ServicePublicOut {
  service: ServiceOut;
  seller: SellerContext;
}

export interface ReviewOut {
  id: string;
  rating: number;
  overall_rating: number;
  product_quality: number;
  customer_service: number;
  communication: number;
  trustworthiness: number;
  comment: string;
  buyer_display_name: string;
  created_at: string;
}

export interface GeographyCity {
  id: string;
  slug: string;
  name_en: string;
  name_ar?: string;
  name_fr?: string;
  region?: string;
  latitude?: number;
  longitude?: number;
  is_active?: boolean;
}

export interface GeographyCityList {
  items: GeographyCity[];
}

export interface MarketplaceOut {
  id: string;
  slug: string;
  name: string;
  description: string;
  city: string;
  cover_image_url: string;
  seller_count?: number;
}
