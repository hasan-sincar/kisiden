import { Skeleton } from "@/components/ui/skeleton";

const OfferSliderSkeleton = () => {
  return (
    <section className="py-6 bg-muted">
      <div className="container overflow-hidden">
        <div className="grid grid-cols-1 md:grid-cols-[66.66%_66.66%] gap-4">
          {Array.from({ length: 2 }).map((_, index) => (
            <Skeleton
              className={`${
                index === 1 ? "hidden md:block" : ""
              } aspect-[983/493] w-full rounded-xl`}
              key={index}
              height={493}
            />
          ))}
        </div>
      </div>
    </section>
  );
};

export default OfferSliderSkeleton;
