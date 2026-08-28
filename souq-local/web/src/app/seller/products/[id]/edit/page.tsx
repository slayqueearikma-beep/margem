import { cookies } from "next/headers";
import { notFound } from "next/navigation";
import { ListingEditorForm } from "@/components/seller/listing-editor-form";
import { resolveLocale } from "@/lib/i18n/video-messages";
import { requireSellerSession } from "@/lib/seller-session";

type EditProductPageProps = {
  params: Promise<{ id: string }>;
};

export default async function EditProductPage({ params }: EditProductPageProps) {
  const { id } = await params;
  const session = await requireSellerSession();
  const product = session.profile.products.find((item) => item.id === id);
  if (!product) notFound();

  const locale = resolveLocale((await cookies()).get("dribex_lang")?.value);

  return (
    <ListingEditorForm
      locale={locale}
      kind="product"
      sellerId={session.profile.id}
      listingId={id}
      initial={{
        name: product.name,
        description: product.description || "",
        priceMad: product.price_mad != null ? String(product.price_mad) : "",
        imageUrl: product.image_url || "",
        videoUrl: product.video_url || "",
        isAvailable: product.is_available,
      }}
    />
  );
}
