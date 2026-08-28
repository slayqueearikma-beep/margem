import Link from "next/link";

export default function SellerPremiumPage() {
  return (
    <div className="mx-auto max-w-xl space-y-4 rounded-3xl border border-[var(--border)] bg-white p-6">
      <h1 className="text-2xl font-bold">DriverPro</h1>
      <p className="text-[var(--muted)]">
        DriverPro unlocks video uploads, up to 20 combined listings, featured placement, and an ad-free seller experience for 149 DH.
      </p>
      <p className="text-sm text-[var(--muted)]">
        Subscription checkout is handled in the Dribex mobile app today. Sign in on mobile, open Premium, and choose DriverPro to activate video uploads.
      </p>
      <Link href="/seller" className="inline-flex text-sm font-semibold text-[var(--primary)]">
        Back to seller hub
      </Link>
    </div>
  );
}
