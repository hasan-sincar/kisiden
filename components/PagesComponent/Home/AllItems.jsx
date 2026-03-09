import ProductCard from "@/components/Common/ProductCard";
import NoData from "@/components/EmptyStates/NoData";
import AllItemsSkeleton from "@/components/PagesComponent/Home/AllItemsSkeleton";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { resetBreadcrumb } from "@/redux/reducer/breadCrumbSlice";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import { t } from "@/utils";
import { allItemApi } from "@/utils/api";
import { Info, X } from "lucide-react";
import { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
const AllItems = ({ cityData, KmRange }) => {
  const dispatch = useDispatch();
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [AllItem, setAllItem] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadMore, setIsLoadMore] = useState(false);

  // State to track if we should show location alert
  const [locationAlertMessage, setLocationAlertMessage] = useState("");

  const getAllItemData = async (page) => {
    if (page === 1) {
      setIsLoading(true);
    }
    try {
      const params = {
        page,
        current_page: "home",
      };
      if (Number(KmRange) > 0 && (cityData?.areaId || cityData?.city)) {
        // Add location-based parameters for non-demo mode
        params.radius = KmRange;
        params.latitude = cityData.lat;
        params.longitude = cityData.long;
      } else {
        // Add location hierarchy parameters for non-demo mode
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

      const response = await allItemApi.getItems(params);
      if (response.data?.error === true) {
        throw new Error(response.data?.message);
      }

      const apiMessage = response.data.message;
      // Check if message indicates no items in selected location
      const isNoItemsInLocation = apiMessage
        ?.toLowerCase()
        .includes("no ads found");

      // Show alert only if there are items but from different location
      if (isNoItemsInLocation && response?.data?.data?.data?.length > 0) {
        setLocationAlertMessage(apiMessage);
      } else {
        setLocationAlertMessage("");
      }

      if (response?.data?.data?.data?.length > 0) {
        const data = response?.data?.data?.data;
        if (page === 1) {
          setAllItem(data);
        } else {
          setAllItem((prevData) => [...prevData, ...data]);
        }
        const currentPage = response?.data?.data?.current_page;
        const lastPage = response?.data?.data?.last_page;
        setHasMore(currentPage < lastPage);
        setCurrentPage(currentPage);
      } else {
        setAllItem([]);
      }
    } catch (error) {
      console.error("Error:", error);
    } finally {
      setIsLoading(false);
      setIsLoadMore(false);
    }
  };

  useEffect(() => {
    getAllItemData(1);
  }, [cityData.lat, cityData.long, KmRange, CurrentLanguage?.id]);

  const handleLoadMore = () => {
    setIsLoadMore(true);
    getAllItemData(currentPage + 1);
  };

  useEffect(() => {
    // reset breadcrumb path when in home page
    dispatch(resetBreadcrumb());
  }, []);

  const handleLikeAllData = (id) => {
    const updatedItems = AllItem.map((item) => {
      if (item.id === id) {
        return { ...item, is_liked: !item.is_liked };
      }
      return item;
    });
    setAllItem(updatedItems);
  };

  return (
    <section className="container mt-12">
      <h5 className="text-xl sm:text-2xl font-medium">
        {t("allAdvertisements")}
      </h5>

      {/* Location Alert - shows when items are from different location */}
      {locationAlertMessage && AllItem.length > 0 && (
        <Alert variant="warning" className="mt-3">
          <Info className="size-4" />
          <AlertTitle>{locationAlertMessage}</AlertTitle>
          <AlertDescription className="sr-only"></AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-6 mt-6">
        {isLoading ? (
          <AllItemsSkeleton />
        ) : AllItem && AllItem.length > 0 ? (
          AllItem?.map((item) => (
            <ProductCard
              key={item?.id}
              item={item}
              handleLike={handleLikeAllData}
            />
          ))
        ) : (
          <div className="col-span-full">
            <NoData name={t("advertisement")} />
          </div>
        )}
      </div>

      {AllItem && AllItem.length > 0 && hasMore && (
        <div className="text-center mt-6">
          <Button
            variant="outline"
            className="text-sm sm:text-base text-primary w-[256px]"
            disabled={isLoading || isLoadMore}
            onClick={handleLoadMore}
          >
            {isLoadMore ? t("loading") : t("loadMore")}
          </Button>
        </div>
      )}
    </section>
  );
};

export default AllItems;
