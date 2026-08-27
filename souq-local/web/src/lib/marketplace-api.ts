import { apiFetch, searchParams } from "./api";
import type {
  Category,
  GeographyCityList,
  MarketplaceOut,
  ProductPublicOut,
  ReviewOut,
  SearchPage,
  SellerDetail,
  SellerSummary,
  ServiceListPage,
  ServicePublicOut,
} from "./types";

export async function fetchCategories(): Promise<Category[]> {
  return apiFetch<Category[]>("/categories");
}

export async function fetchSearch(
  params: Record<string, string | number | boolean | undefined>,
): Promise<SearchPage> {
  return apiFetch<SearchPage>(`/search${searchParams(params)}`);
}

export async function fetchServices(
  params: Record<string, string | number | boolean | undefined>,
): Promise<ServiceListPage> {
  return apiFetch<ServiceListPage>(`/services${searchParams(params)}`);
}

export async function fetchSeller(id: string): Promise<SellerDetail> {
  return apiFetch<SellerDetail>(`/sellers/${id}`, {}, "server");
}

export async function fetchSellers(
  params: Record<string, string | number | undefined> = {},
): Promise<SellerSummary[]> {
  return apiFetch<SellerSummary[]>(`/sellers${searchParams(params)}`);
}

export async function fetchProduct(id: string): Promise<ProductPublicOut> {
  return apiFetch<ProductPublicOut>(`/products/${id}`);
}

export async function fetchService(id: string): Promise<ServicePublicOut> {
  return apiFetch<ServicePublicOut>(`/services/${id}`);
}

export async function fetchReviews(sellerId: string): Promise<ReviewOut[]> {
  return apiFetch<ReviewOut[]>(`/sellers/${sellerId}/reviews`);
}

export async function fetchGeographyCities(): Promise<GeographyCityList | null> {
  try {
    return await apiFetch<GeographyCityList>("/geography/cities?country=MA");
  } catch {
    return null;
  }
}

export async function fetchMarketplaces(): Promise<MarketplaceOut[] | null> {
  try {
    return await apiFetch<MarketplaceOut[]>("/marketplaces");
  } catch {
    return null;
  }
}

export async function fetchMarketplace(slug: string): Promise<MarketplaceOut | null> {
  try {
    return await apiFetch<MarketplaceOut>(`/marketplaces/${slug}`);
  } catch {
    return null;
  }
}

export async function fetchMarketplaceSellers(slug: string): Promise<SellerSummary[] | null> {
  try {
    return await apiFetch<SellerSummary[]>(`/marketplaces/${slug}/sellers`);
  } catch {
    return null;
  }
}
