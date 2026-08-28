import { cookies } from "next/headers";
import { ListingEditorForm } from "@/components/seller/listing-editor-form";
import { resolveLocale } from "@/lib/i18n/video-messages";
import { requireSellerSession } from "@/lib/seller-session";

export default async function NewProductPage() {
  const session = await requireSellerSession();
  const locale = resolveLocale((await cookies()).get("dribex_lang")?.value);

  return (
    <ListingEditorForm locale={locale} kind="product" sellerId={session.profile.id} />
  );
}
