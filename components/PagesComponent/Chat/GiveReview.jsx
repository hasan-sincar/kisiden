"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { FaStar } from "react-icons/fa";
import { t } from "@/utils";
import { addItemReviewApi } from "@/utils/api";
import { toast } from "sonner";

const GiveReview = ({ itemId, setSelectedChatDetails, setBuyer }) => {
  const [rating, setRating] = useState(0);
  const [hoveredRating, setHoveredRating] = useState(0);
  const [review, setReview] = useState("");
  const [errors, setErrors] = useState({
    rating: "",
    review: "",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleRatingClick = (selectedRating) => {
    setRating(selectedRating);
    setErrors((prev) => ({ ...prev, rating: "" }));
  };

  const handleMouseEnter = (starValue) => {
    setHoveredRating(starValue);
  };

  const handleMouseLeave = () => {
    setHoveredRating(0);
  };

  const handleReviewChange = (e) => {
    setReview(e.target.value);
    setErrors((prev) => ({ ...prev, review: "" }));
  };

  const validateForm = () => {
    const newErrors = {
      rating: "",
      review: "",
    };
    let isValid = true;

    if (rating === 0) {
      newErrors.rating = t("pleaseSelectRating");
      isValid = false;
    }

    if (!review.trim()) {
      newErrors.review = t("pleaseWriteReview");
      isValid = false;
    }

    setErrors(newErrors);
    return isValid;
  };

  const handleSubmit = async () => {
    if (!validateForm()) {
      return;
    }
    try {
      setIsSubmitting(true);
      const res = await addItemReviewApi.addItemReview({
        item_id: itemId,
        review,
        ratings: rating,
      });
      if (res?.data?.error === false) {
        toast.success(res?.data?.message);
        setSelectedChatDetails((prev) => ({
          ...prev,
          item: {
            ...prev.item,
            review: res?.data?.data,
          },
        }));
        setBuyer((prev) => ({
          ...prev,
          BuyerChatList: prev.BuyerChatList.map((chatItem) =>
            chatItem?.item?.id === Number(res?.data?.data?.item_id)
              ? {
                  ...chatItem,
                  item: {
                    ...chatItem.item,
                    review: res?.data?.data?.review, // use review from API
                  },
                }
              : chatItem
          ),
        }));
        setRating(0);
        setReview("");
        setErrors({
          rating: "",
          review: "",
        });
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
      toast.error(t("somethingWentWrong"));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="bg-muted p-4">
      <div className="rounded-lg p-4 bg-white">
        <div className="mb-5">
          <h3 className="text-base font-medium mb-2">{t("rateSeller")}</h3>
          <p className="text-sm text-gray-500 mb-3">{t("rateYourExp")}</p>

          <div className="flex gap-2 mb-2">
            {[1, 2, 3, 4, 5].map((starValue) => (
              <button
                key={starValue}
                type="button"
                className="p-1 focus:outline-none"
                onClick={() => handleRatingClick(starValue)}
                onMouseEnter={() => handleMouseEnter(starValue)}
                onMouseLeave={handleMouseLeave}
                aria-label={`Rate ${starValue} stars out of 5`}
                tabIndex={0}
              >
                <FaStar
                  className={`text-3xl ${
                    (hoveredRating || rating) >= starValue
                      ? "text-yellow-400"
                      : "text-gray-200"
                  }`}
                />
              </button>
            ))}
          </div>
          {errors.rating && (
            <p className="text-red-500 text-sm mt-1">{errors.rating}</p>
          )}
        </div>

        <div className="mb-4">
          <Textarea
            placeholder={t("writeAReview")}
            value={review}
            onChange={handleReviewChange}
            className={`min-h-[100px] resize-none border-gray-200 rounded ${
              errors.review ? "border-red-500" : ""
            }`}
          />
          {errors.review && (
            <p className="text-red-500 text-sm mt-1">{errors.review}</p>
          )}
        </div>

        <div className="flex justify-end">
          <Button
            onClick={handleSubmit}
            className="bg-primary text-white px-6"
            disabled={isSubmitting}
          >
            {t("submit")}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default GiveReview;
