"use client";

import { FormEvent, useState } from "react";
import { useTranslations } from "next-intl";
import { useRouter } from "@/i18n/navigation";

export function SellerLoginForm() {
  const router = useRouter();
  const t = useTranslations("sellerPortal");
  const tCommon = useTranslations("common");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError("");

    const response = await fetch("/api/seller/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });

    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as { detail?: string };
      setError(body.detail || t("loginFailed"));
      setLoading(false);
      return;
    }

    router.push("/seller");
    router.refresh();
  }

  return (
    <form onSubmit={onSubmit} className="mx-auto max-w-md space-y-4 rounded-3xl border border-[var(--border)] bg-white p-6">
      <h1 className="text-2xl font-bold">{t("loginTitle")}</h1>
      <p className="text-sm text-[var(--muted)]">{t("loginDescription")}</p>
      {error ? <p className="text-sm text-red-600">{error}</p> : null}
      <label className="block space-y-1">
        <span className="text-sm font-medium">{tCommon("email")}</span>
        <input
          type="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>
      <label className="block space-y-1">
        <span className="text-sm font-medium">{tCommon("password")}</span>
        <input
          type="password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>
      <button
        type="submit"
        disabled={loading}
        className="w-full rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
      >
        {loading ? t("signingIn") : t("signIn")}
      </button>
    </form>
  );
}
