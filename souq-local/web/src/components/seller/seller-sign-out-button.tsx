"use client";

import { useRouter } from "next/navigation";

export function SellerSignOutButton() {
  const router = useRouter();

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
      Sign out
    </button>
  );
}
