import { Skeleton } from "@/components/ui/skeleton";

const RatingsSummarySkeleton = () => {
    return (
        <div className="grid grid-cols-1 md:grid-cols-12 p-4 rounded-xl border">
            {/* Average Rating Section Skeleton */}
            <div className="col-span-4 border-b md:border-b-0 ltr:md:border-r pb-4 md:pb-0 md:pr-4">
                <div className="flex flex-col items-center justify-center">
                    <Skeleton className="h-24 w-24 rounded-md mb-4" />
                    <Skeleton className="h-6 w-36 rounded-md mb-2" />
                    <Skeleton className="h-4 w-20 rounded-md" />
                </div>
            </div>

            {/* Rating Progress Bars Section Skeleton */}
            <div className="col-span-8 pt-4 md:pt-0 md:pl-8">
                <div className="flex flex-col gap-3">
                    {[1, 2, 3, 4, 5].map((index) => (
                        <div className="flex items-center gap-2" key={`skeleton-rating-${index}`}>
                            <Skeleton className="h-6 w-10 rounded-md" />
                            <Skeleton className="h-3 flex-1 rounded-md" />
                            <Skeleton className="h-4 w-6 rounded-md" />
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default RatingsSummarySkeleton; 