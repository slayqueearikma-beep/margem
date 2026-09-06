import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";

export default async function NotFound() {
  const t = await getTranslations("notFound");

  return (
    <div className="mx-auto max-w-lg rounded-3xl border border-[var(--border)] bg-white px-6 py-16 text-center">
      <p className="text-sm font-semibold uppercase tracking-[0.2em] text-[var(--primary)]">
        {t("code")}
      </p>
      <h1 className="mt-3 text-2xl font-bold">{t("title")}</h1>
      <p className="mt-3 text-sm text-[var(--muted)]">{t("description")}</p>
      <Link
        href="/"
        className="mt-6 inline-flex rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white"
      >
        {t("backHome")}
      </Link>
    </div>
  );
}
