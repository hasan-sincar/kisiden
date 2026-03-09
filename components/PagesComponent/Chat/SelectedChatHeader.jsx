import { HiOutlineDotsVertical } from "react-icons/hi";
import { t } from "@/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import CustomLink from "@/components/Common/CustomLink";
import { blockUserApi, unBlockUserApi } from "@/utils/api";
import { toast } from "sonner";
import { useSelector } from "react-redux";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import CustomImage from "@/components/Common/CustomImage";
import { MdArrowBack } from "react-icons/md";

const SelectedChatHeader = ({
  selectedChat,
  isSelling,
  setSelectedChat,
  handleBack,
  isLargeScreen,
}) => {
  const isBlocked = selectedChat?.user_blocked;
  const userData = isSelling ? selectedChat?.buyer : selectedChat?.seller;
  const itemData = selectedChat?.item;
  const isRTL = useSelector(getIsRtl);

  const handleBlockUser = async (id) => {
    try {
      const response = await blockUserApi.blockUser({
        blocked_user_id: userData?.id,
      });

      if (response?.data?.error === false) {
        setSelectedChat((prevData) => ({
          ...prevData,
          user_blocked: true,
        }));
        toast.success(response?.data?.message);
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
    }
  };

  const handleUnBlockUser = async (id) => {
    try {
      const response = await unBlockUserApi.unBlockUser({
        blocked_user_id: userData?.id,
      });
      if (response?.data.error === false) {
        setSelectedChat((prevData) => ({
          ...prevData,
          user_blocked: false,
        }));
        toast.success(response?.data?.message);
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
    }
  };

  return (
    <div className="flex items-center justify-between gap-1 px-4 py-3 border-b">
      <div className="flex items-center gap-4 min-w-0">
        {!isLargeScreen && (
          <button onClick={handleBack}>
            <MdArrowBack size={20} className="rtl:scale-x-[-1]" />
          </button>
        )}
        <div className="relative flex-shrink-0">
          <CustomLink href={`/seller/${userData?.id}`}>
            <CustomImage
              src={userData?.profile}
              alt="avatar"
              width={56}
              height={56}
              className="w-[56px] h-auto aspect-square object-cover rounded-full"
            />
          </CustomLink>
          <CustomImage
            src={userData?.profile}
            alt="avatar"
            width={24}
            height={24}
            className="w-[24px] h-auto aspect-square object-cover rounded-full absolute top-[32px] bottom-[-6px] right-[-6px]"
          />
        </div>
        <div className="flex flex-col gap-2 w-full min-w-0">
          <CustomLink
            href={`/seller/${userData?.id}`}
            className="font-medium truncate"
            title={userData?.name}
          >
            {userData?.name}
          </CustomLink>
          <p
            className="truncate text-sm"
            title={itemData?.translated_name || itemData?.name}
          >
            {itemData?.translated_name || itemData?.name}
          </p>
        </div>
      </div>

      {/* Dropdown Menu for Actions */}

      <div className="flex flex-col gap-1">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="self-end">
              <HiOutlineDotsVertical size={22} />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align={isRTL ? "start" : "end"}>
            <DropdownMenuItem
              className="cursor-pointer"
              onClick={isBlocked ? handleUnBlockUser : handleBlockUser}
            >
              <span>{isBlocked ? t("unblock") : t("block")}</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
        <div className="text-xs whitespace-nowrap">
          {itemData?.formatted_price}
        </div>
      </div>
    </div>
  );
};

export default SelectedChatHeader;
