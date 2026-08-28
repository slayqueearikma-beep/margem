"use client";

import { useRef, useState } from "react";
import { ListingVideo } from "@/components/listing-video";
import { DriverProVideoBanner } from "@/components/seller/driver-pro-video-banner";
import type { AppLocale } from "@/lib/i18n/video-messages";
import { videoMessages } from "@/lib/i18n/video-messages";

const MAX_VIDEO_BYTES = 50 * 1024 * 1024;

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
  initialVideoUrl?: string;
  value: string;
  onChange: (url: string) => void;
  onError: (message: string) => void;
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
  initialVideoUrl = "",
  value,
  onChange,
  onError,
}: ListingVideoFieldProps) {
  const t = videoMessages(locale);
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const hasExistingVideo = Boolean((initialVideoUrl || value).trim());

  if (!videoUploadsEnabled) {
    return (
      <div className="space-y-4">
        <DriverProVideoBanner locale={locale} />
        {hasExistingVideo ? (
          <div className="space-y-2">
            <p className="text-sm text-[var(--muted)]">{t.replaceVideoRequiresDriverPro}</p>
            <ListingVideo src={value || initialVideoUrl} title={t.listingVideo} />
          </div>
        ) : null}
      </div>
    );
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
    <div className="space-y-3 rounded-2xl border border-[var(--border)] bg-white p-4">
      <div>
        <p className="text-sm font-semibold">{t.videoUploadLabel}</p>
        <p className="mt-1 text-xs text-[var(--muted)]">{t.videoUploadHint}</p>
      </div>

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

      {uploading ? <p className="text-sm text-[var(--muted)]">Uploading video…</p> : null}

      {value ? (
        <div className="space-y-2">
          <p className="text-xs font-medium uppercase tracking-wide text-[var(--muted)]">
            {t.videoPreview}
          </p>
          <ListingVideo src={value} title={t.listingVideo} />
          <button
            type="button"
            className="text-sm font-medium text-[var(--primary)]"
            onClick={() => onChange("")}
          >
            {t.removeVideo}
          </button>
        </div>
      ) : null}
    </div>
  );
}
