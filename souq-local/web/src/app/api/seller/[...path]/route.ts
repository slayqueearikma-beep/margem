import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { getServerApiBaseUrl } from "@/lib/config";
import { SELLER_TOKEN_COOKIE } from "@/lib/seller-auth";

const ALLOWED_PREFIXES = [
  "sellers/",
  "uploads/",
  "subscriptions/",
  "auth/me",
  "billing/checkout/subscription/",
];

function isAllowedSellerProxyPath(path: string): boolean {
  return ALLOWED_PREFIXES.some((prefix) => path === prefix.replace(/\/$/, "") || path.startsWith(prefix));
}

type RouteContext = {
  params: Promise<{ path: string[] }>;
};

async function forward(request: Request, pathSegments: string[]): Promise<Response> {
  const normalized = pathSegments.map((segment) => decodeURIComponent(segment)).join("/");
  if (!normalized || !isAllowedSellerProxyPath(normalized)) {
    return NextResponse.json({ detail: "Path not allowed." }, { status: 403 });
  }

  const token = (await cookies()).get(SELLER_TOKEN_COOKIE)?.value;
  if (!token) {
    return NextResponse.json({ detail: "Seller authentication required." }, { status: 401 });
  }

  const target = `${getServerApiBaseUrl()}/${normalized}`;
  const incoming = new URL(request.url);
  const headers = new Headers();
  headers.set("Authorization", `Bearer ${token}`);
  headers.set("Accept", "application/json");

  const contentType = request.headers.get("content-type");
  if (contentType) headers.set("Content-Type", contentType);

  let body: ArrayBuffer | undefined;
  if (request.method !== "GET" && request.method !== "HEAD") {
    body = await request.arrayBuffer();
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${target}${incoming.search}`, {
      method: request.method,
      headers,
      body: body && body.byteLength > 0 ? body : undefined,
      cache: "no-store",
    });
  } catch {
    return NextResponse.json({ detail: "Upstream API unreachable." }, { status: 503 });
  }

  const responseHeaders = new Headers();
  const upstreamType = upstream.headers.get("content-type");
  if (upstreamType) responseHeaders.set("Content-Type", upstreamType);
  responseHeaders.set("Cache-Control", "no-store");

  return new Response(upstream.body, {
    status: upstream.status,
    headers: responseHeaders,
  });
}

export async function GET(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return forward(request, path);
}

export async function POST(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return forward(request, path);
}

export async function PATCH(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return forward(request, path);
}

export async function PUT(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return forward(request, path);
}

export async function DELETE(request: Request, context: RouteContext) {
  const { path } = await context.params;
  return forward(request, path);
}
