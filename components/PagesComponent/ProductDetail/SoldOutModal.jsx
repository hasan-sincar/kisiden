import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { t } from "@/utils";
import { getItemBuyerListApi } from "@/utils/api";
import NoDataFound from "../../../public/assets/no_data_found_illustrator.svg";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { Checkbox } from "@/components/ui/checkbox";
import { Skeleton } from "@/components/ui/skeleton";
import CustomImage from "@/components/Common/CustomImage";

const SoldOutModal = ({
  productDetails,
  showSoldOut,
  setShowSoldOut,
  selectedRadioValue,
  setSelectedRadioValue,
  setShowConfirmModal,
}) => {
  const [buyers, setBuyers] = useState([]);
  const [isNoneOfAboveChecked, setIsNoneOfAboveChecked] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const isJobAd = productDetails?.category?.is_job_category === 1;

  useEffect(() => {
    if (showSoldOut) {
      getBuyers();
    }
  }, [showSoldOut]);

  const handleNoneOfAboveChecked = (checked) => {
    if (selectedRadioValue !== null) {
      setSelectedRadioValue(null);
    }
    setIsNoneOfAboveChecked(checked);
  };

  const handleRadioButtonCheck = (value) => {
    if (isNoneOfAboveChecked) {
      setIsNoneOfAboveChecked(false);
    }
    setSelectedRadioValue(value);
  };

  const handleHideModal = () => {
    setIsNoneOfAboveChecked(false);
    setSelectedRadioValue(null);
    setShowSoldOut(false);
  };

  const getBuyers = async () => {
    try {
      setIsLoading(true);
      const res = await getItemBuyerListApi.getItemBuyerList({
        item_id: productDetails?.id,
      });
      setBuyers(res?.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSoldOut = () => {
    setShowSoldOut(false);
    setShowConfirmModal(true);
  };

  return (
    <Dialog open={showSoldOut} onOpenChange={handleHideModal}>
      <DialogContent
        onInteractOutside={(e) => {
          e.preventDefault();
        }}
      >
        <DialogHeader>
          <DialogTitle className="text-xl">
            {isJobAd ? t("whoWasHired") : t("whoMadePurchase")}
          </DialogTitle>
        </DialogHeader>

        <div className="mt-4 flex flex-col gap-6">
          <div className="rounded-md p-2 bg-muted flex items-center gap-4">
            <div className="">
              <CustomImage
                src={productDetails?.image}
                alt={productDetails?.name}
                height={80}
                width={80}
                className="h-20 w-20"
              />
            </div>
            <div>
              <h1 className="text-base font-medium">{productDetails?.name}</h1>
              <p className="text-xl font-medium text-primary">
                {productDetails?.formatted_price}
              </p>
            </div>
          </div>
          <div className="text-sm text-red-500">
            {isJobAd ? t("selectHiredApplicant") : t("selectBuyerFromList")}
          </div>

          {isLoading ? (
            // Buyers list skeleton
            <>
              {[1, 2, 3].map((item) => (
                <div key={item} className="flex justify-between">
                  <div className="flex gap-4 items-center">
                    <Skeleton className="h-12 w-12 rounded-full" />
                    <Skeleton className="h-4 w-24" />
                  </div>
                  <Skeleton className="h-4 w-4 rounded-full" />
                </div>
              ))}
            </>
          ) : (
            <>
              {buyers?.length > 0 ? (
                buyers?.map((buyer) => {
                  return (
                    <div key={buyer?.id} className="flex justify-between">
                      <div className="flex gap-4 items-center">
                        <CustomImage
                          src={buyer?.profile}
                          width={48}
                          height={48}
                          alt="Ad Buyer"
                          className="h-12 w-12 rounded-full"
                        />
                        <span className="text-sm">{buyer?.name}</span>
                      </div>
                      <RadioGroup
                        onValueChange={(value) => handleRadioButtonCheck(value)}
                        value={selectedRadioValue}
                      >
                        <div className="flex items-center space-x-2">
                          <RadioGroupItem
                            value={buyer?.id}
                            id={`buyer-${buyer?.id}`}
                          />
                        </div>
                      </RadioGroup>
                    </div>
                  );
                })
              ) : (
                <div className="flex justify-center flex-col items-center gap-4">
                  <div>
                    <CustomImage
                      src={NoDataFound}
                      alt="no_img"
                      width={200}
                      height={200}
                    />
                  </div>
                  <h3 className="text-xl font-medium">
                    {isJobAd ? t("noApplicantsFound") : t("noBuyersFound")}
                  </h3>
                </div>
              )}
            </>
          )}
        </div>
        <div className="pt-6 pb-1 border-t flex items-center justify-between">
          <div className="flex items-center gap-2 ">
            <Checkbox
              id="terms"
              checked={isNoneOfAboveChecked}
              onCheckedChange={(checked) => handleNoneOfAboveChecked(checked)}
            />
            <label
              htmlFor="terms"
              className="text-sm  leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
            >
              {t("noneOfAbove")}
            </label>
          </div>
          <button
            className="border rounded-md px-4 py-2 text-lg disabled:bg-gray-500 disabled:text-white hover:bg-primary disabled:border-none hover:text-white"
            disabled={
              (!selectedRadioValue && !isNoneOfAboveChecked) || isLoading
            }
            onClick={handleSoldOut}
          >
            {isJobAd ? t("jobClosed") : t("soldOut")}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
};
export default SoldOutModal;
