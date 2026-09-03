#!/usr/bin/env node
/**
 * Validates production web build configuration before `next build`.
 * Fails fast when localhost/dev API URLs would be baked into a release image.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");

const PRODUCTION_API_URL = "https://api.dribex.ma";
const PRODUCTION_SITE_URL = "https://dribex.ma";
const DEV_HOST = /(^|\/\/)(localhost|127\.0\.0\.1|10\.0\.2\.2|::1)(:|\/|$)/i;

function fail(message) {
  console.error(`[validate-production-config] ${message}`);
  process.exit(1);
}

const publicApi = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL?.trim();

if (!publicApi) {
  fail("NEXT_PUBLIC_API_BASE_URL is required for production Docker builds.");
}
if (!siteUrl) {
  fail("NEXT_PUBLIC_SITE_URL is required for production Docker builds.");
}
if (!publicApi.startsWith("https://")) {
  fail(`NEXT_PUBLIC_API_BASE_URL must use HTTPS. Got: ${publicApi}`);
}
if (DEV_HOST.test(publicApi)) {
  fail(`NEXT_PUBLIC_API_BASE_URL must not use development hosts. Got: ${publicApi}`);
}
if (publicApi !== PRODUCTION_API_URL) {
  fail(
    `NEXT_PUBLIC_API_BASE_URL must be ${PRODUCTION_API_URL}. Got: ${publicApi}`,
  );
}
if (!siteUrl.startsWith("https://")) {
  fail(`NEXT_PUBLIC_SITE_URL must use HTTPS. Got: ${siteUrl}`);
}
if (DEV_HOST.test(siteUrl)) {
  fail(`NEXT_PUBLIC_SITE_URL must not use development hosts. Got: ${siteUrl}`);
}

const dockerfile = readFileSync(join(root, "Dockerfile"), "utf8");
if (/ARG NEXT_PUBLIC_API_BASE_URL=http:\/\/localhost:8000/.test(dockerfile)) {
  fail("web/Dockerfile must not default NEXT_PUBLIC_API_BASE_URL to localhost.");
}

const configSource = readFileSync(join(root, "src/lib/config.ts"), "utf8");
assert.match(configSource, /\/api-proxy/, "config.ts must preserve /api-proxy architecture.");

console.log("[validate-production-config] production web configuration OK");
