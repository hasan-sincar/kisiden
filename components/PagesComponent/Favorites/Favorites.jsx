"use client";
import ProductCard from "@/components/Common/ProductCard";
import NoData from "@/components/EmptyStates/NoData";
import ProductCardSkeleton from "@/components/Common/ProductCardSkeleton";
import { Button } from "@/components/ui/button";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import { t } from "@/utils";
import { getFavouriteApi } from "@/utils/api";
import { useEffect, useState } from "react";
import { useSelector } from "react-redux";

const Favorites = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [favoritesData, setFavoriteData] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [IsLoadMore, setIsLoadMore] = useState(false);

  const fetchFavoriteItems = async (page) => {
    try {
      if (page === 1) {
        setIsLoading(true);
      }
      const response = await getFavouriteApi.getFavouriteApi({ page });
      const data = response?.data?.data?.data;
      if (page === 1) {
        setFavoriteData(data);
      } else {
        setFavoriteData((prevData) => [...prevData, ...data]);
      }

      setCurrentPage(response?.data?.data.current_page);

      if (response?.data?.data.current_page < response?.data?.data.last_page) {
        setHasMore(true);
      } else {
        setHasMore(false);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
      setIsLoadMore(false);
    }
  };

  useEffect(() => {
    fetchFavoriteItems(currentPage);
  }, [currentPage, CurrentLanguage.id]);

  const handleLoadMore = () => {
    setIsLoadMore(true);
    setCurrentPage((prevPage) => prevPage + 1);
  };

  const handleLike = (id) => {
    fetchFavoriteItems(1);
  };

  return (
    <>
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 lg:grid-cols-2 gap-3 sm:gap-6">
        {isLoading ? (
          [...Array(12)].map((_, index) => <ProductCardSkeleton key={index} />)
        ) : favoritesData && favoritesData.length > 0 ? (
          favoritesData?.map(
            (fav) =>
              fav?.is_liked && (
                <ProductCard key={fav?.id} item={fav} handleLike={handleLike} />
              )
          )
        ) : (
          <div className="col-span-full">
            <NoData name={t("favorites")} />
          </div>
        )}
      </div>
      {favoritesData && favoritesData.length > 0 && hasMore && (
        <div className="text-center mt-6">
          <Button
            variant="outline"
            className="text-sm sm:text-base text-primary w-[256px]"
            disabled={isLoading || IsLoadMore}
            onClick={handleLoadMore}
          >
            {IsLoadMore ? t("loading") : t("loadMore")}
          </Button>
        </div>
      )}
    </>
  );
};

export default Favorites;
