import { NextResponse } from "next/server";
import { SELLER_TOKEN_COOKIE } from "@/lib/seller-auth";

export async function POST() {
  const response = NextResponse.json({ status: "ok" });
  response.cookies.set(SELLER_TOKEN_COOKIE, "", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  });
  return response;
}
