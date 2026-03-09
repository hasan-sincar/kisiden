import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

const JobApplicationCardSkeleton = () => {
  return (
    <Card className="hover:shadow-md transition-shadow duration-200">
      <CardHeader>
        <div className="flex items-center justify-between">
          <Skeleton className="h-6 w-32" />
          <Skeleton className="h-6 w-20" />
        </div>
      </CardHeader>

      <CardContent>
        <div className="space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div className="flex flex-col space-y-1">
              <Skeleton className="h-3 w-12" />
              <Skeleton className="h-4 w-40" />
            </div>

            <div className="flex flex-col space-y-1">
              <Skeleton className="h-3 w-12" />
              <Skeleton className="h-4 w-32" />
            </div>

            <div className="flex flex-col space-y-1 sm:col-span-2">
              <Skeleton className="h-3 w-20" />
              <Skeleton className="h-4 w-36" />
            </div>
          </div>

          <div className="space-y-3">
            <Skeleton className="h-px w-full" />
            <div className="flex flex-wrap gap-2">
              <Skeleton className="h-8 w-20" />
              <Skeleton className="h-8 w-20" />
              <Skeleton className="h-8 w-24" />
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default JobApplicationCardSkeleton;
