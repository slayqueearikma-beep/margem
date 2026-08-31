import { getServerApiBaseUrl } from "./config";
import type { FetchOutcome } from "./marketplace-fetch";

type ErrorTranslator = (
  key: string,
  values?: Record<string, string | number>,
) => string;

export function describeFetchErrorMessage(
  outcome: FetchOutcome<unknown>,
  t: ErrorTranslator,
): string {
  if (outcome.ok) return "";
  if (outcome.kind === "network") {
    if (process.env.NODE_ENV === "production") {
      return t("errors.apiTemporarilyUnavailable");
    }
    return t("errors.apiUnreachableDev", { apiBase: getServerApiBaseUrl() });
  }
  return outcome.error.message || t("errors.apiReturnedError");
}

export function serviceUnavailableDescription(
  outcome: FetchOutcome<unknown>,
  t: ErrorTranslator,
): string {
  const detail = describeFetchErrorMessage(outcome, t);
  return t("errors.infrastructureNote", { detail });
}
