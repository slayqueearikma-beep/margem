import Link from "next/link";
import { SellerLoginForm } from "@/components/seller/seller-login-form";

export default function SellerLoginPage() {
  return (
    <div className="space-y-6">
      <SellerLoginForm />
      <p className="text-center text-sm text-[var(--muted)]">
        Need the mobile app instead?{" "}
        <Link href="/" className="font-medium text-[var(--primary)]">
          Return to discovery
        </Link>
      </p>
    </div>
  );
}
