import { notFound } from "next/navigation";
import { getLocale, getTranslations } from "next-intl/server";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { MediaImage } from "@/components/media-image";
import { TrustBadges } from "@/components/trust-badges";
import { EmptyState } from "@/components/states";
import { Link } from "@/i18n/navigation";
import { ApiError } from "@/lib/api";
import { createFormatters } from "@/lib/format-i18n";
import { truncate } from "@/lib/format";
import { fetchService } from "@/lib/marketplace-api";
import { loadActiveAdvertisements } from "@/lib/marketplace-fetch";
import { resolveMediaUrl } from "@/lib/media";
import { buildPageMetadata, jsonLd } from "@/lib/seo";

type ServiceDetailProps = {
  params: Promise<{ id: string }>;
};

export async function generateMetadata({ params }: ServiceDetailProps) {
  const { id } = await params;
  const t = await getTranslations("meta");
  const locale = await getLocale();
  try {
    const data = await fetchService(id);
    return buildPageMetadata({
      title: data.service.name,
      description: truncate(data.service.description, 155),
      path: `/services/${id}`,
      image: resolveMediaUrl(data.service.image_url),
      type: "article",
      locale,
    });
  } catch {
    return buildPageMetadata({
      title: t("serviceNotFound.title"),
      description: t("serviceNotFound.description"),
      path: `/services/${id}`,
      locale,
    });
  }
}

export default async function ServiceDetailPage({ params }: ServiceDetailProps) {
  const { id } = await params;
  const locale = await getLocale();
  const t = await getTranslations("services");
  const tCommon = await getTranslations("common");
  const tDetail = await getTranslations("serviceDetail");
  const tFormat = await getTranslations("format");
  const { formatPrice } = createFormatters(locale, {
    priceOnRequest: tFormat("priceOnRequest"),
    contactForPrice: tFormat("contactForPrice"),
    priceMad: tFormat("priceMad"),
    newRating: tFormat("newRating"),
    verified: tFormat("verified"),
    verificationPending: tFormat("verificationPending"),
    unavailable: tFormat("unavailable"),
    reviews: tFormat("reviews"),
  });

  let data;
  try {
    data = await fetchService(id);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return (
      <EmptyState
        title={t("unavailableDetailTitle")}
        description={t("unavailableDetailDescription")}
        actionHref={`/services/${id}`}
        actionLabel={tCommon("retry")}
      />
    );
  }

  const { service, seller } = data;
  const ads = await loadActiveAdvertisements("service_detail", {
    city: seller.city,
    listingType: "service",
  });
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Service",
    name: service.name,
    description: service.description,
    provider: {
      "@type": "LocalBusiness",
      name: seller.business_name,
    },
  };

  return (
    <article className="grid gap-8 lg:grid-cols-2">
      {ads[0] ? (
        <div className="lg:col-span-2">
          <AdvertisementBanner ad={ads[0]} placement="service_detail" />
        </div>
      ) : null}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonLd(structuredData) }}
      />
      <div className="space-y-4">
        <div className="overflow-hidden rounded-3xl border border-[var(--border)] bg-white">
          <MediaImage
            src={resolveMediaUrl(service.image_url)}
            alt={service.name}
            className="aspect-square w-full object-cover"
          />
        </div>
      </div>
      <div className="space-y-6">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-[var(--primary)]">
            {tDetail("label")}
          </p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight">{service.name}</h1>
          <p className="mt-4 text-2xl font-semibold text-[var(--primary)]">
            {formatPrice(service.price_mad, service.price_negotiable)}
          </p>
        </div>
        <TrustBadges verified={seller.verified} />
        <p className="text-[var(--muted)]">{service.description}</p>
        {service.coverage_areas && service.coverage_areas.length > 0 ? (
          <p className="text-sm text-[var(--muted)]">
            {tCommon("coverage", { areas: service.coverage_areas.join(", ") })}
          </p>
        ) : null}
        <div className="rounded-2xl border border-[var(--border)] bg-white p-5">
          <p className="text-sm font-semibold">{tCommon("offeredBy")}</p>
          <Link
            href={`/sellers/${seller.id}`}
            className="mt-2 inline-flex text-lg font-semibold text-[var(--primary)]"
          >
            {seller.business_name}
          </Link>
        </div>
        <div className="rounded-2xl bg-[var(--primary-muted)] p-5 text-sm text-[var(--muted)]">
          {t("contactNote")}
        </div>
      </div>
    </article>
  );
}
