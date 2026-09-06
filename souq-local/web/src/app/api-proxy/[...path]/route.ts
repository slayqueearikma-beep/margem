import { getServerApiBaseUrl } from "@/lib/config";
import {
  isAllowedPublicProxyPath,
  isAllowedPublicProxyPostPath,
  normalizeProxyPath,
  PROXY_SAFE_RESPONSE_HEADERS,
} from "@/lib/security";

type RouteContext = {
  params: Promise<{ path: string[] }>;
};

const IMPRESSION_BODY_LIMIT_BYTES = 4096;

function rejectProxy(message: string, status = 403): Response {
  return Response.json({ detail: message }, { status });
}

async function proxyToApi(request: Request, pathSegments: string[]): Promise<Response> {
  const normalizedPath = normalizeProxyPath(pathSegments);
  if (!normalizedPath) {
    return rejectProxy("Invalid proxy path.");
  }

  const method = request.method.toUpperCase();
  if (method === "GET" || method === "HEAD") {
    if (!isAllowedPublicProxyPath(normalizedPath)) {
      return rejectProxy("Path not allowed through the public web proxy.");
    }
  } else if (method === "POST") {
    if (!isAllowedPublicProxyPostPath(normalizedPath)) {
      return rejectProxy("Method not allowed.", 405);
    }
  } else {
    return rejectProxy("Method not allowed.", 405);
  }

  const base = getServerApiBaseUrl();
  const incoming = new URL(request.url);
  const target = `${base}/${normalizedPath}${incoming.search}`;

  const headers = new Headers();
  const accept = request.headers.get("accept");
  if (accept) headers.set("Accept", accept);

  const contentType = request.headers.get("content-type");
  if (contentType) headers.set("Content-Type", contentType);

  const adViewer = request.headers.get("x-ad-viewer");
  if (adViewer) headers.set("X-Ad-Viewer", adViewer);

  let body: string | undefined;
  if (method === "POST") {
    const raw = await request.text();
    if (raw.length > IMPRESSION_BODY_LIMIT_BYTES) {
      return rejectProxy("Request body too large.", 413);
    }
    try {
      const parsed = JSON.parse(raw) as {
        campaign_id?: unknown;
        placement?: unknown;
        view_key?: unknown;
      };
      if (
        typeof parsed.campaign_id !== "string" ||
        typeof parsed.placement !== "string" ||
        typeof parsed.view_key !== "string"
      ) {
        return rejectProxy("Invalid impression payload.", 400);
      }
    } catch {
      return rejectProxy("Invalid JSON body.", 400);
    }
    body = raw;
  }

  let upstream: Response;
  try {
    upstream = await fetch(target, {
      method,
      headers,
      body,
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

export async function POST(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return proxyToApi(request, path);
}
