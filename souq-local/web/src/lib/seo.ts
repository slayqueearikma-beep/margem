import type { Metadata } from "next";
import { getSiteUrl } from "./config";

import { intlLocale } from "@/i18n/locale";
import type { AppLocale } from "@/i18n/routing";

type PageMetaInput = {
  title: string;
  description: string;
  path?: string;
  image?: string;
  type?: "website" | "article";
  locale?: AppLocale | string;
};

function openGraphLocale(locale: string): string {
  return intlLocale(locale).replace("-", "_");
}

export function buildPageMetadata({
  title,
  description,
  path = "",
  image,
  type = "website",
  locale = "ar",
}: PageMetaInput): Metadata {
  const siteUrl = getSiteUrl();
  const canonical = `${siteUrl}${path.startsWith("/") ? path : `/${path}`}`;
  const ogImage = image || `${siteUrl}/opengraph-image`;

  return {
    title,
    description,
    alternates: { canonical },
    openGraph: {
      title,
      description,
      url: canonical,
      siteName: "Dribex",
      locale: openGraphLocale(locale),
      type,
      images: [{ url: ogImage, width: 1200, height: 630, alt: title }],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: [ogImage],
    },
    robots: {
      index: true,
      follow: true,
    },
  };
}

export { safeJsonLd as jsonLd } from "./security";
