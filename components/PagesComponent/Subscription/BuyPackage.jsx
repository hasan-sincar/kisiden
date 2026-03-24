"use client";
import { useEffect, useState } from "react";
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
import { getIsRtl } from "@/redux/reducer/languageSlice";
import { useSelector } from "react-redux";
import { getIsLoggedIn } from "@/redux/reducer/authSlice";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import { toast } from "sonner";
import BankDetailsModal from "./BankDetailsModal";
import AdListingPublicPlanCardSkeleton from "@/components/Skeletons/AdListingPublicPlanCardSkeleton";
import { getIsFreAdListing } from "@/redux/reducer/settingSlice";
import { useNavigate } from "@/components/Common/useNavigate";
import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams";
import EmptyMessage from "@/components/EmptyStates/EmptyMessage";
import BuyPackageCard from "./BuyPackageCard";
import ReusableAlertDialog from "@/components/Common/ReusableAlertDialog";

const BuyPackage = ({ categoryId, isFeaturedPlan }) => {
  const isRTL = useSelector(getIsRtl);
  const { navigate } = useNavigate();
  const langCode = useLangFromSearchParams()

  const [listingPackages, setListingPackages] = useState([]);
  const hasListingDiscount = listingPackages?.some(
    (p) => p?.discount_in_percentage > 0
  );
  const [isListingPackagesLoading, setIsListingPackagesLoading] =
    useState(false);

  const [selectedPackage, setSelectedPackage] = useState(null);

  const [adPackages, setAdPackages] = useState([]);
  const hasAdDiscount = adPackages.some((p) => p.discount_in_percentage > 0);
  const [isAdPackagesLoading, setIsAdPackagesLoading] = useState(false);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [packageSettings, setPackageSettings] = useState(null);
  const isLoggedIn = useSelector(getIsLoggedIn);
  const isFreeAdListing = useSelector(getIsFreAdListing);

  const [showFreeConfirmModal, setShowFreeConfirmModal] = useState(false);
  const [packageToAssign, setPackageToAssign] = useState(null);
  const [isAssigningPackage, setIsAssigningPackage] = useState(false);

  useEffect(() => {
    if (!isFreeAdListing && !isFeaturedPlan) {
      handleFetchListingPackages();
    }
    if (isFeaturedPlan) {
      handleFetchFeaturedPackages();
    }
  }, [langCode]);

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
      const res = await getPackageApi.getPackage({
        type: "item_listing", ...(categoryId && { category_id: categoryId }), is_subscribed: 0
      });
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
      const res = await getPackageApi.getPackage({ type: "advertisement", is_subscribed: 0 });
      setAdPackages(res.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsAdPackagesLoading(false);
    }
  };

  const handlePurchasePackage = (pckg) => {
    if (!isLoggedIn) {
      setIsLoginOpen(true);
      return;
    }
    if (pckg?.final_price === 0) {
      if (pckg?.is_purchased_before) {
        toast.error(t("alreadyPurchasedFreePackage"));
        return;
      }
      // Instead of calling assignPackage(pckg.id) directly:
      setPackageToAssign(pckg.id); // Save the ID
      setShowFreeConfirmModal(true); // Show the alert dialog
    } else {
      setShowPaymentModal(true);
      setSelectedPackage(pckg);
    }
  };

  const assignPackage = async (id) => {
    try {
      setIsAssigningPackage(true);
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
    } finally {
      setIsAssigningPackage(false);
    }
  };

  const handleConfirmFreePackage = () => {
    if (packageToAssign) {
      assignPackage(packageToAssign);
    }
    setShowFreeConfirmModal(false);
  };

  return (
    <div className="container">
      {isListingPackagesLoading ? (
        <AdListingPublicPlanCardSkeleton />
      ) : (
        !isFreeAdListing && !isFeaturedPlan &&
        <div className="flex flex-col gap-4 mt-8">
          <h1 className="text-2xl font-medium">{t("adListingPlan")}</h1>
          {
            listingPackages?.length > 0 ?
              <div className="relative">
                <Carousel
                  key={isRTL ? "rtl" : "ltr"}
                  opts={{
                    align: "start",
                    containScroll: "trim",
                    direction: isRTL ? "rtl" : "ltr",
                  }}
                >
                  <CarouselPrevious className="hidden md:flex absolute top-1/2 ltr:left-2 rtl:right-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                  <CarouselNext className="hidden md:flex absolute top-1/2 ltr:right-2 rtl:left-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                  <CarouselContent
                    className={`sm:gap-4 ${hasListingDiscount ? "pt-6" : ""}`}
                  >
                    {listingPackages?.map((pckg) => (
                      <CarouselItem
                        key={pckg.id}
                        className="basis-[90%] sm:basis-[75%] md:basis-[55%] lg:basis-[45%] xl:basis-[35%] 2xl:basis-[30%]"
                      >
                        <BuyPackageCard
                          pckg={pckg}
                          handlePurchasePackage={handlePurchasePackage}
                        />
                      </CarouselItem>
                    ))}
                  </CarouselContent>
                </Carousel>
              </div>
              :
              <EmptyMessage message={t("noAdListingPlanFound")} />
          }
        </div>
      )}

      {
        isFeaturedPlan && (
          isAdPackagesLoading ? (
            <AdListingPublicPlanCardSkeleton />
          ) : (
            <div className="flex flex-col gap-4 mt-8">
              <h1 className="text-2xl font-medium">{t("featuredAdPlan")}</h1>
              {
                adPackages.length > 0 ?
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
                      <CarouselPrevious className="hidden md:flex absolute top-1/2 ltr:left-2 rtl:right-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                      <CarouselNext className="hidden md:flex absolute top-1/2 ltr:right-2 rtl:left-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                      <CarouselContent
                        className={`sm:gap-4 ${hasAdDiscount ? "pt-6" : ""}`}
                      >
                        {adPackages?.map((pckg) => (
                          <CarouselItem
                            key={pckg.id}
                            className="basis-[90%] sm:basis-[75%] md:basis-[55%] lg:basis-[45%] xl:basis-[35%] 2xl:basis-[30%]"
                          >
                            <BuyPackageCard
                              pckg={pckg}
                              handlePurchasePackage={handlePurchasePackage}
                            />
                          </CarouselItem>
                        ))}
                      </CarouselContent>
                    </Carousel>
                  </div>
                  :
                  <EmptyMessage message={t('noFeaturedAdPlanfound')} />
              }
            </div>
          )
        )}

      <PaymentModal
        showPaymentModal={showPaymentModal}
        setShowPaymentModal={setShowPaymentModal}
        selectedPackage={selectedPackage}
        packageSettings={packageSettings}
        isLoading={isLoading}
      />
      <BankDetailsModal
        packageId={selectedPackage?.id}
        bankDetails={packageSettings?.bankTransfer}
      />
      <ReusableAlertDialog
        open={showFreeConfirmModal}
        title={t("confirm")}
        description={t("confirmFreePackage")}
        onCancel={() => setShowFreeConfirmModal(false)}
        onConfirm={handleConfirmFreePackage}
        confirmText={t("confirm")}
        cancelText={t("cancel")}
        confirmDisabled={isAssigningPackage}
      />
    </div>
  );
};

export default BuyPackage;