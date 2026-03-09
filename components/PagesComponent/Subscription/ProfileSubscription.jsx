"use client";
import { useEffect, useState } from "react";
import AddListingPlanCard from "@/components/PagesComponent/Cards/AddListingPlanCard";
import {
  assigFreePackageApi,
  getPackageApi,
  getPaymentSettingsApi,
} from "@/utils/api";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
} from "@/components/ui/carousel";
import { t } from "@/utils";
import PaymentModal from "./PaymentModal";
import AddListingPlanCardSkeleton from "@/components/Skeletons/AddListingPlanCardSkeleton";
import { CurrentLanguageData, getIsRtl } from "@/redux/reducer/languageSlice";
import { useSelector } from "react-redux";
import { toast } from "sonner";
import BankDetailsModal from "./BankDetailsModal";
import { getIsFreAdListing } from "@/redux/reducer/settingSlice";
import { useNavigate } from "@/components/Common/useNavigate";

const ProfileSubscription = () => {
  const isRTL = useSelector(getIsRtl);
  const { navigate } = useNavigate();
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [listingPackages, setListingPackages] = useState([]);

  const hasListingDiscount = listingPackages?.some(
    (p) => p?.discount_in_percentage > 0
  );

  const [adPackages, setAdPackages] = useState([]);
  const hasAdDiscount = adPackages.some((p) => p.discount_in_percentage > 0);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [selectedPackage, setSelectedPackage] = useState(null);
  const [isListingPackagesLoading, setIsListingPackagesLoading] =
    useState(false);
  const [isAdPackagesLoading, setIsAdPackagesLoading] = useState(false);
  const [packageSettings, setPackageSettings] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const isFreeAdListing = useSelector(getIsFreAdListing);
  const [toggleApiAfterPaymentSuccess, setToggleApiAfterPaymentSuccess] = useState(false)


  useEffect(() => {
    if (!isFreeAdListing) {
      handleFetchListingPackages();
    }
    handleFetchFeaturedPackages();
  }, [CurrentLanguage?.id, toggleApiAfterPaymentSuccess]);

  useEffect(() => {
    if (showPaymentModal) {
      handleFetchPaymentSetting();
    }
  }, [showPaymentModal]);

  const handleFetchPaymentSetting = async () => {
    setIsLoading(true);
    try {
      const res = await getPaymentSettingsApi.getPaymentSettings();
      const { data } = res.data;
      setPackageSettings(data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleFetchListingPackages = async () => {
    try {
      setIsListingPackagesLoading(true);
      const res = await getPackageApi.getPackage({ type: "item_listing" });
      setListingPackages(res?.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsListingPackagesLoading(false);
    }
  };

  const handleFetchFeaturedPackages = async () => {
    try {
      setIsAdPackagesLoading(true);
      const res = await getPackageApi.getPackage({ type: "advertisement" });
      setAdPackages(res.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsAdPackagesLoading(false);
    }
  };

  const handlePurchasePackage = (pckg) => {
    if (pckg?.final_price === 0) {
      assignPackage(pckg.id);
    } else {
      setShowPaymentModal(true);
      setSelectedPackage(pckg);
    }
  };

  const assignPackage = async (id) => {
    try {
      const res = await assigFreePackageApi.assignFreePackage({
        package_id: id,
      });
      const data = res?.data;
      if (data?.error === false) {
        toast.success(data.message);
        navigate("/");
      } else {
        toast.error(data.message);
      }
    } catch (error) {
      toast.error(data.message);
      console.log(error);
    }
  };

  return (
    <>
      {isListingPackagesLoading ? (
        <AddListingPlanCardSkeleton />
      ) : (
        <>
          {listingPackages.length > 0 && (
            <div className="flex flex-col gap-4">
              <h1 className="text-2xl font-medium">{t("adListingPlan")}</h1>
              <div className="relative">
                <Carousel
                  key={isRTL ? "rtl" : "ltr"}
                  opts={{
                    align: "start",
                    containScroll: "trim",
                    direction: isRTL ? "rtl" : "ltr",
                  }}
                  className="w-full"
                >
                  <CarouselPrevious className="flex absolute top-1/2 ltr:left-2 rtl:right-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                  <CarouselNext className="flex absolute top-1/2 ltr:right-2 rtl:left-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                  <CarouselContent
                    className={`gap-4 ${hasListingDiscount ? "pt-6" : ""}`}
                  >
                    {listingPackages?.map((pckg) => (
                      <CarouselItem
                        key={pckg.id}
                        className="basis-[100%] sm:basis-3/4 md:basis-1/2 lg:basis-[66.66%] xl:basis-[45%] first:pl-4"
                      >
                        <AddListingPlanCard
                          pckg={pckg}
                          handlePurchasePackage={handlePurchasePackage}
                        />
                      </CarouselItem>
                    ))}
                  </CarouselContent>
                </Carousel>
              </div>
            </div>
          )}
        </>
      )}
      {isAdPackagesLoading ? (
        <AddListingPlanCardSkeleton />
      ) : (
        <div
          className={`flex flex-col gap-4 ${listingPackages.length > 0 ? "mt-8" : ""
            }`}
        >
          <h1 className="text-2xl font-medium">{t("featuredAdPlan")}</h1>
          <div className="relative">
            <Carousel
              key={isRTL ? "rtl" : "ltr"}
              opts={{
                align: "start",
                containScroll: "trim",
                direction: isRTL ? "rtl" : "ltr",
              }}
              className="w-full"
            >
              <CarouselPrevious className="flex absolute top-1/2 ltr:left-2 rtl:right-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
              <CarouselNext className="flex absolute top-1/2 ltr:right-2 rtl:left-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />

              <CarouselContent
                className={`gap-4 ${hasAdDiscount ? "pt-6" : ""}`}
              >
                {adPackages?.map((pckg) => (
                  <CarouselItem
                    key={pckg.id}
                    className="basis-[100%] sm:basis-3/4 md:basis-1/2 lg:basis-[66.66%] xl:basis-[45%] first:pl-4"
                  >
                    <AddListingPlanCard
                      pckg={pckg}
                      handlePurchasePackage={handlePurchasePackage}
                    />
                  </CarouselItem>
                ))}
              </CarouselContent>
            </Carousel>
          </div>
        </div>
      )}
      <PaymentModal
        showPaymentModal={showPaymentModal}
        setShowPaymentModal={setShowPaymentModal}
        selectedPackage={selectedPackage}
        packageSettings={packageSettings}
        isLoading={isLoading}
        setToggleApiAfterPaymentSuccess={setToggleApiAfterPaymentSuccess}
      />
      <BankDetailsModal
        packageId={selectedPackage?.id}
        bankDetails={packageSettings?.bankTransfer}
      />
    </>
  );
};

export default ProfileSubscription;
