import { formatDateMonthYear, t } from "@/utils/index";
import { FaBriefcase, FaRegCalendarCheck, FaRegHeart } from "react-icons/fa";
import { IoEyeOutline } from "react-icons/io5";
import { toast } from "sonner";
import { useSelector } from "react-redux";
import { deleteItemApi } from "@/utils/api";
import CustomLink from "@/components/Common/CustomLink";
import { getCompanyName } from "@/redux/reducer/settingSlice";
import ShareDropdown from "@/components/Common/ShareDropdown";
import { useState } from "react";
import JobApplicationModal from "./JobApplicationModal";
import ReusableAlertDialog from "@/components/Common/ReusableAlertDialog";
import { useNavigate } from "@/components/Common/useNavigate";

const MyAdsListingDetailCard = ({ productDetails }) => {
  const { navigate } = useNavigate();
  const CompanyName = useSelector(getCompanyName);

  const [IsDeleteAccount, setIsDeleteAccount] = useState(false);
  const [IsDeletingAccount, setIsDeletingAccount] = useState(false);

  const [IsShowJobApplications, setIsShowJobApplications] = useState(false);
  const productName =
    productDetails?.translated_item?.name || productDetails?.name;
  // share variables
  const currentUrl = `${process.env.NEXT_PUBLIC_WEB_URL}/ad-details/${productDetails?.slug}`;
  const FbTitle = productName + " | " + CompanyName;
  const headline = `🚀 Discover the perfect deal! Explore "${productName}" from ${CompanyName} and grab it before it's gone. Shop now at`;
  const isEditable =
    productDetails?.status &&
    !["permanent rejected", "inactive", "sold out", "expired"].includes(
      productDetails.status
    );

  // job application variables
  const isJobCategory = Number(productDetails?.category?.is_job_category) === 1;
  const isShowReceivedJobApplications =
    isJobCategory &&
    (productDetails?.status === "approved" ||
      productDetails?.status === "featured" ||
      productDetails?.status === "sold out");

  const price = isJobCategory
    ? productDetails?.formatted_salary_range
    : productDetails?.formatted_price;

  const deleteAd = async () => {
    try {
      setIsDeletingAccount(true);
      const res = await deleteItemApi.deleteItem({
        item_id: productDetails?.id,
      });
      if (res?.data?.error === false) {
        toast.success(t("adDeleted"));
        navigate("/my-ads");
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsDeletingAccount(false);
    }
  };

  return (
    <>
      <div className="flex flex-col border rounded-lg">
        <div className="flex  w-full flex-col gap-4 p-4 border-b">
          <div className="flex justify-between max-w-full">
            <h1
              className="text-2xl font-medium word-break-all line-clamp-2"
              title={productName}
            >
              {productName}
            </h1>
            {productDetails?.status === "approved" && (
              <ShareDropdown
                url={currentUrl}
                title={FbTitle}
                headline={headline}
                companyName={CompanyName}
                className="rounded-full size-10 flex items-center justify-center p-2 border"
              />
            )}
          </div>
          <div className="flex justify-between items-end w-full">
            <h2
              className="text-primary text-3xl font-bold break-all text-balance line-clamp-2"
              title={price}
            >
              {price}
            </h2>
            <p className="text-sm text-muted-foreground whitespace-nowrap">
              {t("adId")} #{productDetails?.id}
            </p>
          </div>
        </div>
        <div className="flex items-center justify-center text-muted-foreground gap-1 p-4 border-b flex-wrap">
          <div className="text-sm flex items-center gap-1 ">
            <FaRegCalendarCheck size={14} />
            {t("postedOn")}: {formatDateMonthYear(productDetails?.created_at)}
          </div>
          <div className="ltr:border-l rtl:border-r gap-1 flex items-center text-sm px-2">
            <IoEyeOutline size={14} />
            {t("views")}: {productDetails?.clicks}
          </div>
          <div className="ltr:border-l rtl:border-r gap-1 flex items-center text-sm px-2">
            <FaRegHeart size={14} />
            {t("favorites")}: {productDetails?.total_likes}
          </div>
        </div>
        <div className="p-4 flex items-center gap-4 flex-wrap">
          <button
            className="py-2 px-4 flex-1 rounded-md bg-black text-white font-medium"
            onClick={() => setIsDeleteAccount(true)}
          >
            {t("delete")}
          </button>

          {isEditable && (
            <CustomLink
              href={`/edit-listing/${productDetails?.id}`}
              className="bg-primary py-2 px-4 flex-1 rounded-md text-white font-medium text-center"
            >
              {t("edit")}
            </CustomLink>
          )}

          {isShowReceivedJobApplications && (
            <button
              onClick={() => setIsShowJobApplications(true)}
              className="bg-black py-2 px-4 flex-1 rounded-md text-white font-medium whitespace-nowrap flex items-center gap-2 justify-center"
            >
              <FaBriefcase />
              {t("jobApplications")}
            </button>
          )}
        </div>
      </div>
      <JobApplicationModal
        IsShowJobApplications={IsShowJobApplications}
        setIsShowJobApplications={setIsShowJobApplications}
        listingId={productDetails?.id}
        isJobFilled={productDetails?.status === "sold out"}
      />
      <ReusableAlertDialog
        open={IsDeleteAccount}
        onCancel={() => setIsDeleteAccount(false)}
        onConfirm={deleteAd}
        title={t("areYouSure")}
        description={t("youWantToDeleteThisAd")}
        cancelText={t("cancel")}
        confirmText={t("yes")}
        confirmDisabled={IsDeletingAccount}
      />
    </>
  );
};

export default MyAdsListingDetailCard;
