import { t } from '@/utils';
import RatingsSummary from '../Reviews/RatingsSummary';
import SellerReviewCard from "@/components/PagesComponent/Reviews/SellerReviewCard";
import { Button } from '@/components/ui/button';
import NoData from '@/components/EmptyStates/NoData';


const SellerRating = ({ ratingsData, seller, isLoadMoreReview, reviewHasMore, reviewCurrentPage, getSeller }) => {

    return (
        ratingsData?.data?.length > 0 ?
            <>
                <RatingsSummary averageRating={seller?.average_rating} reviews={ratingsData?.data} />
                <div className='flex flex-col gap-4 bg-muted p-4 rounded-lg'>
                    {ratingsData?.data?.map((rating) => (
                        <SellerReviewCard key={rating.id} rating={rating} />
                    ))}
                    {
                        ratingsData?.data?.length > 0 && reviewHasMore && (
                            <div className="text-center">
                                <Button
                                    variant="outline"
                                    className="text-sm sm:text-base text-primary w-[256px]"
                                    disabled={isLoadMoreReview}
                                    onClick={() => getSeller(reviewCurrentPage + 1)}
                                >
                                    {isLoadMoreReview ? t("loading") : t("loadMore")}
                                </Button>
                            </div>
                        )
                    }
                </div>
            </>
            :
            <NoData name={t('reviews')} />
    );
};

export default SellerRating;