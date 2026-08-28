import { NextResponse } from "next/server";
import { getServerApiBaseUrl } from "@/lib/config";
import { SELLER_TOKEN_COOKIE } from "@/lib/seller-auth";

export async function POST(request: Request) {
  let payload: { email?: string; password?: string };
  try {
    payload = (await request.json()) as { email?: string; password?: string };
  } catch {
    return NextResponse.json({ detail: "Invalid request body." }, { status: 400 });
  }

  const email = payload.email?.trim().toLowerCase();
  const password = payload.password;
  if (!email || !password) {
    return NextResponse.json({ detail: "Email and password are required." }, { status: 400 });
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${getServerApiBaseUrl()}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ email, password }),
      cache: "no-store",
    });
  } catch {
    return NextResponse.json({ detail: "Authentication service unavailable." }, { status: 503 });
  }

  if (!upstream.ok) {
    const body = (await upstream.json().catch(() => ({}))) as { detail?: string };
    return NextResponse.json(
      { detail: body.detail || "Invalid email or password." },
      { status: upstream.status },
    );
  }

  const data = (await upstream.json()) as { access_token?: string };
  if (!data.access_token) {
    return NextResponse.json({ detail: "Authentication failed." }, { status: 502 });
  }

  const response = NextResponse.json({ status: "ok" });
  response.cookies.set(SELLER_TOKEN_COOKIE, data.access_token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 60 * 60 * 8,
  });
  return response;
}
