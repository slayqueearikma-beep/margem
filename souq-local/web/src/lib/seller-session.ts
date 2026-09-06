import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { getServerApiBaseUrl } from "@/lib/config";
import { SELLER_TOKEN_COOKIE, type SellerProfile } from "@/lib/seller-auth";

export async function getSellerSession(): Promise<{ token: string; profile: SellerProfile } | null> {
  const token = (await cookies()).get(SELLER_TOKEN_COOKIE)?.value;
  if (!token) return null;

  const response = await fetch(`${getServerApiBaseUrl()}/sellers/me`, {
    headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    cache: "no-store",
  });
  if (!response.ok) return null;
  const profile = (await response.json()) as SellerProfile;
  return { token, profile };
}

export async function requireSellerSession(): Promise<{ token: string; profile: SellerProfile }> {
  const session = await getSellerSession();
  if (!session) redirect("/seller/login");
  return session;
}
