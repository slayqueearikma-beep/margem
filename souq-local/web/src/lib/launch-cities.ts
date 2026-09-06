export const ACTIVE_LAUNCH_CITY_SLUG = "casablanca";
export const ACTIVE_LAUNCH_CITY_NAME = "Casablanca";

type NamedCity = {
  slug: string;
  name_en: string;
};

export function isActiveLaunchCity(city: NamedCity): boolean {
  const slug = city.slug.trim().toLowerCase();
  const name = city.name_en.trim().toLowerCase();
  return slug === ACTIVE_LAUNCH_CITY_SLUG || name === ACTIVE_LAUNCH_CITY_SLUG;
}
