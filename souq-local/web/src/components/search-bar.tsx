"use client";

import { useTranslations } from "next-intl";
import { FormEvent, useState } from "react";
import { useRouter } from "@/i18n/navigation";

export function SearchBar({
  defaultQuery = "",
  defaultMode = "all",
}: {
  defaultQuery?: string;
  defaultMode?: string;
}) {
  const router = useRouter();
  const t = useTranslations("search");
  const [query, setQuery] = useState(defaultQuery);
  const [mode, setMode] = useState(defaultMode);

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    const params = new URLSearchParams();
    const trimmed = query.trim();
    if (trimmed) params.set("q", trimmed);
    params.set("mode", mode);
    router.push(`/search?${params.toString()}`);
  }

  return (
    <form
      onSubmit={onSubmit}
      className="flex flex-col gap-3 rounded-2xl border border-[var(--border)] bg-white p-3 shadow-sm sm:flex-row sm:items-center"
    >
      <input
        type="search"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder={t("placeholder")}
        className="min-w-0 flex-1 rounded-xl border border-[var(--border)] px-4 py-3 text-sm outline-none ring-[var(--primary)] focus:ring-2"
      />
      <select
        value={mode}
        onChange={(event) => setMode(event.target.value)}
        className="rounded-xl border border-[var(--border)] px-3 py-3 text-sm"
      >
        <option value="all">{t("modeAll")}</option>
        <option value="products">{t("modeProducts")}</option>
        <option value="services">{t("modeServices")}</option>
        <option value="sellers">{t("modeBusinesses")}</option>
      </select>
      <button
        type="submit"
        className="rounded-xl bg-[var(--primary)] px-5 py-3 text-sm font-semibold text-white"
      >
        {t("submit")}
      </button>
    </form>
  );
}
