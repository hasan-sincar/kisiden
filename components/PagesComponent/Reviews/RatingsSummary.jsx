'use client'
import StarRating from "./StarRating";
import { t } from "@/utils";
import { TiStarFullOutline } from "react-icons/ti";
import { Progress } from "@/components/ui/progress";

const RatingsSummary = ({ averageRating, ratings_count }) => {

    // Calculate total ratings from the object
    const totalRatings = ratings_count
        ? Object.values(ratings_count).reduce((sum, count) => sum + Number(count), 0)
        : 0;

    return (
        <div className="grid grid-cols-1 md:grid-cols-12 p-4 rounded-xl border">
            {/* Average Rating Section */}
            <div className="col-span-4 border-b md:border-b-0 ltr:md:border-r rtl:md:border-l pb-4 md:pb-0 ltr:md:pr-4 rtl:md:pl-4">
                <h1 className="font-bold text-6xl text-center">{Number(averageRating).toFixed(2)}</h1>
                <div className="mt-4 flex flex-col items-center justify-center gap-1">
                    <StarRating rating={Number(averageRating)} size={40} />
                    <p className="text-sm">{totalRatings} {t('ratings')}</p>
                </div>
            </div>

            {/* Rating Progress Bars Section */}
            <div className="col-span-8 pt-4 md:pt-0 ltr:md:pl-8 rtl:md:pr-8">
                <div className="flex flex-col gap-2">
                    {[5, 4, 3, 2, 1].map((rating) => {
                        const count = ratings_count?.[rating] || 0;
                        const percentage = totalRatings > 0 ? (count / totalRatings) * 100 : 0;
                        return (
                            <div className="flex items-center gap-2" key={`rating-${rating}`}>
                                <div className="flex items-center gap-1">
                                    {rating}
                                    <TiStarFullOutline color="black" size={24} />
                                </div>
                                <Progress value={percentage} className='h-3' />
                                <span>{count}</span>
                            </div>
                        )
                    })}
                </div>
            </div>
        </div>
    );
};

export default RatingsSummary; 