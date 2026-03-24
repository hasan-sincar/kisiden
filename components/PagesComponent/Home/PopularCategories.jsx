"use client";
import { useEffect, useState } from "react";
import { RiArrowLeftLine, RiArrowRightLine } from "react-icons/ri";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
} from "@/components/ui/carousel";
import PopularCategoriesSkeleton from "./PopularCategoriesSkeleton.jsx";
import PopularCategoryCard from "@/components/PagesComponent/Home/PopularCategoryCard";
import { useSelector } from "react-redux";
import { t } from "@/utils";
import { getIsRtl } from "@/redux/reducer/languageSlice.js";
import { Loader2 } from "lucide-react";
import { featuredCategoriesApi } from "@/utils/api.js";
import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams.jsx";
const PopularCategories = () => {

  const isRTL = useSelector(getIsRtl);
  const langCode = useLangFromSearchParams();
  const [cateData, setCateData] = useState([]);
  const [isCatLoading, setIsCatLoading] = useState(true);
  const [isCatLoadMore, setIsCatLoadMore] = useState(false);
  const [catCurrentPage, setCatCurrentPage] = useState(1);
  const [catLastPage, setCatLastPage] = useState(1);

  const [api, setApi] = useState();
  const [current, setCurrent] = useState(0);

  const isNextDisabled =
    isCatLoadMore ||
    ((!api || !api.canScrollNext()) && catCurrentPage >= catLastPage);

  useEffect(() => {
    getCategories(1);
  }, [langCode]);

  useEffect(() => {
    if (!api) {
      return;
    }
    setCurrent(api.selectedScrollSnap());
    api.on("select", () => {
      setCurrent(api.selectedScrollSnap());
    });
  }, [api, cateData.length]);

  const getCategories = async (page = 1) => {
    if (page === 1) {
      setIsCatLoading(true);
    } else {
      setIsCatLoadMore(true);
    }
    try {
      const res = await featuredCategoriesApi.getFeaturedCategories({
        page,
      });
      if (res?.data?.error === false) {
        const data = res.data.data;
        setCateData((prev) =>
          page === 1 ? data.data : [...prev, ...data.data]
        );
        setCatCurrentPage(data.current_page);
        setCatLastPage(data.last_page);
      }
    } catch (error) {
      console.error("Featured categories error:", error);
    } finally {
      setIsCatLoading(false);
      setIsCatLoadMore(false);
    }
  };

  const handleNext = async () => {
    if (api && api.canScrollNext()) {
      api.scrollTo(current + 1);
    } else if (catCurrentPage < catLastPage) {
      await getCategories(catCurrentPage + 1);
      setTimeout(() => {
        api.scrollTo(current + 1);
      }, 200);
    }
  };

  return isCatLoading ? (
    <PopularCategoriesSkeleton />
  ) : (
    cateData && cateData.length > 0 && (
      <section className="container mt-12">
        <div className="space-between">
          <h5 className="text-xl sm:text-2xl font-medium">
            {t("popularCategories")}
          </h5>
          <div className="flex items-center justify-center gap-2 sm:gap-4">
            <button
              onClick={() => api && api.scrollTo(current - 1)}
              className={`bg-primary p-1 sm:p-2 rounded-full ${!api?.canScrollPrev() ? "opacity-65 cursor-default" : ""
                }`}
              disabled={!api?.canScrollPrev()}
            >
              <RiArrowLeftLine
                size={24}
                color="white"
                className={isRTL ? "rotate-180" : ""}
              />
            </button>
            <button
              onClick={handleNext}
              className={`bg-primary p-1 sm:p-2 rounded-full ${isNextDisabled ? "opacity-65 cursor-default" : ""
                }`}
              disabled={isNextDisabled}
            >
              {isCatLoadMore ? (
                <Loader2 size={24} className="animate-spin" />
              ) : (
                <RiArrowRightLine
                  size={24}
                  color="white"
                  className={isRTL ? "rotate-180" : ""}
                />
              )}
            </button>
          </div>
        </div>
        <Carousel
          key={isRTL ? "rtl" : "ltr"}
          className="w-full mt-6"
          setApi={setApi}
          opts={{
            align: "start",
            containScroll: "trim",
            direction: isRTL ? "rtl" : "ltr",
          }}
        >
          <CarouselContent className="-ml-3 md:-ml-[30px]">
            {cateData.map((item) => (
              <CarouselItem
                key={item?.id}
                className="basis-1/3 sm:basis-1/4 md:basis-1/5 lg:basis-[16.66%] xl:basis-[12.5%] 2xl:basis-[11.11%] md:pl-[30px]"
              >
                <PopularCategoryCard item={item} />
              </CarouselItem>
            ))}
          </CarouselContent>
        </Carousel>
      </section>
    )
  );
};

export default PopularCategories;
