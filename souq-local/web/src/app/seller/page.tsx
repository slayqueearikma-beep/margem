import Link from "next/link";
import { redirect } from "next/navigation";
import { SellerSignOutButton } from "@/components/seller/seller-sign-out-button";
import { getSellerSession } from "@/lib/seller-session";

export default async function SellerHubPage() {
  const session = await getSellerSession();
  if (!session) redirect("/seller/login");

  const { profile } = session;

  return (
    <div className="space-y-8">
      <div>
        <p className="text-sm font-semibold uppercase tracking-wide text-[var(--primary)]">Seller hub</p>
        <h1 className="mt-2 text-3xl font-bold">{profile.business_name}</h1>
        <p className="mt-2 text-sm text-[var(--muted)]">
          Manage listings and optional DriverPro videos from the web.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Link
          href="/seller/products/new"
          className="rounded-2xl border border-[var(--border)] bg-white p-5 font-semibold text-[var(--primary)]"
        >
          Add product
        </Link>
        <Link
          href="/seller/services/new"
          className="rounded-2xl border border-[var(--border)] bg-white p-5 font-semibold text-[var(--primary)]"
        >
          Add service
        </Link>
      </div>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Your products</h2>
        {profile.products.length > 0 ? (
          <ul className="space-y-2">
            {profile.products.map((product) => (
              <li key={product.id} className="flex items-center justify-between rounded-xl border border-[var(--border)] bg-white px-4 py-3">
                <span>{product.name}</span>
                <Link href={`/seller/products/${product.id}/edit`} className="text-sm font-medium text-[var(--primary)]">
                  Edit
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-[var(--muted)]">No products yet.</p>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Your services</h2>
        {profile.services.length > 0 ? (
          <ul className="space-y-2">
            {profile.services.map((service) => (
              <li key={service.id} className="flex items-center justify-between rounded-xl border border-[var(--border)] bg-white px-4 py-3">
                <span>{service.name}</span>
                <Link href={`/seller/services/${service.id}/edit`} className="text-sm font-medium text-[var(--primary)]">
                  Edit
                </Link>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-[var(--muted)]">No services yet.</p>
        )}
      </section>

      <SellerSignOutButton />
    </div>
  );
}
