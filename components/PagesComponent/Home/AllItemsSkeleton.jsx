import { useId } from "react";
import ProductCardSkeleton from "../../Common/ProductCardSkeleton";

const AllItemsSkeleton = () => {
  return (
    <>
      {Array.from({ length: 8 }).map(() => (
        <ProductCardSkeleton key={useId()} />
      ))}
    </>
  );
};

export default AllItemsSkeleton;
