"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { FormEvent, useState } from "react";

export function SearchBar({
  defaultQuery = "",
  defaultMode = "all",
}: {
  defaultQuery?: string;
  defaultMode?: string;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [query, setQuery] = useState(defaultQuery);
  const [mode, setMode] = useState(defaultMode);

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    const params = new URLSearchParams(searchParams.toString());
    params.set("q", query.trim());
    params.set("mode", mode);
    params.delete("offset");
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
        placeholder="Search products, services, or businesses..."
        className="min-w-0 flex-1 rounded-xl border border-[var(--border)] px-4 py-3 text-sm outline-none ring-[var(--primary)] focus:ring-2"
      />
      <select
        value={mode}
        onChange={(event) => setMode(event.target.value)}
        className="rounded-xl border border-[var(--border)] px-3 py-3 text-sm"
      >
        <option value="all">All</option>
        <option value="products">Products</option>
        <option value="services">Services</option>
        <option value="sellers">Businesses</option>
      </select>
      <button
        type="submit"
        className="rounded-xl bg-[var(--primary)] px-5 py-3 text-sm font-semibold text-white"
      >
        Search
      </button>
    </form>
  );
}
