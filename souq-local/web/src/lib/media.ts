import { getSiteUrl } from "./config";
import { sanitizeMediaSource } from "./security";
import type { PlatformAdvertisement } from "./types";

const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "::1", "0.0.0.0"]);

function parseConfiguredPublicApiHost(): string | null {
  const configured = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  if (!configured || !configured.startsWith("http")) return null;
  try {
    return new URL(configured).host.toLowerCase();
  } catch {
    return null;
  }
}

function isMediaPath(pathname: string): boolean {
  return pathname.startsWith("/media/") || pathname.includes("/media/");
}

function shouldRewriteAbsoluteMediaUrl(url: URL): boolean {
  if (!isMediaPath(url.pathname)) return false;

  const host = url.hostname.toLowerCase();
  if (LOOPBACK_HOSTS.has(host)) return true;

  const publicHost = parseConfiguredPublicApiHost();
  if (publicHost && host !== publicHost) return true;

  return false;
}

export function resolveMediaUrl(url: string | null | undefined): string {
  const value = sanitizeMediaSource(url);
  if (!value) return "";

  if (value.startsWith("http://") || value.startsWith("https://")) {
    try {
      const parsed = new URL(value);
      if (shouldRewriteAbsoluteMediaUrl(parsed)) {
        return `/api-proxy${parsed.pathname}${parsed.search}`;
      }
    } catch {
      return value;
    }
    return value;
  }

  const path = value.startsWith("/") ? value : `/${value}`;
  return `/api-proxy${path}`;
}

function needsAdAssetProxy(url: string): boolean {
  if (!url) return false;
  if (url.startsWith("/media/") || url.includes("/media/")) return false;
  if (url.startsWith("/")) return false;
  return url.startsWith("http://") || url.startsWith("https://");
}

/** Resolve ad creatives through the same-origin media proxy for CSP compliance. */
export function resolveAdAssetUrl(
  ad: Pick<PlatformAdvertisement, "id" | "image_url" | "video_url">,
  kind: "image" | "video",
): string {
  const raw = kind === "image" ? ad.image_url : ad.video_url;
  if (!raw) return "";
  const proxied = resolveMediaUrl(raw);
  if (!proxied) return "";
  if (needsAdAssetProxy(raw)) {
    return `/api-proxy/ads/media/${ad.id}/${kind}`;
  }
  return proxied;
}

export function brandLogoUrl(): string {
  return "/api-proxy/brand/margem_logo.png";
}

/** Same-origin proxy so images/API work on LAN/Tailscale without hardcoding localhost. */
export function getBrowserApiBaseUrl(): string {
  return `${getSiteUrl()}/api-proxy`;
}
