"use client";

import { useRef, useState } from "react";
import { ListingVideo } from "@/components/listing-video";
import { RewardedAdVideoRibbon } from "@/components/seller/rewarded-ad-video-ribbon";
import type { AppLocale } from "@/lib/i18n/video-messages";
import { videoMessages } from "@/lib/i18n/video-messages";

const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
const VIDEO_FEATURE = "video_upload";

function resolveSellerUploadUrl(uploadUrl: string): string {
  try {
    const parsed = new URL(uploadUrl, window.location.origin);
    if (parsed.pathname.startsWith("/uploads/")) {
      return `/api/seller${parsed.pathname}`;
    }
  } catch {
    return uploadUrl;
  }
  return uploadUrl;
}

type ListingVideoFieldProps = {
  locale: AppLocale;
  videoUploadsEnabled: boolean;
  rewardedAdsEnabled?: boolean;
  initialVideoUrl?: string;
  value: string;
  onChange: (url: string) => void;
  onError: (message: string) => void;
  onUnlock?: () => void | Promise<void>;
};

async function readVideoDuration(file: File): Promise<number> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement("video");
    video.preload = "metadata";
    video.onloadedmetadata = () => {
      URL.revokeObjectURL(url);
      resolve(video.duration);
    };
    video.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Could not read video metadata"));
    };
    video.src = url;
  });
}

export function ListingVideoField({
  locale,
  videoUploadsEnabled,
  rewardedAdsEnabled = true,
  initialVideoUrl = "",
  value,
  onChange,
  onError,
  onUnlock,
}: ListingVideoFieldProps) {
  const t = videoMessages(locale);
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [unlocking, setUnlocking] = useState(false);
  const [adPlaying, setAdPlaying] = useState(false);
  const displayVideoUrl = value || initialVideoUrl;
  const hasExistingVideo = Boolean(displayVideoUrl.trim());
  const locked = !videoUploadsEnabled;

  async function watchRewardedAd() {
    if (!rewardedAdsEnabled) {
      onError(t.rewardedAdFailed);
      return;
    }

    setUnlocking(true);
    try {
      const sessionRes = await fetch("/api/seller/rewards/sessions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ feature_code: VIDEO_FEATURE }),
      });
      if (!sessionRes.ok) {
        const body = (await sessionRes.json().catch(() => ({}))) as { detail?: string };
        throw new Error(body.detail || t.rewardedAdFailed);
      }
      const session = (await sessionRes.json()) as {
        session_id: string;
        session_token: string;
      };

      setAdPlaying(true);
      await new Promise((resolve) => setTimeout(resolve, 1500));

      const completeRes = await fetch("/api/seller/rewards/complete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          session_id: session.session_id,
          session_token: session.session_token,
          provider: "internal",
        }),
      });
      if (!completeRes.ok) {
        const body = (await completeRes.json().catch(() => ({}))) as { detail?: string };
        throw new Error(body.detail || t.rewardedAdFailed);
      }

      if (onUnlock) {
        await onUnlock();
      }
    } catch (error) {
      onError(error instanceof Error ? error.message : t.rewardedAdFailed);
    } finally {
      setAdPlaying(false);
      setUnlocking(false);
    }
  }

  async function uploadVideo(file: File) {
    if (file.size > MAX_VIDEO_BYTES) {
      onError(t.videoTooLarge);
      return;
    }

    let duration = 0;
    try {
      duration = await readVideoDuration(file);
    } catch {
      onError(t.videoUploadFailed);
      return;
    }

    if (duration <= 0 || duration >= 60) {
      onError(t.videoTooLong);
      return;
    }

    setUploading(true);
    try {
      const contentType = file.type === "video/quicktime" ? "video/quicktime" : "video/mp4";
      const presignRes = await fetch("/api/seller/uploads/presign", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          filename: file.name || "listing.mp4",
          content_type: contentType,
          purpose: "video",
        }),
      });
      if (!presignRes.ok) {
        const body = (await presignRes.json().catch(() => ({}))) as { detail?: string };
        throw new Error(body.detail || t.videoUploadFailed);
      }
      const presign = (await presignRes.json()) as { upload_url: string; public_url: string };

      const uploadRes = await fetch(resolveSellerUploadUrl(presign.upload_url), {
        method: "PUT",
        headers: {
          "Content-Type": contentType,
          "x-ms-blob-type": "BlockBlob",
        },
        body: file,
      });
      if (!uploadRes.ok) {
        throw new Error(t.videoUploadFailed);
      }

      const validateRes = await fetch("/api/seller/uploads/validate-video", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          public_url: presign.public_url,
          content_type: contentType,
          duration_seconds: duration,
        }),
      });
      if (!validateRes.ok) {
        const body = (await validateRes.json().catch(() => ({}))) as { detail?: string };
        throw new Error(body.detail || t.videoUploadFailed);
      }

      onChange(presign.public_url);
    } catch (error) {
      onError(error instanceof Error ? error.message : t.videoUploadFailed);
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <div
      className={`relative space-y-3 rounded-2xl border bg-white p-4 pr-24 ${
        locked ? "border-dashed border-[var(--border)] bg-[var(--background)]" : "border-[var(--border)]"
      }`}
    >
      {locked && rewardedAdsEnabled ? (
        <RewardedAdVideoRibbon locale={locale} onWatchAd={() => void watchRewardedAd()} loading={unlocking} />
      ) : null}

      <div className={locked ? "opacity-80" : undefined}>
        <p className="text-sm font-semibold">{t.videoSectionTitle}</p>
        <p className="mt-1 text-xs text-[var(--muted)]">
          {locked ? t.videoLockedHint : t.videoUploadHint}
        </p>
      </div>

      {locked ? (
        <div className="flex items-center gap-2 rounded-xl border border-[var(--border)] bg-white/70 px-3 py-2.5 text-sm text-[var(--muted)]">
          <span aria-hidden="true">🔒</span>
          <span>{adPlaying ? t.rewardedAdPlaying : t.videoLockedHint}</span>
        </div>
      ) : (
        <input
          ref={inputRef}
          type="file"
          accept="video/mp4,video/quicktime,.mp4,.mov"
          className="block w-full text-sm"
          disabled={uploading}
          onChange={(event) => {
            const file = event.target.files?.[0];
            if (file) void uploadVideo(file);
          }}
        />
      )}

      {!locked && uploading ? <p className="text-sm text-[var(--muted)]">{t.uploadingVideo}</p> : null}

      {hasExistingVideo ? (
        <div className="space-y-2">
          {locked ? (
            <p className="text-xs text-[var(--muted)]">{t.videoLockedHint}</p>
          ) : (
            <p className="text-xs font-medium uppercase tracking-wide text-[var(--muted)]">
              {t.videoPreview}
            </p>
          )}
          <ListingVideo src={displayVideoUrl} title={t.listingVideo} />
          {!locked ? (
            <button
              type="button"
              className="text-sm font-medium text-[var(--primary)]"
              onClick={() => onChange("")}
            >
              {t.removeVideo}
            </button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
