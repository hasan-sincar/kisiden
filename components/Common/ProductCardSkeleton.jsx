import { Skeleton } from "../ui/skeleton";

const ProductCardSkeleton = () => {
  return (
    <div className="border p-2 rounded-2xl flex flex-col gap-2">
      <Skeleton className="w-full aspect-square" />
      <div className="space-between">
        <Skeleton className="w-1/4 h-4" />
        <Skeleton className="w-1/4 h-4" />
      </div>
      <Skeleton className="w-3/4 h-4" />
      <Skeleton className="w-2/3 h-4" />
    </div>
  );
};

export default ProductCardSkeleton;
