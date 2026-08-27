import { getServerApiBaseUrl } from "@/lib/config";
import {
  isAllowedPublicProxyPath,
  normalizeProxyPath,
  PROXY_SAFE_RESPONSE_HEADERS,
} from "@/lib/security";

type RouteContext = {
  params: Promise<{ path: string[] }>;
};

function rejectProxy(message: string, status = 403): Response {
  return Response.json({ detail: message }, { status });
}

async function proxyToApi(request: Request, pathSegments: string[]): Promise<Response> {
  const normalizedPath = normalizeProxyPath(pathSegments);
  if (!normalizedPath) {
    return rejectProxy("Invalid proxy path.");
  }
  if (!isAllowedPublicProxyPath(normalizedPath)) {
    return rejectProxy("Path not allowed through the public web proxy.");
  }

  if (request.method !== "GET" && request.method !== "HEAD") {
    return rejectProxy("Method not allowed.", 405);
  }

  const base = getServerApiBaseUrl();
  const incoming = new URL(request.url);
  const target = `${base}/${normalizedPath}${incoming.search}`;

  const headers = new Headers();
  const accept = request.headers.get("accept");
  if (accept) headers.set("Accept", accept);

  let upstream: Response;
  try {
    upstream = await fetch(target, {
      method: request.method,
      headers,
      cache: "no-store",
    });
  } catch (error) {
    console.error(`[dribex-web] api-proxy failed for ${target}:`, error);
    return Response.json(
      { detail: "Upstream API unreachable from the web container." },
      { status: 503 },
    );
  }

  const responseHeaders = new Headers();
  for (const name of PROXY_SAFE_RESPONSE_HEADERS) {
    const value = upstream.headers.get(name);
    if (value) responseHeaders.set(name, value);
  }
  responseHeaders.set("Cache-Control", responseHeaders.get("Cache-Control") || "no-store");
  responseHeaders.set("X-Content-Type-Options", "nosniff");

  return new Response(upstream.body, {
    status: upstream.status,
    headers: responseHeaders,
  });
}

export async function GET(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return proxyToApi(request, path);
}

export async function HEAD(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return proxyToApi(request, path);
}
