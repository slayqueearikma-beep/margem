import Link from "next/link";
import { MediaImage } from "@/components/media-image";
import { formatPrice, formatRating, truncate } from "@/lib/format";
import { resolveMediaUrl } from "@/lib/media";
import type { ProductSearchOut, SellerSummary, ServiceSearchOut } from "@/lib/types";
import { TrustBadges } from "./trust-badges";

function AvailabilityBadge({ available }: { available: boolean }) {
  if (available) return null;
  return (
    <span className="rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-semibold uppercase text-[var(--muted)]">
      Unavailable
    </span>
  );
}

export function ProductCard({ product }: { product: ProductSearchOut }) {
  return (
    <Link
      href={`/products/${product.id}`}
      className="group overflow-hidden rounded-2xl border border-[var(--border)] bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <div className="relative aspect-[4/3] overflow-hidden bg-[var(--cream)]">
        <MediaImage
          src={resolveMediaUrl(product.image_url)}
          alt={product.name}
          className="h-full w-full object-cover transition group-hover:scale-105"
        />
      </div>
      <div className="space-y-2 p-4">
        <div className="flex items-start justify-between gap-2">
          <h3 className="line-clamp-2 text-sm font-semibold">{product.name}</h3>
          <span className="shrink-0 text-sm font-semibold text-[var(--primary)]">
            {formatPrice(product.price_mad, product.price_negotiable)}
          </span>
        </div>
        <p className="line-clamp-2 text-xs text-[var(--muted)]">
          {truncate(product.description, 100)}
        </p>
        <div className="flex flex-wrap items-center gap-2 text-xs text-[var(--muted)]">
          {product.category_slug ? <span>{product.category_slug}</span> : null}
          <span>{product.seller_city}</span>
        </div>
        <div className="flex items-center justify-between gap-2 text-xs text-[var(--muted)]">
          <span>{product.seller_name}</span>
          <span>{formatRating(product.seller_rating)} ★</span>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <TrustBadges verified={product.seller_verified} />
          <AvailabilityBadge available={product.is_available} />
        </div>
      </div>
    </Link>
  );
}

export function ServiceCard({ service }: { service: ServiceSearchOut }) {
  return (
    <Link
      href={`/services/${service.id}`}
      className="group overflow-hidden rounded-2xl border border-[var(--border)] bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <div className="relative aspect-[4/3] overflow-hidden bg-[var(--primary-muted)]">
        <MediaImage
          src={resolveMediaUrl(service.image_url)}
          alt={service.name}
          className="h-full w-full object-cover transition group-hover:scale-105"
        />
      </div>
      <div className="space-y-2 p-4">
        <div className="flex items-start justify-between gap-2">
          <h3 className="line-clamp-2 text-sm font-semibold">{service.name}</h3>
          <span className="shrink-0 text-sm font-semibold text-[var(--primary)]">
            {formatPrice(service.price_mad, service.price_negotiable)}
          </span>
        </div>
        <p className="line-clamp-2 text-xs text-[var(--muted)]">
          {truncate(service.description, 100)}
        </p>
        <div className="flex flex-wrap items-center gap-2 text-xs text-[var(--muted)]">
          {service.category_slug ? <span>{service.category_slug}</span> : null}
          <span>{service.seller_city}</span>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <TrustBadges verified={service.seller_verified} />
          <AvailabilityBadge available={service.is_available} />
        </div>
      </div>
    </Link>
  );
}

export function SellerCard({ seller }: { seller: SellerSummary }) {
  return (
    <Link
      href={`/sellers/${seller.id}`}
      className="group overflow-hidden rounded-2xl border border-[var(--border)] bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <div className="relative aspect-[16/9] overflow-hidden bg-[var(--cream)]">
        <MediaImage
          src={resolveMediaUrl(seller.cover_image_url || seller.logo_image_url)}
          alt={seller.business_name}
          className="h-full w-full object-cover transition group-hover:scale-105"
        />
      </div>
      <div className="space-y-2 p-4">
        <div className="flex items-start justify-between gap-2">
          <h3 className="text-base font-semibold">{seller.business_name}</h3>
          <span className="text-sm text-[var(--muted)]">{formatRating(seller.average_rating)} ★</span>
        </div>
        <p className="line-clamp-2 text-sm text-[var(--muted)]">{seller.description}</p>
        <div className="flex items-center justify-between text-xs text-[var(--muted)]">
          <span>{seller.city}</span>
          <span>{seller.review_count} reviews</span>
        </div>
        <TrustBadges
          verified={seller.verification_status === "verified"}
        />
      </div>
    </Link>
  );
}
