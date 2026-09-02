import { intlLocale } from "@/i18n/locale";

export type FormatMessages = {
  priceOnRequest: string;
  contactForPrice: string;
  priceMad: string;
  newRating: string;
  verified: string;
  verificationPending: string;
  unavailable: string;
  reviews: string;
};

export function createFormatters(locale: string, messages: FormatMessages) {
  const numberLocale = intlLocale(locale);

  function formatPrice(
    amount: number | null | undefined,
    negotiable?: boolean,
  ): string {
    if (negotiable && amount == null) {
      return messages.priceOnRequest;
    }
    if (amount == null) {
      return messages.contactForPrice;
    }
    const formatted = amount.toLocaleString(numberLocale);
    return messages.priceMad.replace("{amount}", formatted);
  }

  function formatRating(value: number): string {
    return value > 0 ? value.toLocaleString(numberLocale, { maximumFractionDigits: 1 }) : messages.newRating;
  }

  function verificationLabel(status: string): string | null {
    if (status === "verified") return messages.verified;
    if (status === "pending") return messages.verificationPending;
    return null;
  }

  function formatReviewCount(count: number): string {
    return messages.reviews.replace("{count}", count.toLocaleString(numberLocale));
  }

  return {
    formatPrice,
    formatRating,
    verificationLabel,
    formatReviewCount,
  };
}
