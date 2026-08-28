import { cookies } from "next/headers";
import { notFound } from "next/navigation";
import { ListingEditorForm } from "@/components/seller/listing-editor-form";
import { resolveLocale } from "@/lib/i18n/video-messages";
import { requireSellerSession } from "@/lib/seller-session";

type EditServicePageProps = {
  params: Promise<{ id: string }>;
};

export default async function EditServicePage({ params }: EditServicePageProps) {
  const { id } = await params;
  const session = await requireSellerSession();
  const service = session.profile.services.find((item) => item.id === id);
  if (!service) notFound();

  const locale = resolveLocale((await cookies()).get("dribex_lang")?.value);

  return (
    <ListingEditorForm
      locale={locale}
      kind="service"
      sellerId={session.profile.id}
      listingId={id}
      initial={{
        name: service.name,
        description: service.description || "",
        priceMad: service.price_mad != null ? String(service.price_mad) : "",
        imageUrl: service.image_url || "",
        videoUrl: service.video_url || "",
        isAvailable: service.is_available,
      }}
    />
  );
}
