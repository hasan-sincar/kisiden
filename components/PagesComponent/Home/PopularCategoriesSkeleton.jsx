import { Carousel, CarouselContent, CarouselItem } from "../../ui/carousel";
import { Skeleton } from "../../ui/skeleton";

const PopularCategoriesSkeleton = () => {
  return (
    <>
      <div className="container mt-12">
        <div className="space-between">
          <Skeleton className="w-1/4 h-4" />
          <Skeleton className="w-1/12 h-4" />
        </div>
        <Carousel
          className="w-full mt-6"
          opts={{
            align: "start",
            containScroll: "trim",
          }}
        >
          <CarouselContent className="-ml-3 md:-ml-[30px]">
            {Array.from({ length: 9 }).map((_, index) => (
              <CarouselItem
                key={index}
                className="basis-1/3 sm:basis-1/4 md:basis-1/5 lg:basis-[16.66%] xl:basis-[12.5%] 2xl:basis-[11.11%] md:pl-[30px]"
              >
                <div className="flex flex-col gap-4">
                  <Skeleton className="w-full aspect-square rounded-full" />
                  <Skeleton className="w-full h-4" />
                </div>
              </CarouselItem>
            ))}
          </CarouselContent>
        </Carousel>
      </div>
    </>
  );
};

export default PopularCategoriesSkeleton;
