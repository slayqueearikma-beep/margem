"use client";

import { useTranslations } from "next-intl";
import { ErrorState } from "@/components/states";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const t = useTranslations("common");

  console.error(error);

  return (
    <div className="space-y-4">
      <ErrorState
        title={t("unexpectedError")}
        description={t("renderError")}
      />
      <div className="text-center">
        <button
          type="button"
          onClick={() => reset()}
          className="rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white"
        >
          {t("tryAgain")}
        </button>
      </div>
    </div>
  );
}
