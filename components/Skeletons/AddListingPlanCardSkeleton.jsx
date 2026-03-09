import { Skeleton } from "@/components/ui/skeleton";

const AddListingPlanCardSkeleton = () => {
  return (
    <>
      <Skeleton className="w-1/5 h-4 mt-8 mb-4" />
      <div className="flex gap-4 overflow-x-auto scrollbar-none">
        {Array.from({ length: 4 }).map((_, index) => (
          <div
            key={index}
            className="rounded-lg p-8 shadow-sm border bg-white basis-[100%] sm:basis-3/4 md:basis-1/2 lg:basis-[66.66%] xl:basis-[45%] flex-shrink-0 first:pl-4"
          >
            {/* Card Header */}
            <div className="flex items-center gap-4">
              <div className="p-1 md:p-4 rounded-lg">
                <Skeleton className="w-20 h-20 md:w-24 md:h-24 rounded-full" />
              </div>
              <div className="flex flex-col gap-2 overflow-hidden flex-1">
                <Skeleton className="h-6 w-3/4 mb-1 rounded" /> {/* Title */}
                <div className="flex items-center gap-2">
                  <Skeleton className="h-6 w-16 rounded" /> {/* Price */}
                  <Skeleton className="h-6 w-10 rounded" />{" "}
                  {/* Strikethrough price */}
                </div>
              </div>
            </div>
            {/* Divider */}
            <div className="my-6">
              <Skeleton className="h-[2px] w-full" />
            </div>
            {/* Feature List Skeleton */}
            <div className="space-y-2 mb-2 h-[250px] max-h-[250px] overflow-y-auto p-4 md:p-0 flex flex-col">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="flex items-center gap-3">
                  <Skeleton className="h-5 w-5 rounded-full" />
                  <Skeleton className="h-4 w-3/4 rounded" />
                </div>
              ))}
            </div>
            {/* Button Skeleton */}
            <div className="flex items-center justify-center h-12 max-h-12 p-4 md:p-0">
              <Skeleton className="h-10 w-full rounded-lg" />
            </div>
          </div>
        ))}
      </div>
    </>
  );
};
export default AddListingPlanCardSkeleton;
