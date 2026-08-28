/**
 * Pure JS security helpers shared by the Next.js app and node:test regressions.
 */

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const LEGAL_LANGS = new Set(["en", "fr", "ar"]);
const LEGAL_DOC_PATTERN = /^[a-z0-9-]+$/;

const ALLOWED_EXACT_PATHS = new Set([
  "ads/active",
  "categories",
  "search",
  "services",
  "sellers",
  "marketplaces",
  "geography/cities",
  "privacy",
  "terms",
  "cookies",
  "legal/manifest",
]);

const ALLOWED_PREFIX_PATHS = ["media/", "brand/"];

const BLOCKED_PROXY_PREFIXES = [
  "auth/",
  "admin/",
  "uploads/",
  "community/",
  "billing/",
  "discovery/",
  "privacy/",
  "seller/",
  "openapi",
  "docs",
  "metrics",
  "health",
  "ready",
  "live",
  "p/",
  "qr/",
];

const DANGEROUS_URL_SCHEMES =
  /^(?:javascript|data|vbscript|file|blob|about|chrome|chrome-extension):/i;

function decodePathSegment(segment) {
  try {
    return decodeURIComponent(segment);
  } catch {
    return null;
  }
}

export function normalizeProxyPath(pathSegments) {
  if (!pathSegments.length) return null;

  const normalized = [];
  for (const raw of pathSegments) {
    if (!raw || raw.includes("\0")) return null;
    const decoded = decodePathSegment(raw);
    if (decoded === null) return null;
    if (decoded === ".." || decoded === "." || decoded.includes("/") || decoded.includes("\\")) {
      return null;
    }
    normalized.push(decoded);
  }

  return normalized.join("/");
}

function matchesMarketplacePath(segments) {
  if (segments.length === 1) {
    return SLUG_PATTERN.test(segments[0]);
  }
  if (segments.length === 2) {
    return (
      SLUG_PATTERN.test(segments[0]) &&
      ["sellers", "categories", "featured"].includes(segments[1])
    );
  }
  return false;
}

function matchesLegalDocumentPath(segments) {
  if (segments.length !== 3 || segments[0] !== "legal") return false;
  return LEGAL_LANGS.has(segments[1]) && LEGAL_DOC_PATTERN.test(segments[2]);
}

function matchesSellerPath(segments) {
  if (segments.length === 1) {
    return UUID_PATTERN.test(segments[0]);
  }
  if (segments.length === 2 && segments[1] === "reviews") {
    return UUID_PATTERN.test(segments[0]);
  }
  return false;
}

export function isAllowedPublicProxyPath(path) {
  const normalized = path.replace(/^\/+/, "").replace(/\/+$/, "");
  if (!normalized) return false;

  const lower = normalized.toLowerCase();
  for (const blocked of BLOCKED_PROXY_PREFIXES) {
    if (lower === blocked.replace(/\/$/, "") || lower.startsWith(blocked)) {
      if (blocked === "privacy/" && (lower === "privacy" || lower.startsWith("legal/"))) {
        continue;
      }
      return false;
    }
  }

  if (ALLOWED_EXACT_PATHS.has(normalized)) return true;

  for (const prefix of ALLOWED_PREFIX_PATHS) {
    if (normalized.startsWith(prefix)) return true;
  }

  const segments = normalized.split("/");

  if (segments[0] === "products" && segments.length === 2 && UUID_PATTERN.test(segments[1])) {
    return true;
  }
  if (segments[0] === "services" && segments.length === 2 && UUID_PATTERN.test(segments[1])) {
    return true;
  }
  if (segments[0] === "sellers" && matchesSellerPath(segments.slice(1))) {
    return true;
  }
  if (segments[0] === "marketplaces" && matchesMarketplacePath(segments.slice(1))) {
    return true;
  }
  if (matchesLegalDocumentPath(segments)) {
    return true;
  }

  return false;
}

export function safeExternalHref(url) {
  const value = (url || "").trim();
  if (!value || DANGEROUS_URL_SCHEMES.test(value)) return null;

  let parsed;
  try {
    parsed = new URL(value.match(/^https?:\/\//i) ? value : `https://${value}`);
  } catch {
    return null;
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
  if (parsed.username || parsed.password) return null;

  return parsed.href;
}

export function safeJsonLd(data) {
  return JSON.stringify(data)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

export function sanitizeMediaSource(url) {
  const value = (url || "").trim();
  if (!value || DANGEROUS_URL_SCHEMES.test(value)) return "";
  return value;
}

export const PROXY_SAFE_RESPONSE_HEADERS = [
  "content-type",
  "cache-control",
  "content-length",
  "etag",
  "last-modified",
];

const SELLER_PROXY_ALLOWED_PREFIXES = [
  "sellers/",
  "uploads/",
  "subscriptions/",
  "billing/checkout/subscription/",
];

const SELLER_PROXY_ALLOWED_EXACT = new Set(["auth/me"]);

export function isAllowedSellerProxyPath(path) {
  const normalized = (path || "").replace(/^\/+/, "").replace(/\/+$/, "");
  if (!normalized) return false;
  if (SELLER_PROXY_ALLOWED_EXACT.has(normalized)) return true;
  return SELLER_PROXY_ALLOWED_PREFIXES.some(
    (prefix) => normalized === prefix.replace(/\/$/, "") || normalized.startsWith(prefix),
  );
}
