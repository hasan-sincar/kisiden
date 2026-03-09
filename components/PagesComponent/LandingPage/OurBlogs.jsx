"use client";
import { t } from "@/utils";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
} from "@/components/ui/carousel";
import { useEffect, useState } from "react";
import { RiArrowLeftLine, RiArrowRightLine } from "react-icons/ri";
import { getBlogsApi } from "@/utils/api";
import BlogCardSkeleton from "../../Skeletons/BlogCardSkeleton.jsx";
import BlogCard from "./BlogCard.jsx";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice.js";
import { useSelector } from "react-redux";

const OurBlogs = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const isRTL = CurrentLanguage?.rtl;
  const [api, setApi] = useState();
  const [current, setCurrent] = useState(0);
  const [Blogs, setBlogs] = useState([]);
  const [IsLoading, setIsLoading] = useState(true);

  const getBlogsData = async () => {
    try {
      const res = await getBlogsApi.getBlogs();
      setBlogs(res?.data?.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    getBlogsData();
  }, [CurrentLanguage.id]);

  useEffect(() => {
    if (!api) {
      return;
    }
    setCurrent(api.selectedScrollSnap());
    api.on("select", () => {
      setCurrent(api.selectedScrollSnap());
    });
  }, [api]);

  return (
    <section className="py-28 bg-muted" id="ourBlogs">
      <div className="container">
        <div className="flex items-center flex-col gap-6">
          <p className="outlinedSecHead">{t("ourBlog")}</p>
          <h1 className="landingSecHeader">
            {t("masteringMarketplace")}
            <br />
            {t("withOurBlog")}
          </h1>
        </div>
        <Carousel
          key={isRTL ? "rtl" : "ltr"}
          className="w-full mt-20"
          setApi={setApi}
          opts={{ align: "start", direction: isRTL ? "rtl" : "ltr" }}
        >
          <CarouselContent className="-ml-3 md:-ml-[30px]">
            {IsLoading
              ? Array.from({ length: 6 }).map((_, i) => (
                  <CarouselItem
                    key={i}
                    className="sm:basis-1/2 xl:basis-1/3 pl-3 md:pl-[30px]"
                  >
                    <BlogCardSkeleton />
                  </CarouselItem>
                ))
              : Blogs &&
                Blogs.length > 0 &&
                Blogs.map((blog) => (
                  <CarouselItem
                    key={blog?.id}
                    className="sm:basis-1/2 xl:basis-1/3 pl-3 md:pl-[30px]"
                  >
                    <BlogCard blog={blog} />
                  </CarouselItem>
                ))}
          </CarouselContent>
        </Carousel>

        <div className="flex items-center justify-center mt-[30px] gap-4">
          <button
            onClick={() => api?.scrollTo(current - 1)}
            className={`bg-primary p-2 rounded ${
              !api?.canScrollPrev() ? "opacity-65 cursor-default" : ""
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
            onClick={() => api?.scrollTo(current + 1)}
            className={`bg-primary p-2 rounded ${
              !api?.canScrollNext() ? "opacity-65 cursor-default" : ""
            }`}
            disabled={!api?.canScrollNext()}
          >
            <RiArrowRightLine
              size={24}
              color="white"
              className={isRTL ? "rotate-180" : ""}
            />
          </button>
        </div>
      </div>
    </section>
  );
};

export default OurBlogs;
