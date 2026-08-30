"""Fundamental marketplace categories for Casablanca listings."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class MarketplaceCategorySeed:
    slug: str
    name_en: str
    name_fr: str
    name_ar: str
    icon: str


# Product/service verticals only — listing type (product vs service) is separate.
MARKETPLACE_CATEGORIES: tuple[MarketplaceCategorySeed, ...] = (
    MarketplaceCategorySeed("clothing", "Clothes", "Vêtements", "ملابس", "checkroom"),
    MarketplaceCategorySeed("shoes", "Shoes", "Chaussures", "أحذية", "steps"),
    MarketplaceCategorySeed("perfumes", "Perfumes", "Parfums", "عطور", "fragrance"),
    MarketplaceCategorySeed("beauty", "Beauty", "Beauté", "جمال", "spa"),
    MarketplaceCategorySeed("electronics", "Electronics", "Électronique", "إلكترونيات", "devices"),
    MarketplaceCategorySeed("food", "Food", "Nourriture", "طعام", "restaurant"),
    MarketplaceCategorySeed("home", "Home", "Maison", "منزل", "home"),
    MarketplaceCategorySeed("jewelry", "Jewelry", "Bijoux", "مجوهرات", "diamond"),
    MarketplaceCategorySeed("accessories", "Accessories", "Accessoires", "إكسسوارات", "watch"),
    MarketplaceCategorySeed("sports", "Sports", "Sport", "رياضة", "sports_soccer"),
    MarketplaceCategorySeed("health", "Health", "Santé", "صحة", "local_hospital"),
    MarketplaceCategorySeed("kids", "Kids", "Enfants", "أطفال", "child_care"),
)

# Map deprecated category slugs to the closest fundamental category.
LEGACY_CATEGORY_SLUG_MAP: dict[str, str] = {
    "services": "home",
    "home-garden": "home",
}

# Marketplace-specific category slugs (per-venue trees) → fundamental listing slugs.
MARKETPLACE_CATEGORY_TO_FUNDAMENTAL: dict[str, str] = {
    # Derb Ghallef
    "phones": "electronics",
    "gaming": "electronics",
    "computers": "electronics",
    "networking": "electronics",
    "repairs": "electronics",
    # Derb Omar
    "construction": "home",
    "hardware": "home",
    "plumbing": "home",
    "electrical": "electronics",
    # Al Qurayaa (9ri3a)
    "toyota-parts": "accessories",
    "bmw-parts": "accessories",
    "mercedes-parts": "accessories",
    "tires": "accessories",
    "mechanics": "accessories",
    # Habous
    "traditional-clothing": "clothing",
    "leather": "accessories",
    "handicrafts": "accessories",
    "spices": "food",
    "gifts": "accessories",
    "home-decor": "home",
    # Medina / Bab Marrakech
    "textiles": "clothing",
    "household": "home",
}

MARKETPLACE_CATEGORY_SLUGS: frozenset[str] = frozenset(c.slug for c in MARKETPLACE_CATEGORIES)
