import { ListingEditorForm } from "@/components/seller/listing-editor-form";
import { requireSellerSession } from "@/lib/seller-session";

export default async function NewProductPage() {
  const session = await requireSellerSession();

  return <ListingEditorForm kind="product" sellerId={session.profile.id} />;
}
