import { HiOutlineDotsVertical } from "react-icons/hi";
import { t } from "@/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import CustomLink from "@/components/Common/CustomLink";
import { blockUserApi, deleteChatApi, unBlockUserApi } from "@/utils/api";
import { toast } from "sonner";
import { useSelector } from "react-redux";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import CustomImage from "@/components/Common/CustomImage";
import { MdArrowBack } from "react-icons/md";
import { Loader2, Trash2, X } from "lucide-react";
import { deleteChatMessagesApi } from "@/utils/api";
import { useState } from "react";
import { cn } from "@/lib/utils";
import { useSearchParams } from "next/navigation";
import { useNavigate } from "@/components/Common/useNavigate";

const SelectedChatHeader = ({
  selectedChat,
  isSelling,
  setSelectedChat,
  handleBack,
  selectMode,
  setSelectMode,
  selectedMessages,
  setSelectedMessages,
  chatId,
  totalChats,
  setChatListData,
  setChatMessages
}) => {
  const isBlocked = selectedChat?.user_blocked;
  const userData = isSelling ? selectedChat?.buyer : selectedChat?.seller;
  const itemData = selectedChat?.item;
  const isRTL = useSelector(getIsRtl);
  const [isDeleting, setIsDeleting] = useState(false)
  const searchParams = useSearchParams();
  const { navigate } = useNavigate();

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
        setChatListData((prev) => ({
          ...prev,
          list: prev.list.map((item) =>
            item.id === selectedChat.id ? { ...item, user_blocked: true } : item
          ),
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
        setChatListData((prev) => ({
          ...prev,
          list: prev.list.map((item) =>
            item.id === selectedChat.id ? { ...item, user_blocked: false } : item
          ),
        }));
        toast.success(response?.data?.message);
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
    }
  };

  const handleBulkDelete = async () => {
    if (selectedMessages.length === 0) return;
    try {
      setIsDeleting(true)
      const response = await deleteChatMessagesApi.deleteChatMessages({
        item_offer_id: chatId,
        message_ids: selectedMessages,
      });
      if (response?.data?.error === false) {
        toast.success(response?.data?.message);
        // --- OPTIMISTIC UPDATE ---
        // Directly filter out the deleted messages from the lifted state
        setChatMessages((prev) =>
          prev.filter((msg) => !selectedMessages.includes(msg.id))
        );
        setSelectMode(false);
        setSelectedMessages([]);
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
      toast.error(t("somthingWentWrong"));
    } finally {
      setIsDeleting(false)
    }
  };

  const handleCancelSelect = () => {
    setSelectMode(false);
    setSelectedMessages([]);
  };

  const handleDeleteChat = async () => {
    try {
      const item_offer_id = selectedChat?.id;
      const response = await deleteChatApi.deleteChat({ item_offer_id });
      if (response?.data?.error === false) {
        toast.success(response?.data?.message);
        const params = new URLSearchParams(searchParams.toString());

        if (totalChats === 1) {
          // CASE: Last Chat - Navigate away
          params.delete("chatid");
          params.delete("chat_ad_id");
          params.delete("lang");
          setSelectedChat({});
          navigate(`?${params.toString()}`, { scroll: false });
        } else {
          // CASE: Staying on page - Update local list
          setChatListData((prev) => ({
            ...prev,
            list: prev.list.filter((item) => item.id !== item_offer_id),
            total: prev.total - 1,
          }));
          // Reset view for the next chat
          params.delete("chatid");
          params.delete("lang");
          setSelectedChat({});
          navigate(`?${params.toString()}`, { scroll: false });
        }
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
      toast.error(t("somthingWentWrong"));
    }
  };

  return (
    <div className="flex items-center justify-between gap-1 px-4 py-3 border-b">
      <div className="flex items-center gap-4 min-w-0">

        <button onClick={handleBack} className={cn(
          "block xl:hidden"
        )}>
          <MdArrowBack size={20}
          />
        </button>

        <div className="relative flex-shrink-0">
          <CustomLink href={`/seller/${userData?.id}`}>
            <CustomImage
              key={userData?.id}
              src={userData?.profile}
              alt="avatar"
              width={56}
              height={56}
              className="w-[56px] h-auto aspect-square object-cover rounded-full"
            />
          </CustomLink>
          <CustomImage
            key={itemData?.id}
            src={itemData?.image}
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
      <div className="flex items-center gap-4">
        {selectMode ? (
          <div className="flex items-center gap-3">
            <span className="text-sm">
              {selectedMessages.length} {t("selected")}
            </span>
            <button
              onClick={handleBulkDelete}
              className="text-destructive"
              title={t("delete")}
              disabled={selectedMessages.length === 0 || isDeleting}
            >
              {
                isDeleting ? <Loader2 className="size-5 animate-spin" /> : <Trash2 size={20} />
              }
            </button>
            <button
              onClick={handleCancelSelect}
              title={t("cancel")}
            >
              <X size={20} />
            </button>
          </div>
        ) : (
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
                <DropdownMenuItem
                  className="cursor-pointer text-destructive"
                  onClick={handleDeleteChat}
                >
                  <span>{t("deleteChat")}</span>
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <div className="text-xs whitespace-nowrap">
              {itemData?.formatted_price}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default SelectedChatHeader;
