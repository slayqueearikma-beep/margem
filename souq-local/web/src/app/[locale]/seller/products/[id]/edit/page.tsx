import { notFound } from "next/navigation";
import { ListingEditorForm } from "@/components/seller/listing-editor-form";
import { requireSellerSession } from "@/lib/seller-session";

type EditProductPageProps = {
  params: Promise<{ id: string }>;
};

export default async function EditProductPage({ params }: EditProductPageProps) {
  const { id } = await params;
  const session = await requireSellerSession();
  const product = session.profile.products.find((item) => item.id === id);
  if (!product) notFound();

  return (
    <ListingEditorForm
      kind="product"
      sellerId={session.profile.id}
      listingId={id}
      initial={{
        name: product.name,
        description: product.description || "",
        priceMad: product.price_mad != null ? String(product.price_mad) : "",
        imageUrl: product.image_url || "",
        isAvailable: product.is_available,
      }}
    />
  );
}
