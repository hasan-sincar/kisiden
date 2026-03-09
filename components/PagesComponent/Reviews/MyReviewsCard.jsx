"use client";
import { GoReport } from "react-icons/go";
import StarRating from "./StarRating";
import { formatDate, t } from "@/utils";
import { useState, useRef, useEffect } from "react";
import ReportReviewModal from "./ReportReviewModal";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import CustomImage from "@/components/Common/CustomImage";

const MyReviewsCard = ({ rating, setMyReviews }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const [isTextOverflowing, setIsTextOverflowing] = useState(false);
  const textRef = useRef(null);
  const [IsReportModalOpen, setIsReportModalOpen] = useState(false);
  const [SellerReviewId, setSellerReviewId] = useState("");

  useEffect(() => {
    const checkTextOverflow = () => {
      if (textRef.current) {
        const isOverflowing =
          textRef.current.scrollHeight > textRef.current.clientHeight;
        setIsTextOverflowing(isOverflowing);
      }
    };

    checkTextOverflow();
    window.addEventListener("resize", checkTextOverflow);

    return () => window.removeEventListener("resize", checkTextOverflow);
  }, []);

  const handleReportClick = (id) => {
    setSellerReviewId(id);
    setIsReportModalOpen(true);
  };

  return (
    <div className="bg-white p-4 rounded-lg flex flex-col gap-4">
      <div className="flex flex-col sm:flex-row flex-1 gap-4">
        <div className="relative w-fit">
          <CustomImage
            src={rating?.buyer?.profile}
            width={72}
            height={72}
            alt="Reviewer"
            className="aspect-square rounded-full object-cover"
          />
          <CustomImage
            src={rating?.item?.image}
            width={36}
            height={36}
            alt="Reviewer"
            className="absolute top-12 bottom-[-6px] right-[-6px] w-[36px] h-auto aspect-square rounded-full object-cover"
          />
        </div>

        <div className="flex-1">
          <div className="flex flex-1 items-center justify-between">
            <p className="font-semibold">{rating?.buyer?.name}</p>
            {rating?.report_status ? (
              <div></div>
            ) : (
              <TooltipProvider>
                <Tooltip>
                  <TooltipTrigger asChild>
                    <button onClick={() => handleReportClick(rating?.id)}>
                      <GoReport />
                    </button>
                  </TooltipTrigger>
                  <TooltipContent side="left" align="center">
                    <p>{t("reportReview")}</p>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
            )}
          </div>

          <p className="mt-1 text-sm line-clamp-1">
            {rating?.item?.translated_name || rating?.item?.name}
          </p>
          <div className="mt-1 flex items-center gap-1">
            <StarRating rating={Number(rating?.ratings)} size={24} />
            <span className="text-sm text-muted-foreground">
              {rating?.ratings}
            </span>
          </div>
          <p className="text-sm mt-1 justify-self-end">
            {formatDate(rating?.created_at)}
          </p>
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
              {isExpanded ? "See Less" : "See More"}
            </button>
          </div>
        )}
      </div>

      {/* Report Review Modal */}
      <ReportReviewModal
        isOpen={IsReportModalOpen}
        setIsOpen={setIsReportModalOpen}
        reviewId={SellerReviewId}
        setMyReviews={setMyReviews}
      />
    </div>
  );
};
export default MyReviewsCard;
