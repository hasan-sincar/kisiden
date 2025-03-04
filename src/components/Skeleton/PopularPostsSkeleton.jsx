import Skeleton, { SkeletonTheme } from "react-loading-skeleton"
const PopularPostsSkeleton = () => {
    return (
        <SkeletonTheme baseColor="lightgray" highlightColor="#e0e0e0">

            <div className="popular_posts">
                <h6 className="pop_post_title"><Skeleton width="80%" /></h6>
                <div className="popular_posts_item_wrapper">
                    {Array.from({ length: 6 }).map((_, index) => (
                        <div className="popular_posts_item" key={index}>
                            <Skeleton width="66px" height="55px" />
                            <div className="w-100">
                                <Skeleton width="100%" height={20} />
                            </div>
                        </div>
                    ))}
                </div>

            </div>


        </SkeletonTheme>
    )
}

export default PopularPostsSkeleton