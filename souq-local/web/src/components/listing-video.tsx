import { resolveMediaUrl } from "@/lib/media";

type ListingVideoProps = {
  src: string;
  title: string;
  className?: string;
};

export function ListingVideo({ src, title, className = "" }: ListingVideoProps) {
  const resolved = resolveMediaUrl(src);
  if (!resolved) return null;

  return (
    <div className={`overflow-hidden rounded-2xl border border-[var(--border)] bg-black ${className}`}>
      <video
        className="aspect-video w-full bg-black object-contain"
        controls
        playsInline
        preload="metadata"
        title={title}
      >
        <source src={resolved} type="video/mp4" />
        Your browser does not support embedded video playback.
      </video>
    </div>
  );
}
