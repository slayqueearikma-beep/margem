"use client";

import { useEffect } from "react";
import { ErrorState } from "@/components/states";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <html lang="en">
      <body>
        <div className="mx-auto max-w-7xl px-4 py-16">
          <ErrorState
            title="Unexpected error"
            description="The storefront hit a problem while rendering this page."
            retryHref="#"
          />
          <div className="mt-4 text-center">
            <button
              type="button"
              onClick={() => reset()}
              className="rounded-full bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-white"
            >
              Try again
            </button>
          </div>
        </div>
      </body>
    </html>
  );
}
