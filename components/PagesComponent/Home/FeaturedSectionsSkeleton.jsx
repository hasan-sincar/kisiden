import { Skeleton } from "../../ui/skeleton";
import ProductCardSkeleton from "../../Common/ProductCardSkeleton";

const FeaturedSectionsSkeleton = () => {
  return (
    <div className="container">
      <div className="space-between gap-2 mt-12">
        <Skeleton className="w-1/6 h-4" />
        <Skeleton className="w-1/12 h-4" />
      </div>
      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-6 mt-6">
        {Array.from({ length: 4 }).map((_, index) => (
          <ProductCardSkeleton key={index} />
        ))}
      </div>
    </div>
  );
};

export default FeaturedSectionsSkeleton;
