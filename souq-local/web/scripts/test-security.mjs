#!/usr/bin/env node
import assert from "node:assert/strict";
import test from "node:test";
import {
  isAllowedPublicProxyPath,
  isAllowedPublicProxyPostPath,
  isAllowedSellerProxyPath,
  normalizeProxyPath,
  safeExternalHref,
  safeJsonLd,
} from "../src/lib/security-core.js";

test("normalizeProxyPath rejects traversal", () => {
  assert.equal(normalizeProxyPath(["..", "auth", "me"]), null);
  assert.equal(normalizeProxyPath(["media", "..", "etc", "passwd"]), null);
  assert.equal(normalizeProxyPath(["categories"]), "categories");
});

test("proxy allowlist permits storefront reads only", () => {
  assert.equal(isAllowedPublicProxyPath("categories"), true);
  assert.equal(isAllowedPublicProxyPath("search"), true);
  assert.equal(isAllowedPublicProxyPath("ads/active"), true);
  assert.equal(isAllowedPublicProxyPath("ads/impressions"), true);
  assert.equal(
    isAllowedPublicProxyPath("ads/click/550e8400-e29b-41d4-a716-446655440000"),
    true,
  );
  assert.equal(
    isAllowedPublicProxyPath("products/550e8400-e29b-41d4-a716-446655440000"),
    true,
  );
  assert.equal(isAllowedPublicProxyPath("media/local/item.jpg"), true);
  assert.equal(isAllowedPublicProxyPath("brand/margem_logo.png"), true);
  assert.equal(isAllowedPublicProxyPath("legal/en/privacy"), true);
  assert.equal(isAllowedPublicProxyPath("privacy"), true);
  assert.equal(isAllowedPublicProxyPath("terms"), true);
});

test("proxy allowlist blocks sensitive API namespaces", () => {
  assert.equal(isAllowedPublicProxyPath("auth/me"), false);
  assert.equal(isAllowedPublicProxyPath("admin/users"), false);
  assert.equal(isAllowedPublicProxyPath("uploads/presign"), false);
  assert.equal(isAllowedPublicProxyPath("health"), false);
  assert.equal(isAllowedPublicProxyPath("openapi.json"), false);
  assert.equal(isAllowedPublicProxyPath("metrics"), false);
  assert.equal(isAllowedPublicProxyPath("privacy/consents"), false);
  assert.equal(isAllowedPublicProxyPath("sellers/me"), false);
});

test("proxy POST allowlist permits advertisement impressions only", () => {
  assert.equal(isAllowedPublicProxyPostPath("ads/impressions"), true);
  assert.equal(isAllowedPublicProxyPostPath("ads/active"), false);
  assert.equal(isAllowedPublicProxyPostPath("admin/advertisements"), false);
  assert.equal(isAllowedPublicProxyPostPath("uploads/presign"), false);
});

test("safeExternalHref blocks dangerous schemes", () => {
  assert.equal(safeExternalHref("javascript:alert(1)"), null);
  assert.equal(safeExternalHref("data:text/html,hi"), null);
  assert.equal(safeExternalHref("example.com"), "https://example.com/");
  assert.equal(safeExternalHref("https://shop.example.com/path"), "https://shop.example.com/path");
});

test("safeJsonLd escapes script breakouts", () => {
  const payload = safeJsonLd({ name: "</script><script>alert(1)</script>" });
  assert.equal(payload.includes("</script>"), false);
  assert.equal(payload.includes("\\u003c/script\\u003e"), true);
});

test("seller proxy rejects traversal and sensitive namespaces", () => {
  assert.equal(normalizeProxyPath(["sellers", "..", "auth", "me"]), null);
  assert.equal(normalizeProxyPath(["uploads", "..", "auth", "refresh"]), null);
  assert.equal(isAllowedSellerProxyPath("admin/users"), false);
  assert.equal(isAllowedSellerProxyPath("auth/refresh"), false);
  assert.equal(isAllowedSellerProxyPath("sellers/me"), true);
  assert.equal(isAllowedSellerProxyPath("uploads/presign"), true);
  assert.equal(isAllowedSellerProxyPath("subscriptions/entitlements"), true);
  assert.equal(isAllowedSellerProxyPath("billing/checkout/subscription/seller_pro"), true);
});
