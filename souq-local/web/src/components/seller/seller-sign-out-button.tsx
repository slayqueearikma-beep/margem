"use client";

import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";

export function SellerSignOutButton() {
  const router = useRouter();
  const t = useTranslations("sellerPortal");

  return (
    <button
      type="button"
      className="text-sm text-[var(--muted)]"
      onClick={async () => {
        await fetch("/api/seller/auth/logout", { method: "POST" });
        router.push("/seller/login");
        router.refresh();
      }}
    >
      {t("signOut")}
    </button>
  );
}
