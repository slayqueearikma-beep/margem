const DEFAULT_API = "http://localhost:8000";
const DEFAULT_SITE = "https://dribex.ma";

/** Server-side API base (Docker internal hostname in production). */
export function getServerApiBaseUrl(): string {
  return (
    process.env.API_BASE_URL?.replace(/\/$/, "") ||
    process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") ||
    DEFAULT_API
  );
}

/** Browser-facing API base for media URLs and client fetches. */
export function getPublicApiBaseUrl(): string {
  return process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") || DEFAULT_API;
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
