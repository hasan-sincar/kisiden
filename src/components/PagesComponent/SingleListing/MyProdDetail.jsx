"use client";
import ReactShare from "@/components/SEO/ReactShare";
import { exactPrice, formatMyListingDate } from "@/utils";
import { deleteItemApi } from "@/utils/api";
import { Dropdown } from "antd";
import { useRouter } from "next/navigation";
import toast from "react-hot-toast";
import { FaRegCalendarCheck } from "react-icons/fa6";
import { FiShare2 } from "react-icons/fi";
import { LuHeart } from "react-icons/lu";
import { RxEyeOpen } from "react-icons/rx";
import { useSelector } from "react-redux";
import Swal from "sweetalert2";

const MyProdDetail = ({ SingleListing, t, Status, slug }) => {
  const router = useRouter();
  const systemSettingsData = useSelector((state) => state?.Settings);
  const CompanyName = systemSettingsData?.data?.data?.company_name;
  const currentUrl = `${process.env.NEXT_PUBLIC_WEB_URL}/product-details/${slug}`;

  const handleCopyUrl = async () => {
    const headline = `🚀 Discover the perfect deal! Explore "${SingleListing?.name}" from ${CompanyName} and grab it before it's gone. Shop now at ${currentUrl}`;

    try {
      await navigator.clipboard.writeText(headline);
      toast.success(t("copyToClipboard"));
    } catch (error) {
      console.error("Error copying to clipboard:", error);
    }
  };
  const deleteAd = () => {
    Swal.fire({
      title: `${t("areYouSure")} \u200E`,
      text: t("youWantToDeleteThisAd"),
      icon: "warning",
      showCancelButton: true,
      customClass: {
        cancelButton: "Swal-cancel-buttons",
        confirmButton: "Swal-confirm-buttons",
      },
      confirmButtonText: t("yes"),
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          const res = await deleteItemApi.deleteItem({ id: SingleListing?.id });
          if (res?.data?.error === false) {
            toast.success(t("adDeleted"));
            router.push("/ads");
          }
        } catch (error) {
          console.log(error);
        }
      }
    });
  };

  const handleEditClick = () => {
    router.push(`/edit-listing/${SingleListing?.id}`);
  };

  return (
    <div className="listing_product_card">
      <div className="listing_product_card_head">
        <div className="prod_name">
          <span>{SingleListing?.name}</span>
          {Status === "approved" && (
            <Dropdown
              overlay={
                <ReactShare
                  currentUrl={currentUrl}
                  handleCopyUrl={handleCopyUrl}
                  data={SingleListing?.name}
                  CompanyName={CompanyName}
                />
              }
              placement="bottomRight"
              arrow
            >
              <button>
                <FiShare2 size={20} />
              </button>
            </Dropdown>
          )}
        </div>
        <div className="price_ad">
          <div className="price">
            <span>{exactPrice(SingleListing?.price)}</span>
          </div>
          <span className="ad">
            {t("adId")} #{SingleListing?.id}
          </span>
        </div>
      </div>
      <div className="ad_details">
        <div className="date">
          <FaRegCalendarCheck size={14} />
          <span>
            {t("listedOn")}: {formatMyListingDate(SingleListing?.created_at)}
          </span>
        </div>
        <div className="h_line"></div>
        <div className="date">
          <RxEyeOpen size={14} />
          <span>
            {t("views")}: {SingleListing?.clicks}
          </span>
        </div>
        <div className="h_line"></div>
        <div className="date">
          <LuHeart size={14} />
          <span>
            {t("favorites")}: {SingleListing?.total_likes}
          </span>
        </div>
      </div>
      <div className="btn_container">
        <button className="blakcbtn" onClick={deleteAd}>
          {t("delete")}
        </button>

        {(SingleListing?.status == "review" ||
        SingleListing?.status == "soft rejected" ||
        SingleListing?.status === "approved" ||
        SingleListing?.status == "resubmitted") && (
          <button className="cyna_btn" onClick={handleEditClick}>
            {t("edit")}
          </button>
        )}
      </div>
    </div>
  );
};

export default MyProdDetail;
