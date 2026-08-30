"use client";

import { useState } from "react";

type MediaImageProps = {
  src: string;
  alt: string;
  className?: string;
  loading?: "lazy" | "eager";
};

export function MediaImage({ src, alt, className, loading = "lazy" }: MediaImageProps) {
  const [failed, setFailed] = useState(false);
  const resolved = src.trim();

  if (!resolved || failed) {
    return (
      <div
        className={`flex items-center justify-center bg-[var(--cream)] text-xs font-medium text-[var(--muted)] ${className || ""}`}
        aria-hidden={!alt}
      >
        No image
      </div>
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={resolved}
      alt={alt}
      className={className}
      loading={loading}
      onError={() => setFailed(true)}
    />
  );
}
