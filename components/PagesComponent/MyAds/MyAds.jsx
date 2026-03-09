"use client";
import { t } from "@/utils";
import { CgArrowsExchangeAltV } from "react-icons/cg";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import AdsCard from "./MyAdsCard.jsx";
import { deleteItemApi, getMyItemsApi, renewItemApi } from "@/utils/api";
import { useSelector } from "react-redux";
import ProductCardSkeleton from "@/components/Common/ProductCardSkeleton.jsx";
import NoData from "@/components/EmptyStates/NoData";
import { Button } from "@/components/ui/button";
import {
  CurrentLanguageData,
  getIsRtl,
} from "@/redux/reducer/languageSlice.js";
import { Checkbox } from "@/components/ui/checkbox";
import ReusableAlertDialog from "@/components/Common/ReusableAlertDialog.jsx";
import { toast } from "sonner";
import ChoosePackageModal from "./ChoosePackageModal.jsx";
import { getIsFreAdListing } from "@/redux/reducer/settingSlice.js";

const MyAds = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const searchParams = useSearchParams();
  const isRTL = useSelector(getIsRtl);

  const sortValue = searchParams.get("sort") || "new-to-old";
  const status = searchParams.get("status") || "all";

  const [totalAdsCount, setTotalAdsCount] = useState(0);
  const [MyItems, setMyItems] = useState([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [lastPage, setLastPage] = useState(1);
  const [IsLoading, setIsLoading] = useState(true);
  const [IsLoadMore, setIsLoadMore] = useState(false);

  const isFreeAdListing = useSelector(getIsFreAdListing);
  const [ItemPackages, setItemPackages] = useState([]);
  const [renewIds, setRenewIds] = useState([]);

  const [selectedIds, setSelectedIds] = useState([]);
  const [IsDeleting, setIsDeleting] = useState(false);
  const [IsDeleteDialog, setIsDeleteDialog] = useState(false);

  const [IsChoosePackage, setIsChoosePackage] = useState(false);
  const [selectedPackageId, setSelectedPackageId] = useState("");
  const [isRenewingAd, setIsRenewingAd] = useState(false);

  // Filter expired ads and check if selection is allowed
  const expiredAds = MyItems.filter((item) => item.status === "expired");
  const canMultiSelect = expiredAds.length > 1;

  const getMyItemsData = async (page = 1) => {
    try {
      const params = {
        page,
        sort_by: sortValue,
      };
      if (status !== "all") {
        params.status = status;
      }

      // Set loading states based on page
      if (page > 1) {
        setIsLoadMore(true);
      } else {
        setIsLoading(true);
      }

      const res = await getMyItemsApi.getMyItems(params);
      const data = res?.data;
      if (data?.error === false) {
        setTotalAdsCount(data?.data?.total);
        page > 1
          ? setMyItems((prevData) => [...prevData, ...data?.data?.data])
          : setMyItems(data?.data?.data);
        setCurrentPage(data?.data?.current_page);
        setLastPage(data?.data?.last_page);
      } else {
        console.log("Error in response: ", data.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
      setIsLoadMore(false);
    }
  };

  useEffect(() => {
    getMyItemsData(1);
  }, [sortValue, status, CurrentLanguage?.id]);

  const updateURLParams = (key, value) => {
    const params = new URLSearchParams(searchParams);
    params.set(key, value);
    window.history.pushState(null, "", `?${params.toString()}`);
  };

  const handleSortChange = (value) => {
    updateURLParams("sort", value);
  };

  const handleStatusChange = (value) => {
    updateURLParams("status", value);
  };

  const handleAdSelection = (adId) => {
    const ad = MyItems.find((item) => item.id === adId);
    if (ad?.status !== "expired") return;

    setRenewIds((prev) => {
      if (prev.includes(adId)) {
        return prev.filter((id) => id !== adId);
      } else {
        return [...prev, adId];
      }
    });
  };

  const handleRemove = async () => {
    if (selectedIds.length === 0) return;
    try {
      setIsDeleting(true);
      const payload = { item_ids: selectedIds.join(",") };
      // Call API
      const res = await deleteItemApi.deleteItem(payload);

      // Handle response
      if (res?.data?.error === false) {
        toast.success(res?.data?.message);
        setIsDeleteDialog(false);
        setSelectedIds([]);
        setRenewIds([]);
        await getMyItemsData(1);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsDeleting(false);
    }
  };

  const renewAds = async ({ ids, packageId }) => {
    try {
      setIsRenewingAd(true);
      let payload = {};
      if (Array.isArray(ids)) {
        payload = {
          item_ids: ids.join(","),
          ...(isFreeAdListing ? {} : { package_id: packageId }),
        };
      } else {
        payload = {
          item_ids: ids,
          ...(isFreeAdListing ? {} : { package_id: packageId }),
        };
      }

      const res = await renewItemApi.renewItem(payload);

      if (res?.data?.error === false) {
        toast.success(res?.data?.message);
        setIsChoosePackage(false);
        setRenewIds([]);
        await getMyItemsData(1);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsRenewingAd(false);
    }
  };

  const handleRenew = (ids) => {
    const idsToRenew = Array.isArray(ids) ? ids : renewIds;

    if (isFreeAdListing) {
      renewAds({ ids: idsToRenew });
    } else {
      if (!selectedPackageId) {
        toast.error(t("pleaseSelectPackage"));
        return;
      }

      const subPackage = ItemPackages.find(
        (p) => Number(p.id) === Number(selectedPackageId)
      );
      if (!subPackage?.is_active) {
        toast.error(t("purchasePackageFirst"));
        navigate("/user-subscription");
        return;
      }
      renewAds({ ids: idsToRenew, packageId: selectedPackageId });
    }
  };

  // Handle context menu actions
  const handleContextMenuAction = (action, adId) => {
    const ad = MyItems.find((item) => item.id === adId);

    switch (action) {
      case "select":
        // Only allow selection for expired ads
        if (ad && ad.status === "expired") {
          handleAdSelection(adId);
        }
        break;
      case "renew":
        if (isFreeAdListing) {
          handleRenew([adId]);
        } else {
          setRenewIds([adId]);
          setIsChoosePackage(true);
        }
        break;
      case "delete":
        setSelectedIds([adId]); // single ad
        setIsDeleteDialog(true);
        break;
      default:
        break;
    }
  };

  const handleSelectAll = () => {
    if (renewIds.length === expiredAds.length) {
      setRenewIds([]);
    } else {
      setRenewIds(expiredAds.map((item) => item.id));
    }
  };

  const handleCancelSelection = () => setRenewIds([]);

  return (
    <>
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between py-2 px-4 bg-muted rounded-lg">
        <h1 className="font-semibold">
          {t("totalAds")} {totalAdsCount}
        </h1>

        <div className="flex flex-wrap sm:flex-nowrap items-center gap-2">
          <div className="flex items-center gap-1">
            <CgArrowsExchangeAltV size={25} />
            <span className="whitespace-nowrap">{t("sortBy")}</span>
          </div>
          <Select value={sortValue} onValueChange={handleSortChange}>
            <SelectTrigger className="bg-transparent border-black/23 whitespace-nowrap">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent align={isRTL ? "start" : "end"}>
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

          <Select value={status} onValueChange={handleStatusChange}>
            <SelectTrigger className="bg-transparent border-black/23">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent align={isRTL ? "start" : "end"}>
              <SelectGroup>
                <SelectItem value="all">{t("all")}</SelectItem>
                <SelectItem value="review">{t("review")}</SelectItem>
                <SelectItem value="approved">{t("live")}</SelectItem>
                <SelectItem value="soft rejected">
                  {t("softRejected")}
                </SelectItem>
                <SelectItem value="permanent rejected">
                  {t("permanentRejected")}
                </SelectItem>
                <SelectItem value="inactive">{t("deactivate")}</SelectItem>
                <SelectItem value="featured">{t("featured")}</SelectItem>
                <SelectItem value="sold out">{t("soldOut")}</SelectItem>
                <SelectItem value="resubmitted">{t("resubmitted")}</SelectItem>
                <SelectItem value="expired">{t("expired")}</SelectItem>
              </SelectGroup>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="mt-[30px] text-sm text-destructive">
        <span>{t("expiredAdsNote")}</span>
      </div>

      {/* Selection controls - only show when there are expired ads and at least one is selected */}
      {canMultiSelect && renewIds.length > 0 && (
        <div className="flex items-center justify-between mt-[30px]">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2">
              <Checkbox
                checked={renewIds.length === expiredAds.length}
                onCheckedChange={handleSelectAll}
                className="data-[state=checked]:bg-primary data-[state=checked]:border-primary"
              />
              <span className="text-sm font-medium">{t("selectAll")}</span>
            </div>
          </div>
          <p className="text-sm">
            {renewIds.length} {renewIds.length === 1 ? t("ad") : t("ads")}{" "}
            {t("selected")}
          </p>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 mt-[30px] xl:grid-cols-3 gap-3 sm:gap-6">
        {IsLoading ? (
          [...Array(6)].map((item, index) => (
            <ProductCardSkeleton key={index} />
          ))
        ) : MyItems && MyItems?.length > 0 ? (
          MyItems.map((item) => (
            <AdsCard
              key={item?.id}
              data={item}
              isApprovedSort={sortValue === "approved"}
              isSelected={renewIds.includes(item?.id)}
              isSelectable={renewIds.length > 0 && item.status === "expired"}
              onSelectionToggle={() => handleAdSelection(item?.id)}
              onContextMenuAction={(action) =>
                handleContextMenuAction(action, item?.id)
              }
            />
          ))
        ) : (
          <div className="col-span-full">
            <NoData name={t("advertisement")} />
          </div>
        )}
      </div>
      {currentPage < lastPage && (
        <div className="text-center mt-6">
          <Button
            variant="outline"
            className="text-sm sm:text-base text-primary w-[256px]"
            disabled={IsLoading || IsLoadMore}
            onClick={() => getMyItemsData(currentPage + 1)}
          >
            {IsLoadMore ? t("loading") : t("loadMore")}
          </Button>
        </div>
      )}

      {/* Action buttons for selected ads - show at bottom */}
      {renewIds.length > 0 && (
        <div className="mt-[30px]">
          <div className="flex items-center justify-end gap-3">
            <Button
              onClick={handleCancelSelection}
              className="bg-black text-white"
            >
              {t("cancel")}
            </Button>
            <Button
              onClick={() => {
                if (renewIds.length === 0) return; // no selection
                setSelectedIds([...renewIds]); // copy renewIds to selectedIds
                setIsDeleteDialog(true);
              }}
              className="bg-destructive text-white"
            >
              {t("remove")}
            </Button>
            <Button
              onClick={() => {
                if (isFreeAdListing) {
                  handleRenew(); // directly renew
                } else {
                  setIsChoosePackage(true);
                }
              }}
              disabled={isRenewingAd}
              className="bg-primary text-white"
            >
              {isRenewingAd ? t("loading") : t("renew")}
            </Button>
          </div>
        </div>
      )}

      <ChoosePackageModal
        key={IsChoosePackage}
        selectedPackageId={selectedPackageId}
        setSelectedPackageId={setSelectedPackageId}
        ItemPackages={ItemPackages}
        setItemPackages={setItemPackages}
        IsChoosePackage={IsChoosePackage}
        setIsChoosePackage={setIsChoosePackage}
        handleRenew={handleRenew}
        isRenewingAd={isRenewingAd}
      />
      <ReusableAlertDialog
        open={IsDeleteDialog}
        onCancel={() => setIsDeleteDialog(false)}
        onConfirm={handleRemove}
        title={t("areYouSure")}
        description={
          selectedIds.length === 1
            ? t("areYouSureToDeleteAd")
            : t("areYouSureToDeleteAds")
        }
        cancelText={t("cancel")}
        confirmText={t("yes")}
        confirmDisabled={IsDeleting}
      />
    </>
  );
};

export default MyAds;
