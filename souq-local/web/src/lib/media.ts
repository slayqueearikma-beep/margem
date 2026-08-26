import { getPublicApiBaseUrl } from "./config";

export function resolveMediaUrl(url: string | null | undefined): string {
  const value = (url || "").trim();
  if (!value) return "";
  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value;
  }
  const base = getPublicApiBaseUrl();
  if (value.startsWith("/")) {
    return `${base}${value}`;
  }
  return `${base}/${value}`;
}

export function brandLogoUrl(): string {
  return `${getPublicApiBaseUrl()}/brand/margem_logo.png`;
}
