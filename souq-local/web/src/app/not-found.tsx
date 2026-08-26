import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto max-w-lg rounded-3xl border border-[var(--border)] bg-white px-6 py-16 text-center">
      <p className="text-sm font-semibold uppercase tracking-[0.2em] text-[var(--primary)]">
        404
      </p>
      <h1 className="mt-3 text-2xl font-bold">Page not found</h1>
      <p className="mt-3 text-sm text-[var(--muted)]">
        This listing or page is unavailable. It may have been removed or the URL may be incorrect.
      </p>
      <Link
        href="/"
        className="mt-6 inline-flex rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white"
      >
        Back to home
      </Link>
    </div>
  );
}
