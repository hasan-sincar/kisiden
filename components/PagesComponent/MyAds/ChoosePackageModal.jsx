import CustomImage from "@/components/Common/CustomImage";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { formatPriceAbbreviated, t } from "@/utils";
import { getPackageApi } from "@/utils/api";
import { useSelector } from "react-redux";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import NoData from "@/components/EmptyStates/NoData";
import { cn } from "@/lib/utils";

const ChoosePackageModal = ({
  IsChoosePackage,
  setIsChoosePackage,
  selectedPackageId,
  setSelectedPackageId,
  ItemPackages,
  setItemPackages,
  isRenewingAd,
  handleRenew,
}) => {
  const [IsLoading, setIsLoading] = useState(false);
  const currentLanguageCode = useSelector(getCurrentLangCode);

  useEffect(() => {
    getItemsPackageData();
  }, [currentLanguageCode]);

  const getItemsPackageData = async () => {
    try {
      setIsLoading(true);
      const res = await getPackageApi.getPackage({ type: "item_listing" });
      const { data } = res?.data;
      setItemPackages(data || []);
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={IsChoosePackage} onOpenChange={setIsChoosePackage}>
      <DialogContent onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle className="text-xl font-semibold">
            {t("selectPackage")}
          </DialogTitle>
          <DialogDescription className="sr-only"></DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-3">
          {IsLoading ? (
            Array.from({ length: 3 }).map((_, index) => (
              <PackageCardSkeleton key={index} />
            ))
          ) : ItemPackages.length > 0 ? (
            ItemPackages.map((item) => (
              <div
                className={cn(
                  "flex items-center gap-3 p-3 border rounded-lg hover:bg-muted transition-colors cursor-pointer",
                  item?.id == selectedPackageId &&
                    "bg-primary text-white hover:bg-primary"
                )}
                key={item?.id}
                onClick={() => setSelectedPackageId(item?.id)}
              >
                <CustomImage
                  src={item.icon}
                  width={58}
                  height={58}
                  alt={"Dummy image"}
                  className="rounded"
                />
                <div className="flex flex-col gap-1 w-full">
                  <h3 className="text-lg font-medium ltr:text-left rtl:text-right line-clamp-2">
                    {item.translated_name}
                    {item?.is_active && t("activePlan")}
                  </h3>
                  <div className="flex items-center gap-3 justify-between w-full">
                    <span className="text-lg font-bold whitespace-nowrap">
                      {formatPriceAbbreviated(item.final_price)}
                    </span>
                    <span
                      className={cn(
                        "text-muted-foreground text-xs sm:text-sm ltr:text-right rtl:text-left",
                        item?.id == selectedPackageId && "text-white"
                      )}
                    >
                      <strong
                        className={cn(
                          item?.id == selectedPackageId
                            ? "text-white"
                            : "text-foreground"
                        )}
                      >
                        {item.item_limit === "unlimited"
                          ? t("unlimited")
                          : item.item_limit}
                      </strong>{" "}
                      {t("ads")} &nbsp;|&nbsp;&nbsp;
                      <strong
                        className={cn(
                          item?.id == selectedPackageId
                            ? "text-white"
                            : "text-foreground"
                        )}
                      >
                        {item.duration === "unlimited"
                          ? t("unlimited")
                          : item.duration}
                      </strong>{" "}
                      {t("days")}
                    </span>
                  </div>
                </div>
              </div>
            ))
          ) : (
            <NoData name="packages" />
          )}
        </div>

        {ItemPackages.length > 0 && (
          <DialogFooter>
            <DialogClose asChild>
              <Button className="bg-black text-white">{t("cancel")}</Button>
            </DialogClose>
            <Button
              className="bg-primary text-white"
              type="button"
              onClick={handleRenew}
              disabled={isRenewingAd}
            >
              {isRenewingAd ? t("loading") : t("renewAd")}
            </Button>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  );
};

export default ChoosePackageModal;

const PackageCardSkeleton = () => {
  return (
    <div className="flex items-center gap-3 p-3 border rounded-lg">
      {/* Image Skeleton */}
      <Skeleton className="h-[58px] w-[58px] rounded" />

      <div className="flex flex-col gap-2 w-full">
        {/* Title Skeleton */}
        <Skeleton className="h-5 w-3/4" />

        {/* Price + Meta Skeleton */}
        <div className="flex items-center justify-between w-full gap-3">
          <Skeleton className="h-5 w-16" />
          <Skeleton className="h-4 w-16" />
        </div>
      </div>
    </div>
  );
};
