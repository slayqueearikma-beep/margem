import { getServerApiBaseUrl } from "@/lib/config";

type RouteContext = {
  params: Promise<{ path: string[] }>;
};

async function proxyToApi(request: Request, pathSegments: string[]): Promise<Response> {
  const base = getServerApiBaseUrl();
  const incoming = new URL(request.url);
  const targetPath = pathSegments.join("/");
  const target = `${base}/${targetPath}${incoming.search}`;

  const headers = new Headers();
  const accept = request.headers.get("accept");
  if (accept) headers.set("Accept", accept);

  const upstream = await fetch(target, {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : await request.arrayBuffer(),
    cache: "no-store",
  });

  const responseHeaders = new Headers();
  const contentType = upstream.headers.get("content-type");
  if (contentType) responseHeaders.set("Content-Type", contentType);
  const cacheControl = upstream.headers.get("cache-control");
  if (cacheControl) responseHeaders.set("Cache-Control", cacheControl);

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
