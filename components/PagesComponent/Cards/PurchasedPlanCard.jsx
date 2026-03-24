import { FaCheck } from "react-icons/fa";
import { formatPriceAbbreviated, formatSubscriptionDate, t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";
import { useState } from "react";
import { Progress } from "@/components/ui/progress";

const PurchasedPlanCard = ({ pckg }) => {

  const [isFlipped, setIsFlipped] = useState(false);

  const descriptionItems =
    Array.isArray(pckg?.translated_key_points) &&
      pckg.translated_key_points.length > 0
      ? pckg.translated_key_points
      : (pckg?.translated_description || pckg?.description || "")
        .split("\r\n")
        .filter(Boolean);

  const userPurchasedPackage = pckg?.user_purchased_packages?.[0]
  const remainingDays = userPurchasedPackage?.remaining_days;
  const totalLimit = userPurchasedPackage?.total_limit;
  const listingDurationDays = userPurchasedPackage?.listing_duration_days

  const usedItems = userPurchasedPackage?.used_limit;
  const progressPercentage = totalLimit ? Math.min(100, (usedItems / Number(totalLimit)) * 100) : null;

  const startDate = formatSubscriptionDate(userPurchasedPackage?.start_date);
  const endDate = formatSubscriptionDate(userPurchasedPackage?.end_date);

  return (
    <div className="perspective-1000 h-full">
      <div
        className={`h-full relative transition-transform duration-500 transform-style-preserve-3d ${isFlipped ? "rotate-y-180" : ""
          }`}
      >
        <div
          className="h-full backface-hidden rounded-lg relative p-3 sm:p-6 shadow-sm border bg-white"
        >
          {/* Card Header */}
          <div className="flex items-center gap-4">
            <CustomImage
              height={80}
              width={80}
              src={pckg.icon}
              alt="Bronze medal"
              className="aspect-square rounded-lg"
            />
            <div className="flex flex-col gap-2 overflow-hidden">
              <h2 className="text-xl font-medium mb-1 line-clamp-2 overflow-hidden">
                {pckg?.translated_name || pckg?.name}
              </h2>
              <div className="flex items-center gap-1">
                {pckg?.final_price !== 0 ? (
                  <p className="text-xl font-bold">
                    {formatPriceAbbreviated(pckg?.final_price)}
                  </p>
                ) : (
                  t("Free")
                )}
              </div>
            </div>
          </div>
          {userPurchasedPackage && (
            <div className="flex flex-col gap-4 my-6">

              {totalLimit && <div className="flex flex-col gap-2">
                <div className="flex justify-between items-center text-xs font-medium">
                  <span>{t("adsUsage")}</span>
                  <span>
                    {totalLimit === "unlimited" ? t('unlimited') : `${usedItems}/${totalLimit}`}
                  </span>
                </div>
                <Progress
                  value={progressPercentage}
                  className="h-3"
                />
              </div>}
              <div className="grid grid-cols-1 sm:grid-cols-3 bg-muted rounded-lg p-3 text-center divide-y sm:divide-y-0 sm:divide-x">
                <div className="flex flex-col gap-1 py-3 sm:py-0">
                  <span className="text-xs text-muted-foreground">
                    {t("started")}
                  </span>
                  <span className="text-sm font-bold">
                    {startDate}
                  </span>
                </div>
                <div className="flex flex-col gap-1 py-3 sm:py-0">
                  <span className="text-xs text-muted-foreground">
                    {t("expires")}
                  </span>
                  <span className="text-sm font-bold">
                    {endDate}
                  </span>
                </div>
                <div className="flex flex-col gap-1 py-3 sm:py-0">
                  <span className="text-xs text-muted-foreground">
                    {t("remaining")}
                  </span>
                  <span className="text-sm font-bold capitalize">
                    {remainingDays} {t("days")}
                  </span>
                </div>
              </div>
            </div>
          )}

          <div className="max-h-[300px] min-h-[250px] overflow-y-auto mb-3">
            <h6 className="text-base font-medium">{t('featuresList')}</h6>
            {/* Feature List */}
            <div className="flex flex-col gap-2 p-3 text-sm">
              <div className="flex items-center gap-3">
                <span
                  className="text-primary"
                >
                  <FaCheck />
                </span>
                <span className="capitalize">
                  {t("listingDuration")}: {listingDurationDays} {t("days")}
                </span>
              </div>
              {pckg.categories.length === 0 && (
                <div className="flex items-center gap-3">
                  <span
                    className="text-primary"
                  >
                    <FaCheck />
                  </span>
                  <span className="text-normal ">{t("allCategoriesIncluded")}</span>
                </div>
              )}

              {descriptionItems.map((item, index) => (
                <div key={index} className="flex items-center gap-3">
                  <span
                    className="text-primary"
                  >
                    <FaCheck />
                  </span>
                  <span className="text-normal break-all">{item}</span>
                </div>
              ))}
            </div>

            {pckg.categories.length > 0 && (
              <>
                <h6 className="text-base font-medium">{t("categoryIncludes")}</h6>
                <div className="flex flex-col gap-2 p-3 text-sm">
                  {pckg.categories.slice(0, 2).map((category) => (
                    <div key={category.id} className="flex items-center gap-3">
                      <span
                        className="text-primary"
                      >
                        <FaCheck />
                      </span>
                      <span className="text-normal break-all">
                        {category.translated_name || category.name}
                      </span>
                    </div>
                  ))}
                </div>
                {pckg.categories.length > 2 && (
                  <button
                    onClick={() => setIsFlipped(true)}
                    className="text-sm underline px-3 text-primary"
                  >
                    {t("seeMore")}
                  </button>
                )}
              </>
            )}
          </div>
        </div>
        <div
          className="absolute inset-0 rotate-y-180 backface-hidden rounded-lg p-4 sm:p-8 shadow-sm border bg-white"
        >
          <h6 className="text-lg font-medium mb-4">{t("allCategories")}</h6>

          <div className="flex flex-col gap-2 overflow-y-auto max-h-[300px]">
            {pckg.categories.map((category) => (
              <div key={category.id} className="flex items-center gap-3">
                <FaCheck className="text-primary" />
                <span>{category.translated_name || category.name}</span>
              </div>
            ))}
          </div>

          <button
            onClick={() => setIsFlipped(false)}
            className="mt-4 text-sm underline text-primary"
          >
            {t("back")}
          </button>
        </div>
      </div>
    </div >
  );
};

export default PurchasedPlanCard;
