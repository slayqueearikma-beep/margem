import { ListingEditorForm } from "@/components/seller/listing-editor-form";
import { requireSellerSession } from "@/lib/seller-session";

export default async function NewServicePage() {
  const session = await requireSellerSession();

  return <ListingEditorForm kind="service" sellerId={session.profile.id} />;
}
