"use client";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
} from "@/components/ui/carousel";
import { useEffect, useState } from "react";
import { RiArrowLeftLine, RiArrowRightLine } from "react-icons/ri";
import Autoplay from "embla-carousel-autoplay";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { useSelector } from "react-redux";
import CustomLink from "@/components/Common/CustomLink";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import CustomImage from "@/components/Common/CustomImage";

const OfferSlider = ({ Slider }) => {
  const [api, setApi] = useState();
  const [current, setCurrent] = useState(0);
  const userData = useSelector(userSignUpData);
  const isRTL = useSelector(getIsRtl);

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
    <section className="py-6 bg-muted">
      <div className="container">
        <Carousel
          key={isRTL ? "rtl" : "ltr"}
          className="w-full"
          setApi={setApi}
          opts={{
            align: "start",
            containScroll: "trim",
            direction: isRTL ? "rtl" : "ltr",
          }}
          plugins={[Autoplay({ delay: 3000 })]}
        >
          <CarouselContent className="-ml-3 md:-ml-[30px]">
            {Slider.map((ele, index) => {
              let href;
              if (ele?.model_type === "App\\Models\\Item") {
                if (userData && userData?.id === ele?.model?.user_id) {
                  href = `/my-listing/${ele?.model?.slug}`;
                } else {
                  href = `/ad-details/${ele?.model?.slug}`;
                }
              } else if (ele?.model_type === null) {
                href = ele?.third_party_link;
              } else if (ele?.model_type === "App\\Models\\Category") {
                href = `/ads?category=${ele.model.slug}`;
              } else {
                href = "/";
              }
              // First 2 images load with eager loading and priority for Lighthouse performance
              const isPriorityImage = index < 2;
              return (
                <CarouselItem
                  className="basis-full md:basis-2/3 pl-3 md:pl-[30px]"
                  key={ele?.id}
                >
                  <CustomLink
                    href={href}
                    target={ele?.model_type === null ? "_blank" : ""}
                  >
                    <CustomImage
                      src={ele.image}
                      alt="slider imag"
                      width={983}
                      height={493}
                      className="aspect-[983/493] w-full object-cover rounded-xl"
                      loading={isPriorityImage ? "eager" : "lazy"}
                      priority={isPriorityImage}
                    />
                  </CustomLink>
                </CarouselItem>
              );
            })}
          </CarouselContent>

          {Slider && Slider?.length > 1 && (
            <>
              <button
                onClick={() => api?.scrollTo(current - 1)}
                className={`sm:block absolute z-10 top-1/2 -translate-y-1/2 ltr:left-2 rtl:right-2 bg-primary p-1 md:p-2 rounded-full ${
                  !api?.canScrollPrev() ? "cursor-default" : ""
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
                className={`sm:block absolute z-10 top-1/2 -translate-y-1/2 ltr:right-2 rtl:left-2 bg-primary p-1 md:p-2 rounded-full ${
                  !api?.canScrollNext() ? "cursor-default" : ""
                }`}
                disabled={!api?.canScrollNext()}
              >
                <RiArrowRightLine
                  size={24}
                  color="white"
                  className={isRTL ? "rotate-180" : ""}
                />
              </button>
            </>
          )}
        </Carousel>
      </div>
    </section>
  );
};

export default OfferSlider;
