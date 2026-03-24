import { useEffect, useState } from "react";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
  CarouselNext,
  CarouselPrevious,
} from "@/components/ui/carousel";
import { allItemApi } from "@/utils/api";
import ProductCard from "@/components/Common/ProductCard";
import { useSelector } from "react-redux";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import { t } from "@/utils";
import { getCityData, getKilometerRange } from "@/redux/reducer/locationSlice";

const SimilarProducts = ({ productDetails }) => {
  const [similarData, setSimilarData] = useState([]);
  const isRTL = useSelector(getIsRtl);
  const location = useSelector(getCityData);
  const KmRange = useSelector(getKilometerRange);

  const fetchSimilarData = async (cateID) => {
    try {
      const response = await allItemApi.getItems({
        category_id: cateID,
        ...(location?.lat &&
          location?.long && {
          latitude: location?.lat,
          longitude: location?.long,
          radius: KmRange,
        }),
      });
      const responseData = response?.data;
      if (responseData) {
        const { data } = responseData;
        const filteredData = data?.data?.filter(
          (item) => item.id !== productDetails?.id
        );
        setSimilarData(filteredData || []);
      } else {
        console.error("Invalid response:", response);
      }
    } catch (error) {
      console.error("Error:", error);
    }
  };
  useEffect(() => {
    if (productDetails?.category_id) {
      fetchSimilarData(productDetails?.category_id);
    }
  }, [productDetails?.category_id]);

  if (similarData && similarData.length === 0) {
    return null;
  }

  const handleLikeAllData = (id) => {
    const updatedItems = similarData.map((item) => {
      if (item.id === id) {
        return { ...item, is_liked: !item.is_liked };
      }
      return item;
    });
    setSimilarData(updatedItems);
  };

  return (
    <div className="flex flex-col gap-5 mt-8">
      <h2 className="text-2xl font-medium">{t("relatedAds")}</h2>
      <Carousel
        key={isRTL ? "rtl" : "ltr"}
        opts={{
          direction: isRTL ? "rtl" : "ltr",
        }}
      >
        <CarouselContent>
          {similarData?.map((item) => (
            <CarouselItem
              key={item.id}
              className="md:basis-1/3 lg:basis-[25%] basis-2/3 sm:basis-1/2"
            >
              <ProductCard item={item} handleLike={handleLikeAllData} />
            </CarouselItem>
          ))}
        </CarouselContent>
        {similarData?.length > 3 && (
          <>
            <CarouselPrevious className="hidden md:flex absolute top-1/2 ltr:left-2 rtl:right-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full" />
            <CarouselNext className="hidden md:flex absolute top-1/2 ltr:right-2 rtl:left-2 rtl:scale-x-[-1] -translate-y-1/2 bg-primary text-white rounded-full" />
          </>
        )}
      </Carousel>
    </div>
  );
};

export default SimilarProducts;
