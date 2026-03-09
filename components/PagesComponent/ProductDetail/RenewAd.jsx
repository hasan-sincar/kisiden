import { useNavigate } from "@/components/Common/useNavigate";
import {
  Select,
  SelectContent,
  SelectItem,
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
  currentLanguageId,
  setProductDetails,
  item_id,
  setStatus,
}) => {
  const { navigate } = useNavigate();
  const [RenewId, setRenewId] = useState("");
  const [ItemPackages, setItemPackages] = useState([]);
  const [isRenewingAd, setIsRenewingAd] = useState(false);

  const isFreeAdListing = useSelector(getIsFreAdListing);

  useEffect(() => {
    getItemsPackageData();
  }, [currentLanguageId]);

  const getItemsPackageData = async () => {
    try {
      const res = await getPackageApi.getPackage({ type: "item_listing" });
      const { data } = res.data;
      setItemPackages(data);
      setRenewId(data[0]?.id);
    } catch (error) {
      console.log(error);
    }
  };

  const handleRenewItem = async () => {
    try {
      const subPackage = ItemPackages.find(
        (p) => Number(p.id) === Number(RenewId)
      );
      if (!isFreeAdListing && !subPackage?.is_active) {
        toast.error(t("purchasePackageFirst"));
        navigate("/user-subscription");
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
            expiry_date: res?.data?.data?.expiry_date,
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
    } catch (error) {
      console.log(error);
    }
  };

  return (
    <div className="flex flex-col border rounded-md ">
      <div className="p-4 border-b font-semibold">{t("renewAd")}</div>
      <div className="p-4 flex flex-col gap-4 ">
        <Select
          className="outline-none "
          value={RenewId}
          onValueChange={(value) => setRenewId(value)}
        >
          <SelectTrigger className="outline-none">
            <SelectValue placeholder={t("renewAd")} />
          </SelectTrigger>
          <SelectContent className="w-[--radix-select-trigger-width]">
            {ItemPackages.map((item) => (
              <SelectItem value={item?.id} key={item?.id}>
                {item?.translated_name} - {item.duration} {t("days")}{" "}
                {item?.is_active && t("activePlan")}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <button
          className="bg-primary text-white font-medium w-full p-2 rounded-md disabled:opacity-80"
          onClick={handleRenewItem}
          disabled={isRenewingAd}
        >
          {t("renew")}
        </button>
      </div>
    </div>
  );
};

export default RenewAd;
