import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { SellerLoginForm } from "@/components/seller/seller-login-form";

export default async function SellerLoginPage() {
  const t = await getTranslations("sellerPortal");
  const tCommon = await getTranslations("common");

  return (
    <div className="space-y-6">
      <SellerLoginForm />
      <p className="text-center text-sm text-[var(--muted)]">
        {t("needMobileApp")}{" "}
        <Link href="/" className="font-medium text-[var(--primary)]">
          {tCommon("returnToDiscovery")}
        </Link>
      </p>
    </div>
  );
}
