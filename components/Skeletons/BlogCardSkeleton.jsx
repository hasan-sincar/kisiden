import { Skeleton } from "../ui/skeleton";

const BlogCardSkeleton = () => {
  return (
    <div className="p-4 rounded-3xl flex flex-col gap-4 border h-100 bg-white h-full">
      <Skeleton className="w-full aspect-[388/200]" />
      <Skeleton className="w-2/3 h-4" />
      <Skeleton className="w-full h-4" />
      <Skeleton className="w-full h-4" />
      <Skeleton className="w-1/3 h-4" />
    </div>
  );
};

export default BlogCardSkeleton;
