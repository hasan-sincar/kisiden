import { Skeleton } from "@/components/ui/skeleton"

const SoldOutModalSkeleton = () => {
    return (
        <>
            <div className='mt-4 flex flex-col gap-6'>
                <div className='rounded-md p-2 bg-muted flex items-center gap-4'>
                    <Skeleton className='h-20 w-20 rounded-md' />
                    <div className='w-full'>
                        <Skeleton className='h-5 w-3/5 mb-2' />
                        <Skeleton className='h-7 w-2/5' />
                    </div>
                </div>
                <Skeleton className='h-5 w-4/5' />

                {/* Buyers list skeletons */}
                {[1, 2, 3].map((item) => (
                    <div key={item} className='flex justify-between'>
                        <div className='flex gap-4 items-center'>
                            <Skeleton className='h-12 w-12 rounded-full' />
                            <Skeleton className='h-4 w-24' />
                        </div>
                        <Skeleton className='h-4 w-4 rounded-full' />
                    </div>
                ))}

                <div className='pt-6 pb-1 border-t flex items-center justify-between'>
                    <div className='flex items-center gap-2'>
                        <Skeleton className='h-4 w-4' />
                        <Skeleton className='h-4 w-1/3' />
                    </div>
                    <Skeleton className='h-10 w-1/4 rounded-md' />
                </div>
            </div>
        </>
    )
}

export default SoldOutModalSkeleton 