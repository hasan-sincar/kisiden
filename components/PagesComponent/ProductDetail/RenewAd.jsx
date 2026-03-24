import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams";
import { useNavigate } from "@/components/Common/useNavigate";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getIsFreAdListing } from "@/redux/reducer/settingSlice";
import { t } from "@/utils";
import { getPackageApi, renewItemApi } from "@/utils/api";
import { useEffect, useState } from "react";
import { useSelector } from "react-redux";
import { toast } from "sonner";

const RenewAd = ({
  setProductDetails,
  item_id,
  setStatus,
  categoryId,
  categoryName
}) => {
  const { navigate } = useNavigate();
  const [RenewId, setRenewId] = useState("");
  const [ItemPackages, setItemPackages] = useState([]);
  const [isRenewingAd, setIsRenewingAd] = useState(false);

  const isFreeAdListing = useSelector(getIsFreAdListing);
  const langCode = useLangFromSearchParams()

  const isActivePackageAvailable = ItemPackages.length > 0;
  const globalPackages = ItemPackages.filter((item) => item?.is_global == 1);
  const categoryPackages = ItemPackages.filter((item) => item?.is_global != 1);


  useEffect(() => {
    if (!isFreeAdListing) {
      getItemsPackageData();
    }
  }, [langCode]);

  const getItemsPackageData = async () => {
    try {
      // This API returns only active packages for the selected category and global packages.
      const res = await getPackageApi.getPackage({ type: "item_listing", category_id: categoryId, is_subscribed: 1 });
      const { data } = res.data;
      setItemPackages(data);
    } catch (error) {
      console.log(error);
    }
  };

  const handleRenewItem = async () => {
    if (!isFreeAdListing && !RenewId) {
      toast.error(t("selectRenewalPackageError"));
      return;
    }
    try {
      setIsRenewingAd(true);
      const res = await renewItemApi.renewItem({
        item_ids: item_id,
        ...(isFreeAdListing ? {} : { package_id: RenewId }),
      });
      if (res?.data?.error === false) {
        setProductDetails((prev) => ({
          ...prev,
          status: res?.data?.data?.status,
        }));
        setStatus(res?.data?.data?.status);
        toast.success(res?.data?.message);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsRenewingAd(false);
    }
  };

  return (
    <div className="flex flex-col border rounded-md ">
      <div className="p-4 border-b font-semibold">{t("renewAd")}</div>
      <div className="p-4 flex flex-col gap-4 ">


        {
          !isFreeAdListing && (
            isActivePackageAvailable ?
              <Select
                className="outline-none"
                value={RenewId}
                onValueChange={(value) => setRenewId(value)}
              >
                <SelectTrigger className="outline-none">
                  <SelectValue placeholder={t("selectRenewalPackage")} />
                </SelectTrigger>
                <SelectContent className="w-[--radix-select-trigger-width]">
                  {/* Global Packages */}
                  {globalPackages.length > 0 && (
                    <SelectGroup>
                      <SelectLabel>{t("globalPackages")}</SelectLabel>
                      {globalPackages.map((item) => (
                        <SelectItem value={item?.id} key={item?.id}>
                          {item?.translated_name} - {item.listing_duration_days} {t("days")}
                        </SelectItem>
                      ))}
                    </SelectGroup>
                  )}
                  {/* Category Packages */}
                  {categoryPackages.length > 0 && (
                    <SelectGroup>
                      <SelectLabel>{t("categoryPackages")}</SelectLabel>
                      {categoryPackages.map((item) => (
                        <SelectItem value={item?.id} key={item?.id}>
                          {item?.translated_name} - {item.listing_duration_days} {t("days")}
                        </SelectItem>
                      ))}
                    </SelectGroup>
                  )}
                </SelectContent>
              </Select>
              :
              <div className="flex flex-col gap-2">
                <h6 className="text-sm font-medium text-destructive">{t('subscriptionRequired')}</h6>
                <p className="text-sm text-muted-foreground">{t('renewAdPackageRequiredPrefix')} {categoryName} {t('renewAdPackageRequiredSuffix')}</p>
              </div>
          )
        }
        <button
          className="bg-primary text-white font-medium w-full p-2 rounded-md disabled:opacity-80"
          onClick={(isFreeAdListing || isActivePackageAvailable) ? handleRenewItem : () => navigate(`/subscription?plan=listing&langCode=${langCode}&category_id=${categoryId}`)}
          disabled={isRenewingAd}
        >
          {(isFreeAdListing || isActivePackageAvailable) ? t("renew") : t('purchase')}
        </button>
      </div>
    </div>
  );
};

export default RenewAd;
