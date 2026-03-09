// 📌 components/Common/GetMyAdStatus.jsx
import {
  MdAirplanemodeInactive,
  MdOutlineDone,
  MdOutlineLiveTv,
  MdOutlineSell,
} from "react-icons/md";
import { BiBadgeCheck } from "react-icons/bi";
import { RxCross2 } from "react-icons/rx";
import { RiPassExpiredLine } from "react-icons/ri";
import { IoTimerOutline } from "react-icons/io5";
import { t } from "@/utils";

const GetMyAdStatus = ({
  status,
  isApprovedSort = false,
  isFeature = false,
  isJobCategory = false,
}) => {
  const statusComponents = {
    approved: isApprovedSort
      ? { icon: <MdOutlineLiveTv size={16} color="white" />, text: t("live") }
      : isFeature
      ? { icon: <BiBadgeCheck size={16} color="white" />, text: t("featured") }
      : { icon: <MdOutlineLiveTv size={16} color="white" />, text: t("live") },

    review: {
      icon: <IoTimerOutline size={16} color="white" />,
      text: t("review"),
    },
    "permanent rejected": {
      icon: <RxCross2 size={16} color="white" />,
      text: t("permanentRejected"),
      bg: "bg-red-600",
    },
    "soft rejected": {
      icon: <RxCross2 size={16} color="white" />,
      text: t("softRejected"),
      bg: "bg-red-500",
    },
    inactive: {
      icon: <MdAirplanemodeInactive size={16} color="white" />,
      text: t("deactivate"),
      bg: "bg-gray-500",
    },
    "sold out": {
      icon: <MdOutlineSell size={16} color="white" />,
      text: isJobCategory ? t("positionFilled") : t("soldOut"),
      bg: "bg-yellow-600",
    },
    resubmitted: {
      icon: <MdOutlineDone size={16} color="white" />,
      text: t("resubmitted"),
      bg: "bg-green-600",
    },
    expired: {
      icon: <RiPassExpiredLine size={16} color="white" />,
      text: t("expired"),
      bg: "bg-gray-700",
    },
  };

  const { icon, text, bg = "bg-primary" } = statusComponents[status] || {};

  if (!status) return null;

  return (
    <div className={`flex items-center gap-1 ${bg} rounded-sm py-0.5 px-1`}>
      {icon}
      <span className="text-white text-sm text-ellipsis">{text}</span>
    </div>
  );
};

export default GetMyAdStatus;
