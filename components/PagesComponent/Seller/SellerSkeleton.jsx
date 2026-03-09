import { Skeleton } from '@/components/ui/skeleton';

const SellerSkeleton = ({ steps }) => {
  return (
    <div className="container mx-auto mt-6">
      <div className="grid grid-cols-1 md:grid-cols-12 gap-4">
        {/* Left Side - Seller Detail Card Skeleton */}
        <div className="col-span-12 md:col-span-4">
          <div className="bg-white rounded-lg shadow-sm border p-6">
            <div className="flex flex-col items-center gap-4">
              <Skeleton className="h-32 w-32 rounded-full" />
              <Skeleton className="h-6 w-3/4" />
              <Skeleton className="h-4 w-1/2" />
              <div className="flex gap-2">
                {[1, 2, 3, 4, 5].map(i => (
                  <Skeleton key={i} className="h-5 w-5 rounded-full" />
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Right Side - Content Skeleton */}
        <div className="flex flex-col gap-4 col-span-12 md:col-span-8">
          {/* Tabs Skeleton */}
          <div className="p-4 flex items-center gap-4 bg-muted rounded-md w-full">
            <Skeleton className="h-10 w-24" />
            <Skeleton className="h-10 w-24" />
          </div>

          {/* Content Area Skeleton */}

          {steps === 1 ? (
            // Listings Skeleton
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {[1, 2, 3, 4, 5, 6].map(i => (
                <div key={i} className="border rounded-lg p-4">
                  <Skeleton className="h-40 w-full mb-4" />
                  <Skeleton className="h-4 w-3/4 mb-2" />
                  <Skeleton className="h-4 w-1/2" />
                </div>
              ))}
            </div>
          ) : (
            // Ratings Skeleton
            <div className="flex flex-col gap-6">
              <div className="flex gap-6 items-center">
                <div className="flex flex-col gap-3 items-center">
                  <Skeleton className="h-16 w-16" />
                  <div className="flex gap-2">
                    {[1, 2, 3, 4, 5].map(i => (
                      <Skeleton key={i} className="h-5 w-5" />
                    ))}
                  </div>
                  <Skeleton className="h-4 w-20" />
                </div>
                <div className="flex-1">
                  {[5, 4, 3, 2, 1].map(i => (
                    <div key={i} className="flex items-center space-x-3 mb-3">
                      <Skeleton className="h-4 w-4" />
                      <Skeleton className="h-2 flex-1" />
                      <Skeleton className="h-4 w-8" />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default SellerSkeleton;
