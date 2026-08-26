import Link from "next/link";
import { formatPrice, formatRating, truncate } from "@/lib/format";
import { resolveMediaUrl } from "@/lib/media";
import type { ProductSearchOut, SellerSummary, ServiceListItem } from "@/lib/types";
import { TrustBadges } from "./trust-badges";

export function ProductCard({ product }: { product: ProductSearchOut }) {
  return (
    <Link
      href={`/products/${product.id}`}
      className="group overflow-hidden rounded-2xl border border-[var(--border)] bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <div className="relative aspect-[4/3] overflow-hidden bg-[var(--cream)]">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={resolveMediaUrl(product.image_url)}
          alt={product.name}
          className="h-full w-full object-cover transition group-hover:scale-105"
          loading="lazy"
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
        <div className="flex items-center justify-between gap-2 text-xs text-[var(--muted)]">
          <span>{product.seller_name}</span>
          <span>{formatRating(product.seller_rating)} ★</span>
        </div>
        <TrustBadges verified={product.seller_verified} premium={product.seller_premium} />
      </div>
    </Link>
  );
}

export function ServiceCard({ service }: { service: ServiceListItem }) {
  return (
    <Link
      href={`/services/${service.id}`}
      className="group overflow-hidden rounded-2xl border border-[var(--border)] bg-white shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
    >
      <div className="relative aspect-[4/3] overflow-hidden bg-[var(--primary-muted)]">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={resolveMediaUrl(service.image_url)}
          alt={service.name}
          className="h-full w-full object-cover transition group-hover:scale-105"
          loading="lazy"
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
        <TrustBadges verified={service.seller_verified} premium={service.seller_premium} />
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
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={resolveMediaUrl(seller.cover_image_url || seller.logo_image_url)}
          alt={seller.business_name}
          className="h-full w-full object-cover transition group-hover:scale-105"
          loading="lazy"
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
          premium={seller.is_premium}
        />
      </div>
    </Link>
  );
}
