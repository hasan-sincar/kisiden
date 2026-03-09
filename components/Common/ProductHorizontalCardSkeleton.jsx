import { Skeleton } from "../ui/skeleton";

const ProductHorizontalCardSkeleton = () => {
    return (
        <div className="border p-2 rounded-md flex gap-2 sm:gap-4 w-full relative">
            {/* Product image skeleton */}
            <Skeleton className="w-[100px] sm:w-[219px] h-auto aspect-square sm:aspect-[219/190] rounded" />

            {/* Like button skeleton */}
            <Skeleton className="absolute h-8 w-8 ltr:right-2 rtl:left-2 top-2 rounded-full" />

            <div className="flex flex-col gap-1 sm:gap-2 flex-1">
                {/* Featured badge skeleton */}
                <Skeleton className="h-6 w-24 rounded-md mb-1" />

                {/* Price skeleton */}
                <Skeleton className="h-5 sm:h-6 w-24 rounded" />

                {/* Name skeleton */}
                <Skeleton className="h-4 sm:h-5 w-3/4 rounded" />

                {/* Location skeleton */}
                <Skeleton className="h-3 sm:h-4 w-1/2 rounded" />

                {/* Date skeleton */}
                <div className="flex justify-end mt-auto">
                    <Skeleton className="h-3 sm:h-4 w-24 rounded" />
                </div>
            </div>
        </div>
    );
};

export default ProductHorizontalCardSkeleton; 