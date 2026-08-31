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
import { fetchProduct } from "@/lib/marketplace-api";
import { loadActiveAdvertisements } from "@/lib/marketplace-fetch";
import { resolveMediaUrl } from "@/lib/media";
import { buildPageMetadata, jsonLd } from "@/lib/seo";

type ProductDetailProps = {
  params: Promise<{ id: string }>;
};

export async function generateMetadata({ params }: ProductDetailProps) {
  const { id } = await params;
  const t = await getTranslations("meta");
  const locale = await getLocale();
  try {
    const data = await fetchProduct(id);
    return buildPageMetadata({
      title: data.product.name,
      description: truncate(data.product.description, 155),
      path: `/products/${id}`,
      image: resolveMediaUrl(data.product.image_url),
      type: "article",
      locale,
    });
  } catch {
    return buildPageMetadata({
      title: t("productNotFound.title"),
      description: t("productNotFound.description"),
      path: `/products/${id}`,
      locale,
    });
  }
}

export default async function ProductDetailPage({ params }: ProductDetailProps) {
  const { id } = await params;
  const locale = await getLocale();
  const t = await getTranslations("products");
  const tCommon = await getTranslations("common");
  const tDetail = await getTranslations("productDetail");
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
    data = await fetchProduct(id);
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) notFound();
    return (
      <EmptyState
        title={t("unavailableDetailTitle")}
        description={t("unavailableDetailDescription")}
        actionHref={`/products/${id}`}
        actionLabel={tCommon("retry")}
      />
    );
  }

  const { product, seller } = data;
  const ads = await loadActiveAdvertisements("product_detail", {
    city: seller.city,
    categorySlug: product.category_slug,
    listingType: "product",
  });
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "Product",
    name: product.name,
    description: product.description,
    image: resolveMediaUrl(product.image_url),
    offers: {
      "@type": "Offer",
      priceCurrency: "MAD",
      price: product.price_mad ?? undefined,
      availability: product.is_available
        ? "https://schema.org/InStock"
        : "https://schema.org/OutOfStock",
    },
  };

  return (
    <article className="grid gap-8 lg:grid-cols-2">
      {ads[0] ? (
        <div className="lg:col-span-2">
          <AdvertisementBanner ad={ads[0]} placement="product_detail" />
        </div>
      ) : null}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonLd(structuredData) }}
      />
      <div className="space-y-4">
        <div className="overflow-hidden rounded-3xl border border-[var(--border)] bg-white">
          <MediaImage
            src={resolveMediaUrl(product.image_url)}
            alt={product.name}
            className="aspect-square w-full object-cover"
          />
        </div>
      </div>
      <div className="space-y-6">
        <div>
          <p className="text-sm font-semibold uppercase tracking-wide text-[var(--primary)]">
            {tDetail("label")}
          </p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight">{product.name}</h1>
          <p className="mt-4 text-2xl font-semibold text-[var(--primary)]">
            {formatPrice(product.price_mad, product.price_negotiable)}
          </p>
        </div>
        <div className="flex flex-wrap gap-2 text-sm text-[var(--muted)]">
          {product.category_slug ? (
            <span>{tCommon("categoryLabel", { slug: product.category_slug })}</span>
          ) : null}
          <span>{product.is_available ? tCommon("available") : tCommon("unavailable")}</span>
        </div>
        <TrustBadges verified={seller.verified} />
        <p className="text-[var(--muted)]">{product.description}</p>
        <div className="rounded-2xl border border-[var(--border)] bg-white p-5">
          <p className="text-sm font-semibold">{tCommon("soldBy")}</p>
          <Link
            href={`/sellers/${seller.id}`}
            className="mt-2 inline-flex text-lg font-semibold text-[var(--primary)]"
          >
            {seller.business_name}
          </Link>
          <p className="mt-1 text-sm text-[var(--muted)]">
            {tDetail("sellerRating", {
              city: seller.city,
              rating: seller.average_rating.toLocaleString(locale === "ar" ? "ar-MA" : locale === "fr" ? "fr-MA" : "en-MA", { maximumFractionDigits: 1 }),
              reviewCount: seller.review_count,
            })}
          </p>
        </div>
        <div className="rounded-2xl bg-[var(--primary-muted)] p-5 text-sm text-[var(--muted)]">
          {t("contactNote")}
        </div>
      </div>
    </article>
  );
}
