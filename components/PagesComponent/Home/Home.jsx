"use client";
import { useEffect, useState } from "react";
import AllItems from "./AllItems";
import FeaturedSections from "./FeaturedSections";
import { FeaturedSectionApi, sliderApi } from "@/utils/api";
import OfferSliderSkeleton from "@/components/PagesComponent/Home/OfferSliderSkeleton";
import FeaturedSectionsSkeleton from "./FeaturedSectionsSkeleton";
import PopularCategories from "./PopularCategories";
import dynamic from "next/dynamic";
import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams";
import AdVertical from "@/components/AdSense/AdVertical";
import AdFooterBanner from "@/components/AdSense/AdFooterBanner";
import { useSelector } from "react-redux";
import { getAdsenseSettings } from "@/redux/reducer/settingSlice";
import { getCityData, getKilometerRange } from "@/redux/reducer/locationSlice";

const OfferSlider = dynamic(() => import("./OfferSlider"), {
  ssr: false,
  loading: OfferSliderSkeleton,
});

const Home = () => {

  const KmRange = useSelector(getKilometerRange);
  const cityData = useSelector(getCityData);
  const { adsense_enabled, adsense_mode } = useSelector(getAdsenseSettings);
  const isManualAds = adsense_enabled && adsense_mode === "manual";
  const langCode = useLangFromSearchParams();
  const [IsFeaturedLoading, setIsFeaturedLoading] = useState(false);
  const [featuredData, setFeaturedData] = useState([]);
  const [Slider, setSlider] = useState([]);
  const [IsSliderLoading, setIsSliderLoading] = useState(true);
  const allEmpty = featuredData?.every((ele) => ele?.section_data.length === 0);

  useEffect(() => {
    const fetchSliderData = async () => {
      let params = {};
      if (cityData?.city) {
        params.city = cityData.city;
        params.state = cityData.state;
        params.country = cityData.country;
      } else if (cityData?.state) {
        params.state = cityData.state;
      } else if (cityData?.country) {
        params.country = cityData.country;
      }
      try {
        const response = await sliderApi.getSlider(params);
        const data = response.data;
        setSlider(data.data);
      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsSliderLoading(false);
      }
    };
    fetchSliderData();
  }, [cityData?.city, cityData?.state, cityData?.country]);

  useEffect(() => {
    const fetchFeaturedSectionData = async () => {
      setIsFeaturedLoading(true);
      try {
        const params = {};
        if (Number(KmRange) > 0 && (cityData?.areaId || cityData?.city)) {
          params.radius = KmRange;
          params.latitude = cityData.lat;
          params.longitude = cityData.long;
        } else {
          if (cityData?.areaId) {
            params.area_id = cityData.areaId;
          } else if (cityData?.city) {
            params.city = cityData.city;
          } else if (cityData?.state) {
            params.state = cityData.state;
          } else if (cityData?.country) {
            params.country = cityData.country;
          }
        }
        const response = await FeaturedSectionApi.getFeaturedSections(params);
        const { data } = response.data;
        setFeaturedData(data);
      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsFeaturedLoading(false);
      }
    };
    fetchFeaturedSectionData();
  }, [
    cityData.lat, cityData.long, KmRange, langCode,
  ]);
  return (
    <>
      {IsSliderLoading ? (
        <OfferSliderSkeleton />
      ) : (
        Slider &&
        Slider.length > 0 && (
          <OfferSlider Slider={Slider} IsLoading={IsSliderLoading} />
        )
      )}
      <PopularCategories />

      <div className="container">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-3 sm:gap-6">
          <div className={!isManualAds ? "lg:col-span-12" : "lg:col-span-9"}>
            {IsFeaturedLoading ? (
              <FeaturedSectionsSkeleton />
            ) : (
              <FeaturedSections
                featuredData={featuredData}
                setFeaturedData={setFeaturedData}
                allEmpty={allEmpty}
              />
            )}
            <AllItems cityData={cityData} KmRange={KmRange} />
          </div>
          {isManualAds && (
            <div className="hidden lg:block lg:col-span-3 lg:mt-[104px]">
              <div className="flex flex-col justify-center gap-7">
                <AdVertical />
                <AdVertical />
              </div>
            </div>
          )}
        </div>
        <AdFooterBanner className="mt-12" />
      </div>
    </>
  );
};

export default Home;
