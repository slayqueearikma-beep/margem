/// Maps UI/marketplace category slugs to fundamental listing slugs used by /search.
String? resolveSearchCategorySlug(String? slug) {
  if (slug == null || slug.trim().isEmpty) return null;

  final cleaned = slug.trim().toLowerCase();
  const legacy = {
    'services': 'home',
    'home-garden': 'home',
  };
  const fundamental = {
    'clothing',
    'shoes',
    'perfumes',
    'beauty',
    'electronics',
    'food',
    'home',
    'jewelry',
    'accessories',
    'sports',
    'health',
    'kids',
  };
  const marketplaceToFundamental = {
    'phones': 'electronics',
    'gaming': 'electronics',
    'computers': 'electronics',
    'networking': 'electronics',
    'repairs': 'electronics',
    'construction': 'home',
    'hardware': 'home',
    'plumbing': 'home',
    'electrical': 'electronics',
    'toyota-parts': 'accessories',
    'bmw-parts': 'accessories',
    'mercedes-parts': 'accessories',
    'tires': 'accessories',
    'mechanics': 'accessories',
    'traditional-clothing': 'clothing',
    'leather': 'accessories',
    'handicrafts': 'accessories',
    'spices': 'food',
    'gifts': 'accessories',
    'home-decor': 'home',
    'textiles': 'clothing',
    'household': 'home',
  };

  final normalized = legacy[cleaned] ?? cleaned;
  if (fundamental.contains(normalized)) return normalized;
  return marketplaceToFundamental[normalized] ?? normalized;
}
