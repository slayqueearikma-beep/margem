const DEV_API_DEFAULT = "http://localhost:8000";
const PRODUCTION_API_URL = "https://api.dribex.ma";
const PRODUCTION_SITE_URL = "https://dribex.ma";
const DEFAULT_SITE = PRODUCTION_SITE_URL;

/** Docker Compose service hostname — valid only inside the web container network. */
const DOCKER_INTERNAL_API_PATTERN = /^https?:\/\/api(?::\d+)?(?:\/|$)/;

const DEVELOPMENT_HOST_PATTERN =
  /(^|\/\/)(localhost|127\.0\.0\.1|10\.0\.2\.2|::1)(:|\/|$)/i;

function stripTrailingSlash(value: string): string {
  return value.replace(/\/$/, "");
}

function isDevelopmentApiUrl(value: string): boolean {
  return DEVELOPMENT_HOST_PATTERN.test(value);
}

export function validateProductionWebConfig(): void {
  if (process.env.NODE_ENV !== "production") {
    return;
  }

  const publicApi = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  const site = process.env.NEXT_PUBLIC_SITE_URL?.trim();

  if (!publicApi) {
    throw new Error(
      "NEXT_PUBLIC_API_BASE_URL is required for production web builds.",
    );
  }
  if (!site) {
    throw new Error("NEXT_PUBLIC_SITE_URL is required for production web builds.");
  }
  if (!publicApi.startsWith("https://")) {
    throw new Error(
      `Production NEXT_PUBLIC_API_BASE_URL must use HTTPS. Got: ${publicApi}`,
    );
  }
  if (isDevelopmentApiUrl(publicApi)) {
    throw new Error(
      `Production NEXT_PUBLIC_API_BASE_URL must not use development hosts. Got: ${publicApi}`,
    );
  }
  if (publicApi !== PRODUCTION_API_URL) {
    throw new Error(
      `Production NEXT_PUBLIC_API_BASE_URL must be ${PRODUCTION_API_URL}. Got: ${publicApi}`,
    );
  }
  if (!site.startsWith("https://")) {
    throw new Error(
      `Production NEXT_PUBLIC_SITE_URL must use HTTPS. Got: ${site}`,
    );
  }
  if (isDevelopmentApiUrl(site)) {
    throw new Error(
      `Production NEXT_PUBLIC_SITE_URL must not use development hosts. Got: ${site}`,
    );
  }

  const serverApi = process.env.API_BASE_URL?.trim();
  if (serverApi && isDevelopmentApiUrl(serverApi)) {
    const dockerWeb = process.env.DRIBEX_WEB_IN_DOCKER === "1";
    const internalDockerApi = DOCKER_INTERNAL_API_PATTERN.test(serverApi);
    if (!dockerWeb || !internalDockerApi) {
      throw new Error(
        `Production API_BASE_URL must not use development hosts. Got: ${serverApi}`,
      );
    }
  }
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
      return publicBase || DEV_API_DEFAULT;
    }
    return configured;
  }

  if (process.env.NODE_ENV === "production") {
    if (!publicBase) {
      throw new Error(
        "API_BASE_URL or NEXT_PUBLIC_API_BASE_URL is required in production.",
      );
    }
    return publicBase;
  }

  return publicBase || DEV_API_DEFAULT;
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

validateProductionWebConfig();
