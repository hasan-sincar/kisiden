import { t } from "@/utils";
import { RiUserForbidLine } from "react-icons/ri";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { getBlockedUsers, unBlockUserApi } from "@/utils/api";
import { useState } from "react";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";
import { useSelector } from "react-redux";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import CustomImage from "@/components/Common/CustomImage";

const BlockedUsersMenu = ({ setSelectedChatDetails }) => {
  const [blockedUsersList, setBlockedUsersList] = useState([]);
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [unblockingId, setUnblockingId] = useState("");
  const isRTL = useSelector(getIsRtl);

  const fetchBlockedUsers = async () => {
    setLoading(true);
    try {
      const response = await getBlockedUsers.blockedUsers();
      const { data } = response;
      setBlockedUsersList(data?.data);
    } catch (error) {
      console.error("Error fetching blocked users:", error);
    } finally {
      setLoading(false);
    }
  };

  const handleOpenChange = (isOpen) => {
    setOpen(isOpen);
    if (isOpen) {
      fetchBlockedUsers();
    }
  };

  const handleUnblock = async (userId, e) => {
    e.stopPropagation();
    setUnblockingId(userId);
    try {
      const response = await unBlockUserApi.unBlockUser({
        blocked_user_id: userId,
      });
      if (response?.data?.error === false) {
        // Refresh the blocked users list after successful unblock
        setBlockedUsersList((prevList) =>
          prevList.filter((user) => user.id !== userId)
        );
        setSelectedChatDetails((prev) => ({
          ...prev,
          user_blocked: false,
        }));
        toast.success(response?.data?.message);
      }
    } catch (error) {
      console.error("Error unblocking user:", error);
    } finally {
      setUnblockingId("");
    }
  };

  const BlockedUserSkeleton = () => (
    <div className="flex items-center justify-between p-2">
      <div className="flex items-center gap-2 flex-1 min-w-0">
        <Skeleton className="h-10 w-10 rounded-full" />
        <Skeleton className="h-4 w-24" />
      </div>
      <Skeleton className="h-8 w-16 rounded-md" />
    </div>
  );

  return (
    <DropdownMenu open={open} onOpenChange={handleOpenChange}>
      <DropdownMenuTrigger asChild>
        <button className="focus:outline-none">
          <RiUserForbidLine size={22} />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align={isRTL ? "start" : "end"} className="w-72">
        <DropdownMenuLabel>{t("blockedUsers")}</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <div className="max-h-64 overflow-y-auto">
          {loading ? (
            Array.from({ length: 2 }, (_, index) => (
              <BlockedUserSkeleton key={index} />
            ))
          ) : blockedUsersList && blockedUsersList.length > 0 ? (
            <DropdownMenuGroup>
              {blockedUsersList.map((user) => (
                <DropdownMenuItem
                  key={user.id}
                  className="flex items-center justify-between p-2"
                >
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <div className="h-10 w-10 flex-shrink-0 rounded-full overflow-hidden bg-gray-200 relative">
                      <CustomImage
                        src={user?.profile}
                        alt={user.name}
                        fill
                        className="object-cover"
                      />
                    </div>
                    <span className="truncate">{user.name}</span>
                  </div>
                  <button
                    onClick={(e) => handleUnblock(user?.id, e)}
                    disabled={unblockingId === user?.id}
                    className={`px-3 py-1 text-sm ${
                      unblockingId === user?.id
                        ? "bg-gray-400 cursor-not-allowed"
                        : "bg-primary hover:bg-primary/80"
                    } text-white rounded-md flex-shrink-0 ml-2`}
                  >
                    {t("unblock")}
                  </button>
                </DropdownMenuItem>
              ))}
            </DropdownMenuGroup>
          ) : (
            <div className="p-4 text-center text-muted-foreground">
              {t("noBlockedUsers")}
            </div>
          )}
        </div>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
export default BlockedUsersMenu;
