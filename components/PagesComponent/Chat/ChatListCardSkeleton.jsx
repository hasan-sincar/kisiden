import { Skeleton } from "@/components/ui/skeleton";

const ChatListCardSkeleton = () => {
    return (
        <div className="p-4 border-b">
            <div className="flex items-start gap-3">
                {/* Avatar skeleton */}
                <Skeleton className="w-12 h-12 rounded-full" />

                <div className="flex-1">
                    {/* Name skeleton */}
                    <Skeleton className="h-4 w-[40%] mb-2 rounded-md" />

                    {/* Message skeleton */}
                    <Skeleton className="h-3 w-[70%] rounded-md" />
                </div>

                {/* Time skeleton */}
                <Skeleton className="h-3 w-[15%] rounded-md" />
            </div>
        </div>
    )
}

export default ChatListCardSkeleton 