"use client";
import { useEffect, useState } from "react";
import PurchasedPlanCard from "@/components/PagesComponent/Cards/PurchasedPlanCard";
import {
  getPackageApi,
} from "@/utils/api";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
} from "@/components/ui/carousel";
import { t } from "@/utils";
import AddListingPlanCardSkeleton from "@/components/Skeletons/AddListingPlanCardSkeleton";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import { useSelector } from "react-redux";
import { useNavigate } from "@/components/Common/useNavigate";
import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams";
import EmptyMessage from "@/components/EmptyStates/EmptyMessage";
import { IoIosAddCircleOutline } from "react-icons/io";
import { Button } from "@/components/ui/button";

const ProfileSubscription = () => {
  const isRTL = useSelector(getIsRtl);
  const { navigate } = useNavigate();
  const [listingPackages, setListingPackages] = useState([]);
  const langCode = useLangFromSearchParams()

  // const hasListingDiscount = listingPackages?.some(
  //   (p) => p?.discount_in_percentage > 0
  // );

  const [adPackages, setAdPackages] = useState([]);
  // const hasAdDiscount = adPackages.some((p) => p.discount_in_percentage > 0);
  const [isListingPackagesLoading, setIsListingPackagesLoading] =
    useState(false);
  const [isAdPackagesLoading, setIsAdPackagesLoading] = useState(false);

  useEffect(() => {
    handleFetchListingPackages();
    handleFetchFeaturedPackages();
  }, [langCode]);

  const handleFetchListingPackages = async () => {
    try {
      setIsListingPackagesLoading(true);
      const res = await getPackageApi.getPackage({
        type: "item_listing",
        is_subscribed: 1
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
      const res = await getPackageApi.getPackage({
        type: "advertisement",
        is_subscribed: 1
      });
      setAdPackages(res.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsAdPackagesLoading(false);
    }
  };

  return (
    <>
      {isListingPackagesLoading ? (
        <AddListingPlanCardSkeleton />
      ) : (
        <>
          <div className="flex flex-col gap-4">
            <div className="flex items-center justify-between gap-3">
              <h1 className="text-2xl font-medium">{t("adListingPlan")}</h1>
              <Button className='px-3 py-1.5' onClick={() => navigate('/subscription?plan=listing')}>
                <IoIosAddCircleOutline />
                {t('buyNewPlan')}
              </Button>
            </div>
            {
              listingPackages.length > 0 ?
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
                    <CarouselPrevious className="disabled:hidden flex absolute top-1/2 ltr:left-2 rtl:right-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                    <CarouselNext className="disabled:hidden flex absolute top-1/2 ltr:right-2 rtl:left-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full z-10" />
                    <CarouselContent
                      // className={`gap-4 ${hasListingDiscount ? "pt-6" : ""}`}
                      className="gap-4"
                    >
                      {listingPackages?.map((pckg) => (
                        <CarouselItem
                          key={pckg.id}
                          className="basis-[100%] sm:basis-3/4 md:basis-1/2 lg:basis-[66.66%] xl:basis-[45%] first:pl-4"
                        >
                          <PurchasedPlanCard
                            pckg={pckg}
                          />
                        </CarouselItem>
                      ))}
                    </CarouselContent>
                  </Carousel>
                </div>
                :
                <EmptyMessage message={t('noPurchasedPlanFound')} />
            }
          </div>
        </>
      )}
      {isAdPackagesLoading ? (
        <AddListingPlanCardSkeleton />
      ) : (
        <div
          className={`flex flex-col gap-4 ${listingPackages.length > 0 ? "mt-8" : ""
            }`}
        >
          <div className="flex items-center justify-between gap-3">
            <h1 className="text-2xl font-medium">{t("featuredAdPlan")}</h1>
            <Button className='px-3 py-1.5' onClick={() => navigate('/subscription?plan=featured')}>
              <IoIosAddCircleOutline />
              {t('buyNewPlan')}
            </Button>
          </div>
          {
            adPackages?.length > 0 ?
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
                    // className={`gap-4 ${hasAdDiscount ? "pt-6" : ""}`}
                    className="gap-4"
                  >
                    {adPackages?.map((pckg) => (
                      <CarouselItem
                        key={pckg.id}
                        className="basis-[100%] sm:basis-3/4 md:basis-1/2 lg:basis-[66.66%] xl:basis-[45%] first:pl-4"
                      >
                        <PurchasedPlanCard
                          pckg={pckg}
                        />
                      </CarouselItem>
                    ))}
                  </CarouselContent>
                </Carousel>
              </div>
              :
              <EmptyMessage message={t('noPurchasedPlanFound')} />
          }
        </div>
      )}
    </>
  );
};

export default ProfileSubscription;
