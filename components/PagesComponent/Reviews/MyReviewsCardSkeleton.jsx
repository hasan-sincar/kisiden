import { Skeleton } from "@/components/ui/skeleton";

const ReviewCardItem = () => {
    return (
        <div className="bg-white p-4 rounded-lg flex flex-col gap-4">
            <div className="flex flex-col sm:flex-row flex-1 gap-4">
                {/* Profile image with smaller image overlay */}
                <div className="relative w-fit">
                    <Skeleton className="w-[72px] h-[72px] rounded-full" />
                    <Skeleton className="w-[36px] h-[36px] rounded-full absolute top-12 bottom-[-6px] right-[-6px]" />
                </div>

                <div className="flex-1">
                    {/* Reviewer name and report icon */}
                    <div className="flex flex-1 items-center justify-between">
                        <Skeleton className="h-5 w-32 rounded-md" />
                        <Skeleton className="h-5 w-5 rounded-md" />
                    </div>

                    {/* Item name */}
                    <Skeleton className="h-4 w-48 mt-1 rounded-md" />

                    {/* Star rating */}
                    <div className="mt-1 flex items-center gap-1">
                        <Skeleton className="h-6 w-32 rounded-md" />
                    </div>

                    {/* Date */}
                    <Skeleton className="h-4 w-24 mt-1 rounded-md" />
                </div>
            </div>

            {/* Divider */}
            <div className="border-b"></div>

            {/* Review text */}
            <div>
                <Skeleton className="h-4 w-full rounded-md mb-2" />
                <Skeleton className="h-4 w-full rounded-md" />

                {/* See More button (optional) */}
                <div className="flex justify-center mt-1">
                    <Skeleton className="h-4 w-16 rounded-md" />
                </div>
            </div>
        </div>
    );
};

const MyReviewsCardSkeleton = () => {
    return (
        <div className="mt-[30px] p-2 sm:p-4 bg-muted rounded-xl flex flex-col gap-[30px]">
            {Array(8).fill(0).map((_, index) => (
                <ReviewCardItem key={`review-skeleton-${index}`} />
            ))}
        </div>
    );
};

export default MyReviewsCardSkeleton; 