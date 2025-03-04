import Skeleton, { SkeletonTheme } from "react-loading-skeleton"

const BlogTagsSkeleton = () => {
    return (
        <SkeletonTheme baseColor="lightgray" highlightColor="#e0e0e0">
            <div className="tags">
                <div className="tags_title">
                    <Skeleton width="80%" />
                </div>
                <div className="tags_item_wrapper">
                    {Array.from({ length: 30 }).map((_, index) => (
                        <Skeleton width="50px" key={index} />
                    ))}
                </div>
            </div>
        </SkeletonTheme>
    )
}

export default BlogTagsSkeleton