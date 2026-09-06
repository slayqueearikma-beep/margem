"use client";

import { FormEvent, useState } from "react";
import { useTranslations } from "next-intl";
import { Link, useRouter } from "@/i18n/navigation";

type ListingKind = "product" | "service";

type ListingEditorFormProps = {
  kind: ListingKind;
  sellerId: string;
  listingId?: string;
  initial?: {
    name?: string;
    description?: string;
    priceMad?: string;
    imageUrl?: string;
    isAvailable?: boolean;
  };
};

export function ListingEditorForm({
  kind,
  sellerId,
  listingId,
  initial,
}: ListingEditorFormProps) {
  const router = useRouter();
  const t = useTranslations("sellerPortal");
  const tCommon = useTranslations("common");
  const isEditing = Boolean(listingId);

  const [name, setName] = useState(initial?.name || "");
  const [description, setDescription] = useState(initial?.description || "");
  const [priceMad, setPriceMad] = useState(initial?.priceMad || "");
  const [imageUrl, setImageUrl] = useState(initial?.imageUrl || "");
  const [isAvailable, setIsAvailable] = useState(initial?.isAvailable ?? true);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  const title = isEditing
    ? kind === "product"
      ? t("editProduct")
      : t("editService")
    : kind === "product"
      ? t("addProductForm")
      : t("addServiceForm");

  const publishLabel =
    kind === "product" ? t("publishProduct") : t("publishService");

  async function saveListing(event: FormEvent) {
    event.preventDefault();
    setError("");
    setSaving(true);

    const payload: Record<string, unknown> = {
      name: name.trim(),
      description: description.trim(),
      image_url: imageUrl.trim(),
    };

    if (kind === "product") {
      if (priceMad.trim()) {
        payload.price_mad = Number(priceMad);
        payload.pricing_type = "fixed";
      } else {
        payload.pricing_type = "offer";
      }
      if (isEditing) payload.is_available = isAvailable;
    } else {
      if (priceMad.trim()) {
        payload.price_mad = Number(priceMad);
        payload.pricing_type = "fixed";
      } else {
        payload.pricing_type = "offer";
      }
      if (isEditing) payload.is_available = isAvailable;
    }

    const endpoint = isEditing
      ? `/api/seller/sellers/${sellerId}/${kind}s/${listingId}`
      : `/api/seller/sellers/${sellerId}/${kind}s`;

    try {
      const response = await fetch(endpoint, {
        method: isEditing ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!response.ok) {
        const body = (await response.json().catch(() => ({}))) as { detail?: string };
        throw new Error(body.detail || t("saveListingError"));
      }
      const saved = (await response.json()) as { id: string };
      router.push(`/${kind}s/${saved.id}`);
      router.refresh();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : t("saveListingError"));
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={saveListing} className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-2xl font-bold">{title}</h1>
        <Link href="/seller" className="text-sm font-medium text-[var(--primary)]">
          {t("sellerHubLink")}
        </Link>
      </div>

      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}

      <label className="block space-y-1">
        <span className="text-sm font-medium">{tCommon("name")}</span>
        <input
          required
          value={name}
          onChange={(event) => setName(event.target.value)}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium">{tCommon("description")}</span>
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          rows={4}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium">{tCommon("priceMad")}</span>
        <input
          value={priceMad}
          onChange={(event) => setPriceMad(event.target.value)}
          inputMode="decimal"
          placeholder={t("pricePlaceholder")}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium">{tCommon("imageUrl")}</span>
        <input
          value={imageUrl}
          onChange={(event) => setImageUrl(event.target.value)}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      {isEditing ? (
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={isAvailable}
            onChange={(event) => setIsAvailable(event.target.checked)}
          />
          {t("availableCheckbox")}
        </label>
      ) : null}

      <button
        type="submit"
        disabled={saving}
        className="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
      >
        {saving ? t("saving") : isEditing ? t("saveChanges") : publishLabel}
      </button>
    </form>
  );
}
