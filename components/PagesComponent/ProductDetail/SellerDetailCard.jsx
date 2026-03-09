import { useState } from "react";
import { Badge } from "@/components/ui/badge";
import { MdVerifiedUser } from "react-icons/md";
import { IoMdStar } from "react-icons/io";
import { FaArrowRight, FaPaperPlane } from "react-icons/fa";
import { IoChatboxEllipsesOutline } from "react-icons/io5";
import { useSelector } from "react-redux";
import { extractYear, t } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import { BiPhoneCall } from "react-icons/bi";
import { itemOfferApi } from "@/utils/api";
import { toast } from "sonner";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { Gift } from "lucide-react";
import MakeOfferModal from "./MakeOfferModal";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import ApplyJobModal from "./ApplyJobModal";
import CustomImage from "@/components/Common/CustomImage";
import Link from "next/link";
import { useNavigate } from "@/components/Common/useNavigate";

const SellerDetailCard = ({ productDetails, setProductDetails }) => {
  const { navigate } = useNavigate();
  const userData = productDetails && productDetails?.user;
  const memberSinceYear = productDetails?.created_at
    ? extractYear(productDetails.created_at)
    : "";
  const [IsStartingChat, setIsStartingChat] = useState(false);
  const loggedInUser = useSelector(userSignUpData);
  const loggedInUserId = loggedInUser?.id;
  const [IsOfferModalOpen, setIsOfferModalOpen] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);

  const isAllowedToMakeOffer =
    productDetails?.price > 0 &&
    !productDetails?.is_already_offered &&
    Number(productDetails?.category?.is_job_category) === 0 &&
    Number(productDetails?.category?.price_optional) === 0;
  const isJobCategory = Number(productDetails?.category?.is_job_category) === 1;
  const isApplied = productDetails?.is_already_job_applied;
  const item_id = productDetails?.id;

  const offerData = {
    itemPrice: productDetails?.price,
    itemId: productDetails?.id,
  };

  const handleChat = async () => {
    if (!loggedInUserId) {
      setIsLoginOpen(true);
      return;
    }
    try {
      setIsStartingChat(true);
      const response = await itemOfferApi.offer({
        item_id: offerData.itemId,
      });
      const { data } = response.data;
      navigate("/chat?activeTab=buying&chatid=" + data?.id);
    } catch (error) {
      toast.error(t("unableToStartChat"));
      console.log(error);
    } finally {
      setIsStartingChat(false);
    }
  };

  const handleMakeOffer = () => {
    if (!loggedInUserId) {
      setIsLoginOpen(true);
      return;
    }
    setIsOfferModalOpen(true);
  };

  const handleApplyJob = () => {
    if (!loggedInUserId) {
      setIsLoginOpen(true);
      return;
    }
    setShowApplyModal(true);
  };

  return (
    <>
      <div className="flex items-center rounded-lg border flex-col">
        {(userData?.is_verified === 1 || memberSinceYear) && (
          <div className="p-4 flex justify-between items-center w-full">
            {productDetails?.user?.is_verified == 1 && (
              <Badge
                variant="outline"
                className="p-1 bg-[#FA6E53] flex items-center gap-1 rounded-md text-white text-sm"
              >
                <MdVerifiedUser size={20} />
                {t("verified")}
              </Badge>
            )}
            {memberSinceYear && (
              <p className="ltr:ml-auto rtl:mr-auto text-sm text-muted-foreground">
                {t("memberSince")}: {memberSinceYear}
              </p>
            )}
          </div>
        )}
        <div className="border-b w-full"></div>
        <div className="flex gap-2 justify-between w-full items-center p-4">
          <div className="flex gap-2.5 items-center max-w-[90%]">
            <CustomImage
              onClick={() => navigate(`/seller/${productDetails?.user?.id}`)}
              src={productDetails?.user?.profile}
              alt="Seller Image"
              width={80}
              height={80}
              className="w-[80px] aspect-square rounded-lg cursor-pointer"
            />
            <div className="flex flex-col gap-1 min-w-0">
              <CustomLink
                href={`/seller/${productDetails?.user?.id}`}
                className="font-bold text-lg text_ellipsis"
              >
                {productDetails?.user?.name}
              </CustomLink>
              {productDetails?.user?.reviews_count > 0 &&
                productDetails?.user?.average_rating && (
                  <div className="flex items-center gap-1 text-sm">
                    <IoMdStar size={20} className="text-black" />
                    <p className="flex">
                      {Number(productDetails?.user?.average_rating).toFixed(2)}
                    </p>{" "}
                    |{" "}
                    <p className="flex text-sm ">
                      {productDetails?.user?.reviews_count}
                    </p>{" "}
                    {t("ratings")}
                  </div>
                )}
              {productDetails?.user?.show_personal_details === 1 &&
                productDetails?.user?.email && (
                  <Link
                    href={`mailto:${productDetails?.user?.email}`}
                    className="text-sm text_ellipsis"
                  >
                    {productDetails?.user?.email}
                  </Link>
                )}
            </div>
          </div>
          <CustomLink href={`/seller/${productDetails?.user?.id}`}>
            <FaArrowRight size={20} className="text-black rtl:scale-x-[-1]" />
          </CustomLink>
        </div>
        <div className="border-b w-full"></div>
        <div className="flex flex-wrap items-center gap-4 p-4 w-full">
          <button
            onClick={handleChat}
            disabled={IsStartingChat}
            className="bg-[#000] text-white p-4 rounded-md flex items-center gap-2 text-base font-medium justify-center whitespace-nowrap [flex:1_1_47%]"
          >
            <IoChatboxEllipsesOutline size={22} />
            {IsStartingChat ? (
              <span>{t("startingChat")}</span>
            ) : (
              <span>{t("startChat")}</span>
            )}
          </button>

          {productDetails?.user?.mobile && (
            <Link
              href={`tel:${
                productDetails?.user?.country_code
                  ? `+${productDetails.user.country_code}`
                  : ""
              }${productDetails?.user?.mobile}`}
              className="bg-[#000] text-white p-4 rounded-md flex items-center gap-2 text-base font-medium justify-center whitespace-nowrap [flex:1_1_47%]"
            >
              <BiPhoneCall size={21} />
              <span>{t("call")}</span>
            </Link>
          )}
          {isAllowedToMakeOffer && (
            <button
              onClick={handleMakeOffer}
              className="bg-primary text-white p-4 rounded-md flex items-center gap-2 text-base font-medium justify-center whitespace-nowrap [flex:1_1_47%]"
            >
              <Gift size={21} />
              {t("makeOffer")}
            </button>
          )}
          {isJobCategory && (
            <button
              className={`text-white p-4 rounded-md flex items-center gap-2 text-base font-medium justify-center whitespace-nowrap [flex:1_1_47%] ${
                isApplied ? "bg-primary" : "bg-black"
              }`}
              disabled={isApplied}
              onClick={handleApplyJob}
            >
              <FaPaperPlane size={20} />
              {isApplied ? t("applied") : t("applyNow")}
            </button>
          )}
        </div>
      </div>

      <MakeOfferModal
        isOpen={IsOfferModalOpen}
        onClose={() => setIsOfferModalOpen(false)}
        productDetails={productDetails}
        key={`offer-modal-${IsOfferModalOpen}`}
      />
      <ApplyJobModal
        key={`apply-job-modal-${showApplyModal}`}
        showApplyModal={showApplyModal}
        setShowApplyModal={setShowApplyModal}
        item_id={item_id}
        setProductDetails={setProductDetails}
      />
    </>
  );
};

export default SellerDetailCard;
