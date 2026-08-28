import Link from "next/link";
import { notFound } from "next/navigation";
import { AdvertisementBanner } from "@/components/advertisement-banner";
import { MediaImage } from "@/components/media-image";
import { ListingVideo } from "@/components/listing-video";
import { TrustBadges } from "@/components/trust-badges";
import { EmptyState } from "@/components/states";
import { ApiError } from "@/lib/api";
import { formatPrice, truncate } from "@/lib/format";
import { fetchService } from "@/lib/marketplace-api";
import { loadActiveAdvertisements } from "@/lib/marketplace-fetch";
import { resolveMediaUrl } from "@/lib/media";
import { buildPageMetadata, jsonLd } from "@/lib/seo";

type ServiceDetailProps = {
  params: Promise<{ id: string }>;
};

export async function generateMetadata({ params }: ServiceDetailProps) {
  const { id } = await params;
  try {
    const data = await fetchService(id);
    return buildPageMetadata({
      title: data.service.name,
      description: truncate(data.service.description, 155),
      path: `/services/${id}`,
      image: resolveMediaUrl(data.service.image_url),
      type: "article",
    });
  } catch {
    return buildPageMetadata({
      title: "Service not found",
      description: "This service listing is unavailable.",
      path: `/services/${id}`,
    });
  }
}

export default async function ServiceDetailPage({ params }: ServiceDetailProps) {
  const { id } = await params;

  let data;
  try {
    data = await fetchService(id);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return (
      <EmptyState
        title="Service unavailable"
        description="We couldn't load this service right now."
        actionHref={`/services/${id}`}
        actionLabel="Retry"
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
        {service.video_url ? (
          <ListingVideo src={service.video_url} title={`${service.name} video`} />
        ) : null}
      </div>
      <div className="space-y-6">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-[var(--primary)]">
            Service
          </p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight">{service.name}</h1>
          <p className="mt-4 text-2xl font-semibold text-[var(--primary)]">
            {formatPrice(service.price_mad, service.price_negotiable)}
          </p>
        </div>
        <TrustBadges verified={seller.verified} premium={seller.premium} />
        <p className="text-[var(--muted)]">{service.description}</p>
        {service.coverage_areas && service.coverage_areas.length > 0 ? (
          <p className="text-sm text-[var(--muted)]">
            Coverage: {service.coverage_areas.join(", ")}
          </p>
        ) : null}
        <div className="rounded-2xl border border-[var(--border)] bg-white p-5">
          <p className="text-sm font-semibold">Offered by</p>
          <Link
            href={`/sellers/${seller.id}`}
            className="mt-2 inline-flex text-lg font-semibold text-[var(--primary)]"
          >
            {seller.business_name}
          </Link>
        </div>
        <div className="rounded-2xl bg-[var(--primary-muted)] p-5 text-sm text-[var(--muted)]">
          Book or inquire through the Dribex mobile app. This public page is for discovery only.
        </div>
      </div>
    </article>
  );
}
