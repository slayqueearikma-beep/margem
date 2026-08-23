"""Canonical MarGem business category taxonomy (54 categories).

Each tuple: slug, name_en, name_fr, name_ar, icon, accent_color, sort_order
"""

from __future__ import annotations

from typing import NamedTuple


class BusinessCategory(NamedTuple):
    slug: str
    name_en: str
    name_fr: str
    name_ar: str
    icon: str
    accent_color: str
    sort_order: int


BUSINESS_CATEGORIES: tuple[BusinessCategory, ...] = (
    BusinessCategory("doctors", "Doctors", "Médecins", "أطباء", "medical_services", "#E53935", 1),
    BusinessCategory("dentists", "Dentists", "Dentistes", "أطباء أسنان", "medical_information", "#D81B60", 2),
    BusinessCategory("pharmacies", "Pharmacies", "Pharmacies", "صيدليات", "local_pharmacy", "#E91E63", 3),
    BusinessCategory("veterinarians", "Veterinarians", "Vétérinaires", "أطباء بيطريون", "pets", "#8E24AA", 4),
    BusinessCategory("restaurants", "Restaurants", "Restaurants", "مطاعم", "restaurant", "#F4511E", 5),
    BusinessCategory("cafes", "Cafés", "Cafés", "مقاهي", "local_cafe", "#FF6F00", 6),
    BusinessCategory("hotels", "Hotels", "Hôtels", "فنادق", "hotel", "#6D4C41", 7),
    BusinessCategory("beauty-salons", "Beauty Salons", "Salons de beauté", "صالونات تجميل", "spa", "#EC407A", 8),
    BusinessCategory("barbers", "Barbers", "Barbiers", "حلاقون", "content_cut", "#AB47BC", 9),
    BusinessCategory("gyms", "Gyms", "Salles de sport", "صالات رياضية", "fitness_center", "#5C6BC0", 10),
    BusinessCategory("auto-repair", "Auto Repair Garages", "Garages auto", "ورش إصلاح السيارات", "car_repair", "#546E7A", 11),
    BusinessCategory("car-dealerships", "Car Dealerships", "Concessionnaires auto", "وكلاء سيارات", "directions_car", "#37474F", 12),
    BusinessCategory("motorcycle-dealerships", "Motorcycle Dealerships", "Concessionnaires moto", "وكلاء دراجات نارية", "two_wheeler", "#455A64", 13),
    BusinessCategory("motorcycle-repair", "Motorcycle Repair Shops", "Réparation moto", "ورش إصلاح الدراجات", "motorcycle", "#607D8B", 14),
    BusinessCategory("car-rental", "Car Rental Agencies", "Location de voitures", "تأجير سيارات", "car_rental", "#78909C", 15),
    BusinessCategory("motorcycle-rental", "Motorcycle Rental Agencies", "Location de motos", "تأجير دراجات نارية", "moped", "#90A4AE", 16),
    BusinessCategory("tire-shops", "Tire Shops", "Pneumatiques", "محلات إطارات", "tire_repair", "#263238", 17),
    BusinessCategory("car-washes", "Car Washes", "Lavage auto", "مغاسل سيارات", "local_car_wash", "#0288D1", 18),
    BusinessCategory("auto-parts", "Auto Parts Stores", "Pièces auto", "قطع غيار السيارات", "build_circle", "#0277BD", 19),
    BusinessCategory("real-estate", "Real Estate Agencies", "Agences immobilières", "وكالات عقارية", "real_estate_agent", "#2E7D32", 20),
    BusinessCategory("travel-agencies", "Travel Agencies", "Agences de voyage", "وكالات سفر", "flight", "#00897B", 21),
    BusinessCategory("insurance-agencies", "Insurance Agencies", "Assurances", "وكالات تأمين", "policy", "#00796B", 22),
    BusinessCategory("banks", "Banks", "Banques", "بنوك", "account_balance", "#1565C0", 23),
    BusinessCategory("lawyers", "Lawyers", "Avocats", "محامون", "gavel", "#3949AB", 24),
    BusinessCategory("notaries", "Notaries", "Notaires", "موثقون", "approval", "#283593", 25),
    BusinessCategory("accountants", "Accountants", "Comptables", "محاسبون", "calculate", "#1E88E5", 26),
    BusinessCategory("driving-schools", "Driving Schools", "Auto-écoles", "مدارس تعليم السياقة", "school", "#FFA000", 27),
    BusinessCategory("cleaning-companies", "Cleaning Companies", "Entreprises de nettoyage", "شركات تنظيف", "cleaning_services", "#00ACC1", 28),
    BusinessCategory("moving-companies", "Moving Companies", "Déménagement", "شركات نقل", "local_shipping", "#00838F", 29),
    BusinessCategory("plumbers", "Plumbers", "Plombiers", "سباكون", "plumbing", "#039BE5", 30),
    BusinessCategory("electricians", "Electricians", "Électriciens", "كهربائيون", "electrical_services", "#F9A825", 31),
    BusinessCategory("painters", "Painters", "Peintres", "دهانون", "format_paint", "#9E9D24", 32),
    BusinessCategory("carpenters", "Carpenters", "Menuisiers", "نجارون", "carpenter", "#8D6E63", 33),
    BusinessCategory("locksmiths", "Locksmiths", "Serruriers", "قفالون", "lock", "#795548", 34),
    BusinessCategory("air-conditioning", "Air Conditioning Services", "Climatisation", "تكييف", "ac_unit", "#00BCD4", 35),
    BusinessCategory("security-companies", "Security Companies", "Sécurité", "شركات أمن", "security", "#424242", 36),
    BusinessCategory("pest-control", "Pest Control Companies", "Désinsectisation", "مكافحة الآفات", "pest_control", "#689F38", 37),
    BusinessCategory("marketing-agencies", "Marketing Agencies", "Agences marketing", "وكالات تسويق", "campaign", "#E65100", 38),
    BusinessCategory("digital-agencies", "Digital Agencies", "Agences digitales", "وكالات رقمية", "devices", "#FF5722", 39),
    BusinessCategory("web-development", "Web Development Agencies", "Développement web", "تطوير مواقع", "web", "#3F51B5", 40),
    BusinessCategory("software-companies", "Software Companies", "Éditeurs logiciels", "شركات برمجيات", "computer", "#673AB7", 41),
    BusinessCategory("architecture-firms", "Architecture Firms", "Architectes", "مكاتب هندسة معمارية", "architecture", "#5E35B1", 42),
    BusinessCategory("engineering-firms", "Engineering Firms", "Bureaux d'études", "مكاتب هندسية", "engineering", "#512DA8", 43),
    BusinessCategory("recruitment-agencies", "Recruitment Agencies", "Recrutement", "وكالات توظيف", "work", "#303F9F", 44),
    BusinessCategory("event-agencies", "Event Agencies", "Événementiel", "وكالات فعاليات", "event", "#C2185B", 45),
    BusinessCategory("furniture-stores", "Furniture Stores", "Meubles", "محلات أثاث", "chair", "#6D4C41", 46),
    BusinessCategory("electronics-stores", "Electronics Stores", "Électronique", "محلات إلكترونيات", "devices_other", "#1976D2", 47),
    BusinessCategory("clothing-stores", "Clothing Stores", "Vêtements", "محلات ملابس", "checkroom", "#7B1FA2", 48),
    BusinessCategory("jewelry-stores", "Jewelry Stores", "Bijouteries", "محلات مجوهرات", "diamond", "#AD1457", 49),
    BusinessCategory("bookstores", "Bookstores", "Librairies", "مكتبات", "menu_book", "#5D4037", 50),
    BusinessCategory("pet-stores", "Pet Stores", "Animaleries", "محلات حيوانات", "pet_supplies", "#43A047", 51),
    BusinessCategory("flower-shops", "Flower Shops", "Fleuristes", "محلات زهور", "local_florist", "#E91E63", 52),
    BusinessCategory("bakeries", "Bakeries", "Boulangeries", "مخابز", "bakery_dining", "#FFB300", 53),
    BusinessCategory("supermarkets", "Supermarkets", "Supermarchés", "سوبرماركت", "shopping_cart", "#388E3C", 54),
)

LEGACY_CATEGORY_SLUGS: tuple[str, ...] = (
    "food",
    "clothing",
    "electronics",
    "beauty",
    "services",
    "home",
    "health",
    "sports",
)
