export function TrustBadges({
  verified,
  premium,
}: {
  verified?: boolean;
  premium?: boolean;
}) {
  if (!verified && !premium) return null;

  return (
    <div className="flex flex-wrap gap-1.5">
      {verified ? (
        <span className="rounded-full bg-green-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-green-700">
          Verified
        </span>
      ) : null}
      {premium ? (
        <span className="rounded-full bg-amber-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-amber-700">
          Premium
        </span>
      ) : null}
    </div>
  );
}
