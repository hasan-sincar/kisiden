import { FaArrowRight, FaCheck } from "react-icons/fa";
import { formatPriceAbbreviated, t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";
import { useState } from "react";

const AddListingPlanCard = ({ pckg, handlePurchasePackage }) => {

  const [isFlipped, setIsFlipped] = useState(false);

  const descriptionItems =
    Array.isArray(pckg?.translated_key_points) &&
      pckg.translated_key_points.length > 0
      ? pckg.translated_key_points
      : (pckg?.translated_description || pckg?.description || "")
        .split("\r\n")
        .filter(Boolean);

  const isPackageActive = pckg?.is_active == 1;

  const userPurchasedPackage = pckg?.user_purchased_packages?.[0]
  const remainingDays = userPurchasedPackage?.remaining_days;
  const remainingItems = userPurchasedPackage?.remaining_item_limit;
  const totalDays = pckg?.duration;
  const totalItems = pckg?.item_limit;
  const listingDurationDays = isPackageActive ? userPurchasedPackage?.listing_duration_days : pckg?.listing_duration_days

  return (

    <div className="perspective-1000">
      <div
        className={`relative transition-transform duration-500 transform-style-preserve-3d ${isFlipped ? "rotate-y-180" : ""
          }`}
      >
        <div
          className={`backface-hidden rounded-lg relative p-4 sm:p-8 shadow-sm border ${isPackageActive == 1 ? "bg-primary !text-white" : "bg-white"
            }`}
        >
          {/* Sale Badge */}
          {pckg?.discount_in_percentage > 0 && (
            <div className="absolute -top-4 left-1/2 transform -translate-x-1/2 z-20">
              <span className="bg-primary text-white px-6 py-2 rounded-full text-sm font-medium whitespace-nowrap">
                {t("save")} {pckg?.discount_in_percentage}% {t("off")}
              </span>
            </div>
          )}

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
                {pckg?.price > pckg?.final_price && (
                  <p className="text-xl font-bold line-through text-gray-500">
                    {formatPriceAbbreviated(pckg?.price)}
                  </p>
                )}
              </div>
            </div>
          </div>

          {/* Divider */}
          <div className="border-t border-gray-200 my-6"></div>

          <div className="h-[250px] overflow-y-auto mb-3">
            <h6 className="text-base font-medium">Features List</h6>

            {/* Feature List */}
            <div className="flex flex-col gap-2 p-3 text-sm">
              <div className="flex items-center gap-3">
                <span
                  className={`${isPackageActive == 1 ? "text-white" : "text-primary"
                    }`}
                >
                  <FaCheck />
                </span>
                <span className="text-normal capitalize">
                  {t("packageValidity")}:{" "}
                  {isPackageActive
                    ? `${remainingDays} / ${totalDays} ${t("days")}`
                    : `${totalDays} ${t("days")}`}
                </span>
              </div>
              <div className="flex items-center gap-3">
                <span
                  className={`${isPackageActive == 1 ? "text-white" : "text-primary"
                    }`}
                >

                  <FaCheck />
                </span>
                <span className="capitalize">
                  {t("listingDuration")}: {listingDurationDays} {t("days")}
                </span>
              </div>
              <div className="flex items-center gap-3">
                <span
                  className={`${isPackageActive == 1 ? "text-white" : "text-primary"
                    }`}
                >
                  <FaCheck />
                </span>
                <span className="text-normal">
                  {totalItems === "unlimited"
                    ? t("unlimited")
                    : isPackageActive
                      ? `${remainingItems} / ${totalItems}`
                      : totalItems}{" "}
                  {t("adsListing")}
                </span>
              </div>

              {pckg.categories.length === 0 && (
                <div className="flex items-center gap-3">
                  <span
                    className={`${isPackageActive == 1 ? "text-white" : "text-primary"
                      }`}
                  >
                    <FaCheck />
                  </span>
                  <span className="text-normal ">{t("allCategoriesIncluded")}</span>
                </div>
              )}

              {descriptionItems.map((item, index) => (
                <div key={index} className="flex items-center gap-3">
                  <span
                    className={`${isPackageActive == 1 ? "text-white" : "text-primary"
                      }`}
                  >
                    <FaCheck />
                  </span>
                  <span className="text-normal ">{item}</span>
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
                        className={`${isPackageActive == 1 ? "text-white" : "text-primary"
                          }`}
                      >
                        <FaCheck />
                      </span>
                      <span className="text-normal ">
                        {category.translated_name || category.name}
                      </span>
                    </div>
                  ))}
                </div>
                {pckg.categories.length > 2 && (
                  <button
                    onClick={() => setIsFlipped(true)}
                    className={`text-sm underline px-3 ${isPackageActive == 1 ? "text-white" : "text-primary"
                      }`}
                  >
                    {t("seeMore")}
                  </button>
                )}
              </>
            )}
          </div>

          <div className="flex items-center justify-center h-12 max-h-12 p-4 md:p-0">
            <button
              onClick={() => handlePurchasePackage(pckg)}
              className={` w-full ${isPackageActive == 1 ? "hidden" : "flex"
                } py-1 px-3 md:py-2 md:px-4 lg:py-3 lg:px-6 rounded-lg  items-center text-primary  justify-center hover:bg-primary border hover:text-white transition-all duration-300`}
            >
              <span className="font-light text-lg">{t("choosePlan")}</span>
              <span className="ml-2">
                <FaArrowRight size={20} className="rtl:scale-x-[-1]" />
              </span>
            </button>
          </div>


        </div>
        <div
          className={`absolute inset-0 rotate-y-180 backface-hidden rounded-lg p-4 sm:p-8 shadow-sm border
    ${isPackageActive == 1 ? "bg-primary text-white" : "bg-white"}
  `}
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
            className={`mt-4 text-sm underline ${isPackageActive == 1 ? "text-white" : "text-primary"
              }`}
          >
            {t("back")}
          </button>
        </div>
      </div>
    </div >
  );
};

export default AddListingPlanCard;
