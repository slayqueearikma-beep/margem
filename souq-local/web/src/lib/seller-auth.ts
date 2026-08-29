export const SELLER_TOKEN_COOKIE = "dribex_seller_token";

export type SellerEntitlements = {
  seller: {
    driver_pro_active: boolean;
    combined_listing_count: number;
    combined_listing_limit: number;
    combined_listing_remaining: number;
  } | null;
  rewarded_ads_enabled?: boolean;
};

export type SellerProfile = {
  id: string;
  business_name: string;
  products: Array<{
    id: string;
    name: string;
    description?: string;
    price_mad?: number | null;
    image_url?: string;
    is_available?: boolean;
  }>;
  services: Array<{
    id: string;
    name: string;
    description?: string;
    price_mad?: number | null;
    image_url?: string;
    is_available?: boolean;
  }>;
};
