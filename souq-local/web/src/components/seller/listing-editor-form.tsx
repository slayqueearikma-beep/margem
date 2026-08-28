"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useEffect, useState } from "react";
import { ListingVideoField } from "@/components/seller/listing-video-field";
import type { AppLocale } from "@/lib/i18n/video-messages";
import type { SellerEntitlements } from "@/lib/seller-auth";

type ListingKind = "product" | "service";

type ListingEditorFormProps = {
  locale: AppLocale;
  kind: ListingKind;
  sellerId: string;
  listingId?: string;
  initial?: {
    name?: string;
    description?: string;
    priceMad?: string;
    imageUrl?: string;
    videoUrl?: string;
    isAvailable?: boolean;
  };
};

export function ListingEditorForm({
  locale,
  kind,
  sellerId,
  listingId,
  initial,
}: ListingEditorFormProps) {
  const router = useRouter();
  const isEditing = Boolean(listingId);

  const [name, setName] = useState(initial?.name || "");
  const [description, setDescription] = useState(initial?.description || "");
  const [priceMad, setPriceMad] = useState(initial?.priceMad || "");
  const [imageUrl, setImageUrl] = useState(initial?.imageUrl || "");
  const [videoUrl, setVideoUrl] = useState(initial?.videoUrl || "");
  const [isAvailable, setIsAvailable] = useState(initial?.isAvailable ?? true);
  const [entitlements, setEntitlements] = useState<SellerEntitlements | null>(null);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void refreshEntitlements();
  }, []);

  async function refreshEntitlements() {
    const response = await fetch("/api/seller/subscriptions/entitlements");
    if (response.ok) {
      setEntitlements((await response.json()) as SellerEntitlements);
    }
  }

  const videoUploadsEnabled = entitlements?.seller?.video_uploads_enabled ?? false;
  const rewardedAdsEnabled = entitlements?.rewarded_ads_enabled ?? true;

  async function saveListing(event: FormEvent) {
    event.preventDefault();
    setError("");
    setSaving(true);

    const payload: Record<string, unknown> = {
      name: name.trim(),
      description: description.trim(),
      image_url: imageUrl.trim(),
      video_url: videoUrl.trim(),
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
        throw new Error(body.detail || "Could not save listing.");
      }
      const saved = (await response.json()) as { id: string };
      router.push(`/${kind}s/${saved.id}`);
      router.refresh();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : "Could not save listing.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={saveListing} className="mx-auto max-w-2xl space-y-6">
      <div className="flex items-center justify-between gap-4">
        <h1 className="text-2xl font-bold">
          {isEditing ? `Edit ${kind}` : `Add ${kind}`}
        </h1>
        <Link href="/seller" className="text-sm font-medium text-[var(--primary)]">
          Seller hub
        </Link>
      </div>

      {error ? (
        <p className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}

      <label className="block space-y-1">
        <span className="text-sm font-medium">Name</span>
        <input
          required
          value={name}
          onChange={(event) => setName(event.target.value)}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium">Description</span>
        <textarea
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          rows={4}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium">Price (MAD)</span>
        <input
          value={priceMad}
          onChange={(event) => setPriceMad(event.target.value)}
          inputMode="decimal"
          placeholder="Leave empty for price on request"
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium">Image URL</span>
        <input
          value={imageUrl}
          onChange={(event) => setImageUrl(event.target.value)}
          className="w-full rounded-xl border border-[var(--border)] px-3 py-2"
        />
      </label>

      <ListingVideoField
        locale={locale}
        videoUploadsEnabled={videoUploadsEnabled}
        rewardedAdsEnabled={rewardedAdsEnabled}
        initialVideoUrl={initial?.videoUrl || ""}
        value={videoUrl}
        onChange={setVideoUrl}
        onError={(message) => setError(message)}
        onUnlock={refreshEntitlements}
      />

      {isEditing ? (
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={isAvailable}
            onChange={(event) => setIsAvailable(event.target.checked)}
          />
          Available
        </label>
      ) : null}

      <button
        type="submit"
        disabled={saving}
        className="rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
      >
        {saving ? "Saving…" : isEditing ? "Save changes" : `Publish ${kind}`}
      </button>
    </form>
  );
}
