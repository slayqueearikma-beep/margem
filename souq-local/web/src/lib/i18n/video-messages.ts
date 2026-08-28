export type AppLocale = "en" | "fr" | "ar";

export const VIDEO_MESSAGES: Record<
  AppLocale,
  {
    videoSectionTitle: string;
    videoLockedHint: string;
    driverProRibbonLabel: string;
    driverProRibbonPrice: string;
    driverProRibbonAria: string;
    upgradeAction: string;
    videoUploadHint: string;
    videoPreview: string;
    removeVideo: string;
    replaceVideoRequiresDriverPro: string;
    videoUploadFailed: string;
    videoTooLong: string;
    videoTooLarge: string;
    listingVideo: string;
    uploadingVideo: string;
  }
> = {
  en: {
    videoSectionTitle: "Video",
    videoLockedHint: "Available with DriverPro",
    driverProRibbonLabel: "DriverPro",
    driverProRibbonPrice: "149 DH",
    driverProRibbonAria: "DriverPro feature — 149 DH",
    upgradeAction: "Upgrade",
    videoUploadHint: "Add a video to your listing. MP4 or MOV, under 1 minute, max 50 MB.",
    videoPreview: "Video preview",
    removeVideo: "Remove video",
    replaceVideoRequiresDriverPro: "Uploading or replacing videos requires an active DriverPro subscription.",
    videoUploadFailed: "Video upload failed. Your other listing details were not lost — try again or continue without video.",
    videoTooLong: "Video must be less than 1 minute.",
    videoTooLarge: "Video must be 50 MB or smaller.",
    listingVideo: "Listing video",
    uploadingVideo: "Uploading video…",
  },
  fr: {
    videoSectionTitle: "Vidéo",
    videoLockedHint: "Disponible avec DriverPro",
    driverProRibbonLabel: "DriverPro",
    driverProRibbonPrice: "149 DH",
    driverProRibbonAria: "Fonctionnalité DriverPro — 149 DH",
    upgradeAction: "Mettre à niveau",
    videoUploadHint: "Ajoutez une vidéo à votre annonce. MP4 ou MOV, moins d'une minute, 50 Mo max.",
    videoPreview: "Aperçu vidéo",
    removeVideo: "Supprimer la vidéo",
    replaceVideoRequiresDriverPro:
      "L'ajout ou le remplacement d'une vidéo nécessite un abonnement DriverPro actif.",
    videoUploadFailed:
      "Échec du téléversement vidéo. Les autres informations de l'annonce sont conservées — réessayez ou continuez sans vidéo.",
    videoTooLong: "La vidéo doit durer moins d'une minute.",
    videoTooLarge: "La vidéo doit faire 50 Mo ou moins.",
    listingVideo: "Vidéo de l'annonce",
    uploadingVideo: "Téléversement en cours…",
  },
  ar: {
    videoSectionTitle: "فيديو",
    videoLockedHint: "متاح مع DriverPro",
    driverProRibbonLabel: "DriverPro",
    driverProRibbonPrice: "149 درهم",
    driverProRibbonAria: "ميزة DriverPro — 149 درهم",
    upgradeAction: "ترقية",
    videoUploadHint: "أضف فيديو إلى إعلانك. MP4 أو MOV، أقل من دقيقة، بحد أقصى 50 ميغابايت.",
    videoPreview: "معاينة الفيديو",
    removeVideo: "إزالة الفيديو",
    replaceVideoRequiresDriverPro: "رفع أو استبدال الفيديو يتطلب اشتراك DriverPro نشطًا.",
    videoUploadFailed:
      "فشل رفع الفيديو. تم الاحتفاظ ببيانات الإعلان الأخرى — أعد المحاولة أو تابع بدون فيديو.",
    videoTooLong: "يجب أن يكون الفيديو أقل من دقيقة.",
    videoTooLarge: "يجب ألا يتجاوز حجم الفيديو 50 ميغابايت.",
    listingVideo: "فيديو الإعلان",
    uploadingVideo: "جارٍ رفع الفيديو…",
  },
};

export function resolveLocale(value: string | null | undefined): AppLocale {
  if (value === "fr" || value === "ar") return value;
  return "en";
}

export function videoMessages(locale: AppLocale) {
  return VIDEO_MESSAGES[locale];
}
