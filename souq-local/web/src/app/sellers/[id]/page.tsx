import { notFound } from "next/navigation";
import { ProductCard, ServiceCard } from "@/components/listing-cards";
import { TrustBadges } from "@/components/trust-badges";
import { EmptyState } from "@/components/states";
import { ApiError } from "@/lib/api";
import {
  externalHref,
  formatRating,
  truncate,
  verificationLabel,
} from "@/lib/format";
import { loadReviews, loadSeller } from "@/lib/marketplace-fetch";
import { resolveMediaUrl } from "@/lib/media";
import { buildPageMetadata, jsonLd } from "@/lib/seo";

type SellerDetailProps = {
  params: Promise<{ id: string }>;
};

export async function generateMetadata({ params }: SellerDetailProps) {
  const { id } = await params;
  try {
    const sellerOutcome = await loadSeller(id);
    if (!sellerOutcome.ok) {
      return buildPageMetadata({
        title: "Business not found",
        description: "This seller profile is unavailable.",
        path: `/sellers/${id}`,
      });
    }
    const seller = sellerOutcome.data;
    return buildPageMetadata({
      title: seller.business_name,
      description: truncate(seller.description, 155),
      path: `/sellers/${id}`,
      image: resolveMediaUrl(seller.cover_image_url || seller.logo_image_url),
    });
  } catch {
    return buildPageMetadata({
      title: "Business not found",
      description: "This seller profile is unavailable.",
      path: `/sellers/${id}`,
    });
  }
}

export default async function SellerDetailPage({ params }: SellerDetailProps) {
  const { id } = await params;

  const sellerOutcome = await loadSeller(id);
  if (!sellerOutcome.ok) {
    if (sellerOutcome.error instanceof ApiError && sellerOutcome.error.status === 404) {
      notFound();
    }
    return (
      <EmptyState
        title="Profile unavailable"
        description={sellerOutcome.error.message}
        actionHref={`/sellers/${id}`}
        actionLabel="Retry"
      />
    );
  }
  const seller = sellerOutcome.data;

  const reviewsOutcome = await loadReviews(id);
  const reviews = reviewsOutcome.ok ? reviewsOutcome.data : [];
  const website = externalHref(seller.website_url);
  const verification = verificationLabel(seller.verification_status);

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "LocalBusiness",
    name: seller.business_name,
    description: seller.description,
    address: seller.address,
    telephone: seller.phone,
    url: website || undefined,
    aggregateRating:
      seller.review_count > 0
        ? {
            "@type": "AggregateRating",
            ratingValue: seller.average_rating,
            reviewCount: seller.review_count,
          }
        : undefined,
  };

  return (
    <div className="space-y-10">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonLd(structuredData) }}
      />

      <section className="overflow-hidden rounded-3xl border border-[var(--border)] bg-white">
        <div className="relative aspect-[21/9] bg-[var(--cream)]">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={resolveMediaUrl(seller.cover_image_url || seller.logo_image_url)}
            alt={seller.business_name}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="space-y-4 p-6 sm:p-8">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <h1 className="text-3xl font-bold tracking-tight">{seller.business_name}</h1>
              <p className="mt-2 text-[var(--muted)]">{seller.description}</p>
            </div>
            <div className="text-right">
              <p className="text-2xl font-semibold">{formatRating(seller.average_rating)} ★</p>
              <p className="text-sm text-[var(--muted)]">{seller.review_count} reviews</p>
            </div>
          </div>
          <TrustBadges
            verified={seller.verification_status === "verified"}
            premium={seller.is_premium}
          />
          {verification ? (
            <p className="text-sm font-medium text-green-700">{verification}</p>
          ) : null}
          <div className="grid gap-3 text-sm text-[var(--muted)] sm:grid-cols-2">
            <p>{seller.address}</p>
            <p>{seller.city}</p>
            {seller.phone ? <p>Phone: {seller.phone}</p> : null}
            {website ? (
              <p>
                Website:{" "}
                <a
                  href={website}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-semibold text-[var(--primary)] underline-offset-2 hover:underline"
                >
                  {seller.website_url.replace(/^https?:\/\//, "")}
                </a>
              </p>
            ) : null}
          </div>
          <div className="rounded-2xl bg-[var(--primary-muted)] p-4 text-sm text-[var(--muted)]">
            Messaging, favorites, and seller tools require the Dribex mobile app.
          </div>
        </div>
      </section>

      {seller.products.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-xl font-semibold">Products</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {seller.products.map((product) => (
              <ProductCard
                key={product.id}
                product={{
                  id: product.id,
                  seller_id: seller.id,
                  seller_name: seller.business_name,
                  seller_city: seller.city,
                  seller_verified: seller.verification_status === "verified",
                  seller_premium: seller.is_premium,
                  seller_rating: seller.average_rating,
                  name: product.name,
                  description: product.description,
                  price_mad: product.price_mad,
                  price_negotiable: product.price_negotiable,
                  image_url: product.image_url,
                  category_slug: product.category_slug,
                  is_available: product.is_available,
                }}
              />
            ))}
          </div>
        </section>
      ) : null}

      {seller.services.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-xl font-semibold">Services</h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {seller.services.map((service) => (
              <ServiceCard
                key={service.id}
                service={{
                  id: service.id,
                  seller_id: seller.id,
                  seller_name: seller.business_name,
                  seller_city: seller.city,
                  seller_verified: seller.verification_status === "verified",
                  seller_premium: seller.is_premium,
                  seller_rating: seller.average_rating,
                  name: service.name,
                  description: service.description,
                  price_mad: service.price_mad,
                  price_negotiable: service.price_negotiable,
                  image_url: service.image_url,
                  category_slug: service.category_slug,
                  is_available: service.is_available,
                }}
              />
            ))}
          </div>
        </section>
      ) : null}

      {reviews.length > 0 ? (
        <section className="space-y-4">
          <h2 className="text-xl font-semibold">Reviews</h2>
          <div className="space-y-3">
            {reviews.slice(0, 6).map((review) => (
              <div
                key={review.id}
                className="rounded-2xl border border-[var(--border)] bg-white p-5"
              >
                <div className="flex items-center justify-between gap-3">
                  <p className="font-semibold">{review.buyer_display_name}</p>
                  <p className="text-sm text-[var(--muted)]">
                    {review.overall_rating.toFixed(1)} ★
                  </p>
                </div>
                {review.comment ? (
                  <p className="mt-2 text-sm text-[var(--muted)]">{review.comment}</p>
                ) : null}
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
