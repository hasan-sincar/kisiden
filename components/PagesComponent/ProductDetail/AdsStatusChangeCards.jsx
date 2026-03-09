import { useState } from "react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { chanegItemStatusApi } from "@/utils/api";
import { toast } from "sonner";
import SoldOutModal from "./SoldOutModal";
import ReusableAlertDialog from "@/components/Common/ReusableAlertDialog";
import { t } from "@/utils";
import { useNavigate } from "@/components/Common/useNavigate";

const AdsStatusChangeCards = ({
  productDetails,
  setProductDetails,
  status,
  setStatus,
}) => {
  const { navigate } = useNavigate();
  const [IsChangingStatus, setIsChangingStatus] = useState(false);
  const [showSoldOut, setShowSoldOut] = useState(false);
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [selectedRadioValue, setSelectedRadioValue] = useState(null);

  const isJobAd = productDetails?.category?.is_job_category === 1;

  const isSoftRejected =
    productDetails?.status === "soft rejected" ||
    productDetails?.status === "resubmitted";

  const IsDisableSelect = !(
    productDetails?.status === "approved" ||
    productDetails?.status === "inactive"
  );

  const isShowRejectedReason =
    productDetails?.rejected_reason &&
    (productDetails?.status === "soft rejected" ||
      productDetails?.status === "permanent rejected");
  const resubmitAdForReview = async () => {
    try {
      const res = await chanegItemStatusApi.changeItemStatus({
        item_id: productDetails?.id,
        status: "resubmitted",
      });

      if (res?.data?.error === false) {
        toast(t("adResubmitted"));
        setProductDetails((prev) => ({ ...prev, status: "resubmitted" }));
      }
    } catch (error) {
      console.log(error);
      toast(error.message);
    }
  };

  const handleStatusChange = (newStatus) => {
    setStatus(newStatus);
  };

  const updateItemStatus = async () => {
    if (productDetails?.status === status) {
      toast.error(t("changeStatusToSave"));
      return;
    }
    if (status === "sold out") {
      setShowSoldOut(true);
      return;
    }
    try {
      setIsChangingStatus(true);
      const res = await chanegItemStatusApi.changeItemStatus({
        item_id: productDetails?.id,
        status: status === "approved" ? "active" : status,
      });
      if (res?.data?.error === false) {
        setProductDetails((prev) => ({ ...prev, status }));
        toast.success(t("statusUpdated"));
        navigate("/my-ads");
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log("error", error);
    } finally {
      setIsChangingStatus(false);
    }
  };

  const makeItemSoldOut = async () => {
    try {
      setIsChangingStatus(true);
      await new Promise((resolve) => setTimeout(resolve, 5000));
      const res = await chanegItemStatusApi.changeItemStatus({
        item_id: productDetails?.id,
        status: "sold out",
        sold_to: selectedRadioValue,
      });
      if (res?.data?.error === false) {
        toast.success(t("statusUpdated"));
        setProductDetails((prev) => ({ ...prev, status: "sold out" }));
        setShowConfirmModal(false);
      } else {
        toast.error(t("failedToUpdateStatus"));
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsChangingStatus(false);
    }
  };

  return (
    <>
      {isSoftRejected ? (
        <div className="border rounded-md gap-4">
          <div className="flex flex-col">
            <div className="p-4 text-xl font-medium border-b">
              {t("adWasRejectedResubmitNow")}
            </div>
            {productDetails?.rejected_reason && (
              <p className="bg-red-100 text-[#dc3545] px-2 py-1 rounded text-sm mt-[7px] font-medium">
                <span className="font-medium">{t("rejectedReason")}:</span>{" "}
                {productDetails?.rejected_reason}
              </p>
            )}
            <div className="w-full p-4 ">
              <button
                className="bg-primary text-white font-medium w-full p-2 rounded-md"
                disabled={productDetails?.status === "resubmitted"}
                onClick={resubmitAdForReview}
              >
                {productDetails?.status === "resubmitted"
                  ? t("resubmitted")
                  : t("resubmit")}
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div className="flex flex-col border rounded-md ">
          <div className="p-4 border-b font-semibold">{t("changeStatus")}</div>
          <div className="p-4 flex flex-col gap-4 ">
            <Select
              className="outline-none "
              value={status}
              onValueChange={handleStatusChange}
              disabled={IsChangingStatus || IsDisableSelect}
            >
              <SelectTrigger className="outline-none">
                <SelectValue placeholder={t("status")} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="approved">{t("active")}</SelectItem>
                <SelectItem value="inactive">{t("deactivate")}</SelectItem>
                <SelectItem value="review" disabled>
                  {" "}
                  {t("review")}
                </SelectItem>
                <SelectItem value="permanent rejected" disabled>
                  {" "}
                  {t("permanentRejected")}
                </SelectItem>
                <SelectItem value="expired" disabled>
                  {t("expired")}
                </SelectItem>
                <SelectItem
                  value="sold out"
                  disabled={productDetails?.status === "inactive"}
                >
                  {isJobAd ? t("jobClosed") : t("soldOut")}
                </SelectItem>
              </SelectContent>
            </Select>

            {isShowRejectedReason && (
              <p className="bg-red-100 text-[#dc3545] px-2 py-1 rounded text-sm mt-[7px] font-medium">
                <span className="font-medium">{t("rejectedReason")}:</span>{" "}
                {productDetails?.rejected_reason}
              </p>
            )}
            <button
              className="bg-primary text-white font-medium w-full p-2 rounded-md disabled:opacity-80"
              onClick={updateItemStatus}
              disabled={IsChangingStatus || IsDisableSelect}
            >
              {t("save")}
            </button>
          </div>
        </div>
      )}
      <SoldOutModal
        productDetails={productDetails}
        showSoldOut={showSoldOut}
        setShowSoldOut={setShowSoldOut}
        selectedRadioValue={selectedRadioValue}
        setSelectedRadioValue={setSelectedRadioValue}
        setShowConfirmModal={setShowConfirmModal}
      />

      <ReusableAlertDialog
        open={showConfirmModal}
        onCancel={() => setShowConfirmModal(false)}
        onConfirm={makeItemSoldOut}
        title={isJobAd ? t("confirmHire") : t("confirmSoldOut")}
        description={
          isJobAd ? t("markAsClosedDescription") : t("cantUndoChanges")
        }
        cancelText={t("cancel")}
        confirmText={t("confirm")}
        confirmDisabled={IsChangingStatus}
      />
    </>
  );
};

export default AdsStatusChangeCards;
