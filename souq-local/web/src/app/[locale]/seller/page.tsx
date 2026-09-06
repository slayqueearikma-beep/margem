import { getLocale, getTranslations } from "next-intl/server";
import { Link, redirect } from "@/i18n/navigation";
import { SellerSignOutButton } from "@/components/seller/seller-sign-out-button";
import { getSellerSession } from "@/lib/seller-session";

export default async function SellerHubPage() {
  const session = await getSellerSession();
  if (!session) {
    redirect({ href: "/seller/login", locale: await getLocale() });
    return null;
  }

  const { profile } = session;
  const t = await getTranslations("sellerPortal");
  const tCommon = await getTranslations("common");

  return (
    <div className="space-y-8">
      <div>
        <p className="text-sm font-semibold uppercase tracking-wide text-[var(--primary)]">
          {t("hubLabel")}
        </p>
        <h1 className="mt-2 text-3xl font-bold">{profile.business_name}</h1>
        <p className="mt-2 text-sm text-[var(--muted)]">{t("hubTitle")}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Link
          href="/seller/products/new"
          className="rounded-2xl border border-[var(--border)] bg-white p-5 font-semibold text-[var(--primary)]"
        >
          {t("addProduct")}
        </Link>
        <Link
          href="/seller/services/new"
          className="rounded-2xl border border-[var(--border)] bg-white p-5 font-semibold text-[var(--primary)]"
        >
          {t("addService")}
        </Link>
      </div>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{t("yourProducts")}</h2>
        {profile.products.length > 0 ? (
          <ul className="space-y-2">
            {profile.products.map((product) => (
              <li
                key={product.id}
                className="flex items-center justify-between rounded-xl border border-[var(--border)] bg-white px-4 py-3"
              >
                <span>{product.name}</span>
                <Link
                  href={`/seller/products/${product.id}/edit`}
                  className="text-sm font-medium text-[var(--primary)]"
                >
                  {tCommon("edit")}
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-[var(--muted)]">{t("noProducts")}</p>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{t("yourServices")}</h2>
        {profile.services.length > 0 ? (
          <ul className="space-y-2">
            {profile.services.map((service) => (
              <li
                key={service.id}
                className="flex items-center justify-between rounded-xl border border-[var(--border)] bg-white px-4 py-3"
              >
                <span>{service.name}</span>
                <Link
                  href={`/seller/services/${service.id}/edit`}
                  className="text-sm font-medium text-[var(--primary)]"
                >
                  {tCommon("edit")}
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-[var(--muted)]">{t("noServices")}</p>
        )}
      </section>

      <SellerSignOutButton />
    </div>
  );
}
