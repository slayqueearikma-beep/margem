import { getSiteUrl } from "./config";

export function resolveMediaUrl(url: string | null | undefined): string {
  const value = (url || "").trim();
  if (!value) return "";
  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value;
  }
  const path = value.startsWith("/") ? value : `/${value}`;
  return `/api-proxy${path}`;
}

export function brandLogoUrl(): string {
  return "/api-proxy/brand/margem_logo.png";
}

/** Same-origin proxy so images/API work on LAN/Tailscale without hardcoding localhost. */
export function getBrowserApiBaseUrl(): string {
  return `${getSiteUrl()}/api-proxy`;
}
