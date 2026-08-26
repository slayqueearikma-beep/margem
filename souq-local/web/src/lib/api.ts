import { getPublicApiBaseUrl, getServerApiBaseUrl } from "./config";

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

type FetchOptions = RequestInit & { next?: { revalidate?: number | false; tags?: string[] } };

export async function apiFetch<T>(
  path: string,
  options: FetchOptions = {},
  runtime: "server" | "client" = "server",
): Promise<T> {
  const base =
    runtime === "client" ? getPublicApiBaseUrl() : getServerApiBaseUrl();
  const url = `${base}${path.startsWith("/") ? path : `/${path}`}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      Accept: "application/json",
      ...(options.headers || {}),
    },
    cache: "no-store",
  });

  if (!response.ok) {
    let detail = response.statusText;
    try {
      const body = (await response.json()) as { detail?: string };
      if (typeof body.detail === "string") {
        detail = body.detail;
      }
    } catch {
      // ignore parse errors
    }
    throw new ApiError(detail || `Request failed (${response.status})`, response.status);
  }

  return (await response.json()) as T;
}

export function searchParams(
  params: Record<string, string | number | boolean | undefined | null>,
): string {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === "") continue;
    query.set(key, String(value));
  }
  const serialized = query.toString();
  return serialized ? `?${serialized}` : "";
}
