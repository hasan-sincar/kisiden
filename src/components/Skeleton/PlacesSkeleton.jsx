import Skeleton, { SkeletonTheme } from "react-loading-skeleton"

const PlacesSkeleton = () => {
    return (
        <SkeletonTheme baseColor="lightgray" highlightColor="#e0e0e0">
            {Array.from({ length: 5 }).map((_, index) => (
                <div key={index} className="p-2">
                    <Skeleton count={1} />
                    <Skeleton count={0.9} />
                </div>
            ))}
        </SkeletonTheme>
    );
};

export default PlacesSkeleton;
