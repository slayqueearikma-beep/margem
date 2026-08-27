import Link from "next/link";

export function EmptyState({
  title,
  description,
  actionHref,
  actionLabel,
}: {
  title: string;
  description: string;
  actionHref?: string;
  actionLabel?: string;
}) {
  return (
    <div className="rounded-2xl border border-dashed border-[var(--border)] bg-white px-6 py-16 text-center">
      <h2 className="text-lg font-semibold">{title}</h2>
      <p className="mx-auto mt-2 max-w-md text-sm text-[var(--muted)]">{description}</p>
      {actionHref && actionLabel ? (
        <Link
          href={actionHref}
          className="mt-6 inline-flex rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white"
        >
          {actionLabel}
        </Link>
      ) : null}
    </div>
  );
}

export function ErrorState({
  title = "Something went wrong",
  description = "We could not load this page. Please try again in a moment.",
  retryHref,
}: {
  title?: string;
  description?: string;
  retryHref?: string;
}) {
  return (
    <EmptyState
      title={title}
      description={description}
      actionHref={retryHref}
      actionLabel={retryHref ? "Try again" : undefined}
    />
  );
}

export function LoadingGrid({ count = 8 }: { count?: number }) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {Array.from({ length: count }).map((_, index) => (
        <div
          key={index}
          className="animate-pulse overflow-hidden rounded-2xl border border-[var(--border)] bg-white"
        >
          <div className="aspect-[4/3] bg-gray-200" />
          <div className="space-y-3 p-4">
            <div className="h-4 rounded bg-gray-200" />
            <div className="h-3 w-2/3 rounded bg-gray-100" />
          </div>
        </div>
      ))}
    </div>
  );
}
