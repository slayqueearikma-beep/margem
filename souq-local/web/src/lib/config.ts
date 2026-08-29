const DEFAULT_API = "http://localhost:8000";
const DEFAULT_SITE = "https://dribex.ma";

/** Docker Compose service hostname — valid only inside the web container network. */
const DOCKER_INTERNAL_API_PATTERN = /^https?:\/\/api(?::\d+)?(?:\/|$)/;

function stripTrailingSlash(value: string): string {
  return value.replace(/\/$/, "");
}

function resolveServerApiBaseUrl(): string {
  const configured = process.env.API_BASE_URL
    ? stripTrailingSlash(process.env.API_BASE_URL)
    : undefined;
  const publicBase = process.env.NEXT_PUBLIC_API_BASE_URL
    ? stripTrailingSlash(process.env.NEXT_PUBLIC_API_BASE_URL)
    : undefined;

  if (configured) {
    const dockerWeb = process.env.DRIBEX_WEB_IN_DOCKER === "1";
    if (DOCKER_INTERNAL_API_PATTERN.test(configured) && !dockerWeb) {
      // npm run dev on the host cannot resolve the compose service name "api".
      return publicBase || DEFAULT_API;
    }
    return configured;
  }

  return publicBase || DEFAULT_API;
}

/** Server-side API base (Docker internal hostname in production). */
export function getServerApiBaseUrl(): string {
  return resolveServerApiBaseUrl();
}

/** Browser-facing API base for client fetches (same-origin proxy). */
export function getPublicApiBaseUrl(): string {
  return "/api-proxy";
}

export function getSiteUrl(): string {
  return process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, "") || DEFAULT_SITE;
}

export const LAUNCH_CITIES = (
  process.env.NEXT_PUBLIC_LAUNCH_CITIES || "Casablanca"
)
  .split(",")
  .map((city) => city.trim())
  .filter(Boolean);

export const BRAND = {
  name: "Dribex",
  tagline: "Discover Morocco's hidden gems",
  primary: "#2563EB",
  background: "#F9FAFB",
  cream: "#F8F1E9",
  terracotta: "#721019",
} as const;
