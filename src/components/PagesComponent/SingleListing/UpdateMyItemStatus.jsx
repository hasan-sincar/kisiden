"use client";
import { chanegItemStatusApi } from "@/utils/api";
import toast from "react-hot-toast";
import { MdKeyboardArrowDown } from "react-icons/md";

const UpdateMyItemStatus = ({
  t,
  SingleListing,
  Status,
  setStatus,
  setIsCallSingleListing,
  setIsSoldOutModalOpen,
  setSingleListing,
}) => {
  const isSoftRejected =
    SingleListing?.status === "soft rejected" ||
    SingleListing?.status === "resubmitted";
  const IsDisabled = !(SingleListing?.status === "approved");

  const handleStatusChange = (e) => {
    setStatus(e.target.value);
  };

  const updateItemStatus = async () => {
    if (SingleListing?.status === Status) {
      toast.error(t("changeStatusToSave"));
      return;
    }

    if (Status === "sold out") {
      setIsSoldOutModalOpen(true);
      return;
    }
    const res = await chanegItemStatusApi.changeItemStatus({
      item_id: SingleListing?.id,
      status: Status,
    });
    if (res?.data?.error === false) {
      setIsCallSingleListing((prev) => !prev);
      if (Status === "inactive") {
        toast.success(t("statusUpdated"));
      } else if (Status === "active") {
        toast.success(t("advertisementUnderReview"));
      } else {
        toast.success(t("statusUpdated"));
        setIsShowCreateFeaturedAd(false);
      }
    }
  };

  const resubmitAdForReview = async () => {
    try {
      const res = await chanegItemStatusApi.changeItemStatus({
        item_id: SingleListing?.id,
        status: "resubmitted",
      });

      if (res?.data?.error === false) {
        toast.success(t("adResubmitted"));
        setSingleListing((prev) => ({ ...prev, status: "resubmitted" }));
      }
    } catch (error) {
      console.log(error);
      toast.error(error.message);
    }
  };

  return isSoftRejected ? (
    <div className="change_status">
      <div className="status">
        <p className="softRejected">{t("adWasRejectedResubmitNow")}</p>

        {SingleListing?.rejected_reason && (
          <p className="rejectedReason">
            <span className="rejReasonLabel">Rejected Reason:</span>{" "}
            {SingleListing?.rejected_reason}
          </p>
        )}
      </div>
      <div className="change_status_content">
        <button
          className="save_btn m-0"
          disabled={SingleListing?.status === "resubmitted"}
          onClick={resubmitAdForReview}
        >
          {SingleListing?.status === "resubmitted"
            ? t("resubmitted")
            : t("resubmit")}
        </button>
      </div>
    </div>
  ) : (
    <div className="change_status">
      <p className="status">{t("changeStatus")}</p>
      <div className="change_status_content">
        <div className="status_select_wrapper">
          <select
            name="status"
            id="status"
            value={Status}
            disabled={IsDisabled}
            onChange={handleStatusChange}
            className="status_select"
          >
            <option value="active">{t("active")}</option>
            <option value="inactive">{t("deactivate")}</option>
            <option value="review" disabled>
              {t("review")}
            </option>
            <option value="permanent rejected" disabled>
              {t("permanentRejected")}
            </option>
            <option value="expired" disabled>
              {t("expired")}
            </option>
            <option value="sold out">{t("soldOut")}</option>
          </select>
          {!IsDisabled && (
            <MdKeyboardArrowDown size={20} className="down_select_arrow" />
          )}
        </div>
        {SingleListing?.rejected_reason && (
          <p className="rejectedReason">
            <span className="rejReasonLabel">Rejected Reason:</span>{" "}
            {SingleListing?.rejected_reason}
          </p>
        )}
        {!IsDisabled && (
          <button onClick={updateItemStatus} className="save_btn">
            {t("save")}
          </button>
        )}
      </div>
    </div>
  );
};

export default UpdateMyItemStatus;
