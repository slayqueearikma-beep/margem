"use client";

import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";

type PaginationNavProps = {
  basePath: string;
  offset: number;
  limit: number;
  hasMore: boolean;
  total?: number;
  params?: Record<string, string | undefined>;
};

function buildHref(
  basePath: string,
  offset: number,
  params?: Record<string, string | undefined>,
): string {
  const query = new URLSearchParams();
  if (offset > 0) query.set("offset", String(offset));
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value) query.set(key, value);
    }
  }
  const serialized = query.toString();
  return serialized ? `${basePath}?${serialized}` : basePath;
}

export function PaginationNav({
  basePath,
  offset,
  limit,
  hasMore,
  total,
  params,
}: PaginationNavProps) {
  const t = useTranslations("pagination");
  const prevOffset = Math.max(0, offset - limit);
  const nextOffset = offset + limit;
  const showPrev = offset > 0;
  const showNext = hasMore;

  if (!showPrev && !showNext) return null;

  return (
    <nav
      className="flex flex-wrap items-center justify-between gap-3 border-t border-[var(--border)] pt-6"
      aria-label={t("ariaLabel")}
    >
      <p className="text-sm text-[var(--muted)]">
        {typeof total === "number"
          ? t("results", { total })
          : t("showingFrom", { start: offset + 1 })}
      </p>
      <div className="flex gap-2">
        {showPrev ? (
          <Link
            href={buildHref(basePath, prevOffset, params)}
            className="rounded-full border border-[var(--border)] bg-white px-4 py-2 text-sm font-semibold hover:border-[var(--primary)]"
          >
            {t("previous")}
          </Link>
        ) : null}
        {showNext ? (
          <Link
            href={buildHref(basePath, nextOffset, params)}
            className="rounded-full bg-[var(--primary)] px-4 py-2 text-sm font-semibold text-white"
          >
            {t("loadMore")}
          </Link>
        ) : null}
      </div>
    </nav>
  );
}
