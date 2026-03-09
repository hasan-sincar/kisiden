import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { t, truncate } from "@/utils";
import { useSelector } from "react-redux";
import { FiUser } from "react-icons/fi";
import { IoMdNotificationsOutline } from "react-icons/io";
import { BiChat, BiDollarCircle, BiReceipt } from "react-icons/bi";
import { LiaAdSolid } from "react-icons/lia";
import { LuHeart } from "react-icons/lu";
import { MdOutlineRateReview, MdWorkOutline } from "react-icons/md";
import { RiLogoutCircleLine } from "react-icons/ri";
import { FaAngleDown } from "react-icons/fa";
import { useMediaQuery } from "usehooks-ts";
import CustomImage from "@/components/Common/CustomImage";
import { useNavigate } from "@/components/Common/useNavigate";

const ProfileDropdown = ({ IsLogout, setIsLogout }) => {
  const isSmallScreen = useMediaQuery("(max-width: 1200px)");
  const { navigate } = useNavigate();
  const UserData = useSelector(userSignUpData);
  return (
    <DropdownMenu key={IsLogout}>
      <DropdownMenuTrigger className="flex items-center gap-1">
        <CustomImage
          src={UserData?.profile}
          alt={UserData?.name}
          width={32}
          height={32}
          className="rounded-full w-8 h-8 aspect-square object-cover border"
        />
        <p>{truncate(UserData.name, 12)}</p>
        <FaAngleDown className="text-muted-foreground flex-shrink-0" size={12} />
      </DropdownMenuTrigger>
      <DropdownMenuContent align={isSmallScreen ? "start" : "center"}>
        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/profile")}
        >
          <FiUser size={16} />
          <span>{t("myProfile")}</span>
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/notifications")}
        >
          <IoMdNotificationsOutline size={16} />
          {t("notification")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/chat")}
        >
          <BiChat size={16} />
          {t("chat")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/user-subscription")}
        >
          <BiDollarCircle size={16} />
          {t("subscription")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/my-ads")}
        >
          <LiaAdSolid size={16} />
          {t("myAds")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/favorites")}
        >
          <LuHeart size={16} />
          {t("favorites")}
        </DropdownMenuItem>

        <DropdownMenuItem onClick={() => navigate("/transactions")}>
          <BiReceipt size={16} />
          {t("transaction")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/reviews")}
        >
          <MdOutlineRateReview size={16} />
          {t("myReviews")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => navigate("/job-applications")}
        >
          <MdWorkOutline size={16} />
          {t("jobApplications")}
        </DropdownMenuItem>

        <DropdownMenuItem
          className="cursor-pointer"
          onClick={() => setIsLogout(true)}
        >
          <RiLogoutCircleLine size={16} />
          {t("signOut")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export default ProfileDropdown;
