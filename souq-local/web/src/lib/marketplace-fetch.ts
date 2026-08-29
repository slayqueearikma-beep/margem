import { ApiError, apiFetch, searchParams } from "./api";
import { getServerApiBaseUrl } from "./config";
import type {
  Category,
  GeographyCityList,
  MarketplaceOut,
  PlatformAdvertisement,
  ProductPublicOut,
  ReviewOut,
  SearchPage,
  SellerDetail,
  SellerSummary,
  ServicePublicOut,
} from "./types";

export type FetchOutcome<T> =
  | { ok: true; data: T }
  | { ok: false; error: Error; kind: "api" | "network" };

function logFetchFailure(path: string, error: unknown): Error {
  const base = getServerApiBaseUrl();
  if (error instanceof ApiError) {
    console.error(`[dribex-web] API ${path} failed (${error.status}): ${error.message}`);
    return error;
  }
  const networkError =
    error instanceof Error ? error : new Error(typeof error === "string" ? error : "Unknown error");
  console.error(
    `[dribex-web] API ${path} unreachable via ${base}:`,
    networkError.message,
    networkError.cause ?? "",
  );
  return networkError;
}

export async function safeApiFetch<T>(
  path: string,
  options: Parameters<typeof apiFetch>[1] = {},
  runtime: Parameters<typeof apiFetch>[2] = "server",
): Promise<FetchOutcome<T>> {
  try {
    const data = await apiFetch<T>(path, options, runtime);
    return { ok: true, data };
  } catch (error) {
    const resolved = logFetchFailure(path, error);
    return {
      ok: false,
      error: resolved,
      kind: error instanceof ApiError ? "api" : "network",
    };
  }
}

export function describeFetchError(outcome: FetchOutcome<unknown>): string {
  if (outcome.ok) return "";
  if (outcome.kind === "network") {
    if (process.env.NODE_ENV === "production") {
      return "The marketplace API is temporarily unavailable.";
    }
    return `The Dribex API is unreachable (${getServerApiBaseUrl()}). Ensure margem-api is healthy and the web container can reach it on the Docker network.`;
  }
  return outcome.error.message || "The marketplace API returned an error.";
}

export function serviceUnavailableDescription(outcome: FetchOutcome<unknown>): string {
  const detail = describeFetchError(outcome);
  return `${detail} This is an infrastructure or API error — not an empty marketplace.`;
}

export async function loadSearch(
  params: Record<string, string | number | boolean | undefined>,
): Promise<FetchOutcome<SearchPage>> {
  return safeApiFetch<SearchPage>(`/search${searchParams(params)}`);
}

export async function loadCategories(): Promise<FetchOutcome<Category[]>> {
  return safeApiFetch<Category[]>("/categories");
}

export async function loadMarketplaces(): Promise<FetchOutcome<MarketplaceOut[]>> {
  return safeApiFetch<MarketplaceOut[]>("/marketplaces");
}

export async function loadMarketplace(slug: string): Promise<FetchOutcome<MarketplaceOut>> {
  return safeApiFetch<MarketplaceOut>(`/marketplaces/${slug}`);
}

export async function loadMarketplaceSellers(slug: string): Promise<FetchOutcome<SellerSummary[]>> {
  return safeApiFetch<SellerSummary[]>(`/marketplaces/${slug}/sellers`);
}

export async function loadSeller(id: string): Promise<FetchOutcome<SellerDetail>> {
  return safeApiFetch<SellerDetail>(`/sellers/${id}`);
}

export async function loadProduct(id: string): Promise<FetchOutcome<ProductPublicOut>> {
  return safeApiFetch<ProductPublicOut>(`/products/${id}`);
}

export async function loadService(id: string): Promise<FetchOutcome<ServicePublicOut>> {
  return safeApiFetch<ServicePublicOut>(`/services/${id}`);
}

export async function loadReviews(sellerId: string): Promise<FetchOutcome<ReviewOut[]>> {
  return safeApiFetch<ReviewOut[]>(`/sellers/${sellerId}/reviews`);
}

export async function loadGeographyCities(): Promise<FetchOutcome<GeographyCityList>> {
  return safeApiFetch<GeographyCityList>("/geography/cities?country=MA");
}

export async function loadActiveAdvertisements(
  placement = "homepage_top",
  options: {
    marketplaceSlug?: string;
    city?: string;
    categorySlug?: string;
    listingType?: string;
    limit?: number;
  } = {},
): Promise<PlatformAdvertisement[]> {
  const outcome = await safeApiFetch<PlatformAdvertisement[]>(
    `/ads/active${searchParams({
      placement,
      marketplace_slug: options.marketplaceSlug,
      city: options.city,
      category_slug: options.categorySlug,
      listing_type: options.listingType,
      platform: "web",
      limit: options.limit ?? 1,
    })}`,
  );
  if (!outcome.ok) {
    console.warn("[dribex-web] Advertisement feed unavailable:", outcome.error.message);
    return [];
  }
  return outcome.data;
}
