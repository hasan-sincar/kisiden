import { formatDate, t } from "@/utils";
import { useEffect, useRef, useState } from "react";
import StarRating from "./StarRating";
import CustomImage from "@/components/Common/CustomImage";

const SellerReviewCard = ({ rating }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isTextOverflowing, setIsTextOverflowing] = useState(false);
  const textRef = useRef(null);

  useEffect(() => {
    const checkOverflow = () => {
      const content = textRef.current;
      if (content) {
        setIsTextOverflowing(content.scrollHeight > content.clientHeight);
      }
    };
    checkOverflow();
    window.addEventListener("resize", checkOverflow);
    return () => window.removeEventListener("resize", checkOverflow);
  }, []);

  return (
    <div className="bg-white p-4 rounded-lg flex flex-col gap-4">
      <div className="flex sm:items-center gap-4 flex-col sm:flex-row">
        <CustomImage
          src={rating?.buyer?.profile}
          width={72}
          height={72}
          alt="Reviewer"
          className="aspect-square rounded-full object-cover"
        />
        <div className="flex flex-col gap-1 w-full">
          <p className="font-semibold">{rating?.buyer?.name}</p>

          <div className="flex items-center justify-between flex-wrap gap-1 w-full">
            <div className="flex items-center gap-1">
              <StarRating rating={Number(rating?.ratings)} size={24} />
              <span className="text-sm text-muted-foreground">
                {rating?.ratings}
              </span>
            </div>
            <p className="text-sm justify-self-end">
              {formatDate(rating?.created_at)}
            </p>
          </div>
        </div>
      </div>
      <div className="border-b"></div>

      <div>
        <p ref={textRef} className={`${!isExpanded ? "line-clamp-2" : ""}`}>
          {rating?.review}
        </p>
        {isTextOverflowing && (
          <div className="flex justify-center mt-1">
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              className="text-primary text-sm hover:underline"
            >
              {isExpanded ? t("seeLess") : t("seeMore")}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default SellerReviewCard;
