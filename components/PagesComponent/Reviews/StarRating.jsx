'use client'
import { TiStarFullOutline, TiStarHalfOutline, TiStarOutline } from "react-icons/ti";

const StarRating = ({ rating = 0, size = 16, maxStars = 5, showEmpty = true }) => {

    // Get the integer part of the rating (full stars)
    const fullStars = Math.floor(rating);

    // Check if there's any decimal part at all (0.1, 0.2, ..., 0.9)
    const hasDecimal = rating % 1 !== 0;

    // If there's any decimal, always show a half star
    const hasHalfStar = hasDecimal;

    // Calculate empty stars
    const emptyStars = maxStars - fullStars - (hasHalfStar ? 1 : 0);

    return (
        <div className="flex items-center gap-1 max-w-full">
            {/* Render full stars */}
            {[...Array(fullStars)].map((_, index) => (
                <TiStarFullOutline key={`full-${index}`} color="#FFD700" size={size} />
            ))}

            {/* Render half star if there's any decimal */}
            {hasHalfStar && (
                <TiStarHalfOutline key="half" className="rtl:scale-x-[-1]" color="#FFD700" size={size} />
            )}

            {/* Render empty stars */}
            {showEmpty && [...Array(emptyStars)].map((_, index) => (
                <TiStarOutline key={`empty-${index}`} color="#0000002E" size={size} />
            ))}
        </div>
    );
};

export default StarRating;