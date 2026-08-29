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

const MAX_IMPRESSION_BODY_BYTES = 4096;

function rejectProxy(message: string, status = 403): Response {
  return Response.json({ detail: message }, { status });
}

function buildUpstreamHeaders(request: Request, includeBody: boolean): Headers {
  const headers = new Headers();
  const accept = request.headers.get("accept");
  if (accept) headers.set("Accept", accept);

  if (includeBody) {
    const contentType = request.headers.get("content-type");
    if (contentType) headers.set("Content-Type", contentType);
    const viewer = request.headers.get("x-ad-viewer");
    if (viewer) headers.set("X-Ad-Viewer", viewer);
  }

  return headers;
}

function buildProxyResponse(upstream: Response): Response {
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

async function proxyToApi(
  request: Request,
  pathSegments: string[],
  options: { allowPost?: boolean } = {},
): Promise<Response> {
  const normalizedPath = normalizeProxyPath(pathSegments);
  if (!normalizedPath) {
    return rejectProxy("Invalid proxy path.");
  }

  const method = request.method.toUpperCase();
  let body: string | undefined;

  if (method === "POST") {
    if (!options.allowPost || !isAllowedPublicProxyPostPath(normalizedPath)) {
      return rejectProxy("Method not allowed.", 405);
    }
    const contentType = request.headers.get("content-type") || "";
    if (!contentType.toLowerCase().startsWith("application/json")) {
      return rejectProxy("Invalid content type.", 415);
    }
    body = await request.text();
    if (!body || body.length > MAX_IMPRESSION_BODY_BYTES) {
      return rejectProxy("Invalid request body.", 400);
    }
  } else if (method === "GET" || method === "HEAD") {
    if (!isAllowedPublicProxyPath(normalizedPath)) {
      return rejectProxy("Path not allowed through the public web proxy.");
    }
  } else {
    return rejectProxy("Method not allowed.", 405);
  }

  const base = getServerApiBaseUrl();
  const incoming = new URL(request.url);
  const target = `${base}/${normalizedPath}${incoming.search}`;

  const headers = buildUpstreamHeaders(request, method === "POST");
  const init: RequestInit = {
    method,
    headers,
    cache: "no-store",
    body,
  };

  let upstream: Response;
  try {
    upstream = await fetch(target, init);
  } catch (error) {
    console.error(`[dribex-web] api-proxy failed for ${target}:`, error);
    return Response.json(
      { detail: "Upstream API unreachable from the web container." },
      { status: 503 },
    );
  }

  return buildProxyResponse(upstream);
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
  return proxyToApi(request, path, { allowPost: true });
}
