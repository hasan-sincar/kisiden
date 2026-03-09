import { useEffect, useState } from "react";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { TbTransferVertical } from "react-icons/tb";
import { IoGrid } from "react-icons/io5";
import { allItemApi } from "@/utils/api";
import ProductHorizontalCardSkeleton from "@/components/Common/ProductHorizontalCardSkeleton";
import ProductCardSkeleton from "@/components/Common/ProductCardSkeleton";
import ProductCard from "@/components/Common/ProductCard";
import NoData from "@/components/EmptyStates/NoData";
import ProductHorizontalCard from "@/components/Common/ProductHorizontalCard";
import { useSearchParams } from "next/navigation";
import { MdViewStream } from "react-icons/md";
import { Button } from "@/components/ui/button";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import { useSelector } from "react-redux";
import { t } from "@/utils";

const SellerLsitings = ({ id }) => {
  const searchParams = useSearchParams();
  const view = searchParams.get("view") || "grid";
  const sortBy = searchParams.get("sort") || "new-to-old";
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [isSellerItemsLoading, setIsSellerItemsLoading] = useState(false);
  const [sellerItems, setSellerItems] = useState([]);
  const [isSellerItemLoadMore, setIsSellerItemLoadMore] = useState(false);
  const [CurrentPage, setCurrentPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  useEffect(() => {
    getSellerItems(1);
  }, [sortBy, CurrentLanguage.id]);

  const getSellerItems = async (page) => {
    try {
      if (page === 1) {
        setIsSellerItemsLoading(true);
      }
      const res = await allItemApi.getItems({
        user_id: id,
        sort_by: sortBy,
        page,
      });

      if (page > 1) {
        // Append new data to existing sellerItems
        setSellerItems((prevItems) => [...prevItems, ...res?.data?.data?.data]);
      } else {
        // Set new data if CurrentPage is 1 or initial load
        setSellerItems(res?.data?.data?.data);
      }

      setCurrentPage(res?.data?.data?.current_page);
      if (res?.data?.data.current_page === res?.data?.data.last_page) {
        setHasMore(false); // Check if there's more data
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsSellerItemsLoading(false);
      setIsSellerItemLoadMore(false);
    }
  };

  const handleLike = (id) => {
    const updatedItems = sellerItems.map((item) => {
      if (item.id === id) {
        return { ...item, is_liked: !item.is_liked };
      }
      return item;
    });
    setSellerItems(updatedItems);
  };

  const handleProdLoadMore = () => {
    setIsSellerItemLoadMore(true);
    getSellerItems(CurrentPage + 1);
  };

  const toggleView = (newView) => {
    const params = new URLSearchParams(searchParams);
    params.set("view", newView);
    window.history.pushState(null, "", `?${params.toString()}`);
  };

  const handleSortBy = (value) => {
    const params = new URLSearchParams(searchParams);
    params.set("sort", value);
    window.history.pushState(null, "", `?${params.toString()}`);
  };

  return (
    <>
      <div className="flex items-center justify-between">
        <div className="flex flex-col sm:flex-row sm:items-center gap-2">
          <div className="flex items-center gap-1">
            <TbTransferVertical />
            <span className="whitespace-nowrap">{t("sortBy")}</span>
          </div>
          <Select value={sortBy} onValueChange={handleSortBy}>
            <SelectTrigger>
              <SelectValue placeholder={t("sortBy")} />
            </SelectTrigger>
            <SelectContent>
              <SelectGroup>
                <SelectItem value="new-to-old">
                  {t("newestToOldest")}
                </SelectItem>
                <SelectItem value="old-to-new">
                  {t("oldestToNewest")}
                </SelectItem>
                <SelectItem value="price-high-to-low">
                  {t("priceHighToLow")}
                </SelectItem>
                <SelectItem value="price-low-to-high">
                  {t("priceLowToHigh")}
                </SelectItem>
                <SelectItem value="popular_items">{t("popular")}</SelectItem>
              </SelectGroup>
            </SelectContent>
          </Select>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => toggleView("grid")}
            className={`flex items-center justify-center size-8 sm:size-10 text-muted-foreground transition-colors duration-300 cursor-pointer gap-2 rounded-full ${
              view === "grid"
                ? "bg-primary text-white"
                : "hover:bg-black/15 hover:text-black"
            }`}
          >
            <IoGrid className="size-5 sm:size-6" />
          </button>
          <button
            onClick={() => toggleView("list")}
            className={`flex items-center justify-center size-8 sm:size-10 text-muted-foreground hover:text-black transition-colors duration-300 cursor-pointer gap-2 rounded-full ${
              view === "list"
                ? "bg-primary text-white"
                : "hover:text-black hover:bg-black/15"
            }`}
          >
            <MdViewStream className="size-5 sm:size-6" />
          </button>
        </div>
      </div>
      <div className="grid grid-cols-12 gap-4">
        {isSellerItemsLoading ? (
          Array.from({ length: 12 }).map((_, index) =>
            view === "list" ? (
              <div className="col-span-12" key={index}>
                <ProductHorizontalCardSkeleton />
              </div>
            ) : (
              <div key={index} className="col-span-6 lg:col-span-4">
                <ProductCardSkeleton />
              </div>
            )
          )
        ) : sellerItems && sellerItems.length > 0 ? (
          sellerItems?.map((item, index) =>
            view === "list" ? (
              <div className="col-span-12" key={index}>
                <ProductHorizontalCard item={item} handleLike={handleLike} />
              </div>
            ) : (
              <div className="col-span-6 lg:col-span-4" key={index}>
                <ProductCard item={item} handleLike={handleLike} />
              </div>
            )
          )
        ) : (
          <div className="col-span-12">
            <NoData name={t("ads")} />
          </div>
        )}
      </div>

      {sellerItems && sellerItems.length > 0 && hasMore && (
        <div className="text-center mt-6">
          <Button
            variant="outline"
            className="text-sm sm:text-base text-primary w-[256px]"
            disabled={isSellerItemsLoading || isSellerItemLoadMore}
            onClick={handleProdLoadMore}
          >
            {isSellerItemLoadMore ? t("loading") : t("loadMore")}
          </Button>
        </div>
      )}
    </>
  );
};

export default SellerLsitings;
