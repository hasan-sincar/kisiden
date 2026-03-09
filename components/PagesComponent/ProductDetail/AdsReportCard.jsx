import { useState } from "react";
import { PiWarningOctagon } from "react-icons/pi";
import ReportModal from "@/components/User/ReportModal";
import { getIsLoggedIn } from "@/redux/reducer/authSlice";
import { useSelector } from "react-redux";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import { t } from "@/utils";
const AdsReportCard = ({ productDetails, setProductDetails }) => {
  const [isReportModalOpen, setIsReportModalOpen] = useState(false);
  const isLoggedIn = useSelector(getIsLoggedIn);

  const handleReportAd = () => {
    if (!isLoggedIn) {
      setIsLoginOpen(true);
      return;
    }
    setIsReportModalOpen(true);
  };

  return (
    <div className="flex flex-col border rounded-lg ">
      <div className="flex items-center gap-2 p-4">
        <div className="bg-[#DC354514] rounded-full p-2">
          <PiWarningOctagon size={22} className="text-[#DC3545]" />
        </div>
        <p className="text-base">{t("reportItmLabel")}</p>
      </div>
      <div className="border-b w-full"></div>
      <div className="flex p-4 justify-between">
        <div className="flex items-center gap-2">
          <p className="text-base font-medium">{t("adId")}</p>
          <p className="text-base font-medium"> #{productDetails?.id}</p>
        </div>
        <button
          className=" bg-muted text-primary font-semibold py-1 px-2 rounded-md text-sm"
          onClick={handleReportAd}
        >
          {t("reportAd")}
        </button>
      </div>
      <ReportModal
        productDetails={productDetails}
        setProductDetails={setProductDetails}
        isReportModalOpen={isReportModalOpen}
        setIsReportModalOpen={setIsReportModalOpen}
      />
    </div>
  );
};

export default AdsReportCard;
