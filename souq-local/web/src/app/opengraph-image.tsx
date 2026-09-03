import { ImageResponse } from "next/og";
import { BRAND } from "@/lib/config";

export const runtime = "edge";
export const alt = "Dribex marketplace";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: 80,
          background: "linear-gradient(135deg, #F8F1E9 0%, #EFF6FF 100%)",
        }}
      >
        <div style={{ fontSize: 28, color: "#2563EB", fontWeight: 700 }}>{BRAND.name}</div>
        <div style={{ fontSize: 64, fontWeight: 800, marginTop: 16, color: "#111827" }}>
          Discover local marketplace listings
        </div>
        <div style={{ fontSize: 28, marginTop: 24, color: "#6B7280" }}>{BRAND.tagline}</div>
      </div>
    ),
    size,
  );
}
