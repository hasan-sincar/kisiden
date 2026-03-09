"use client";
import { formatDateMonthYear, t } from "@/utils";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useSelector } from "react-redux";
import { useEffect, useState } from "react";
import { getNotificationList } from "@/utils/api";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import Pagination from "@/components/Common/Pagination";
import NoData from "@/components/EmptyStates/NoData";
import NotificationSkeleton from "./NotificationSkeleton";
import CustomImage from "@/components/Common/CustomImage";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { useNavigate } from "@/components/Common/useNavigate";
import { cn } from "@/lib/utils";

const Notifications = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [notifications, setNotifications] = useState([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const userData = useSelector(userSignUpData);
  const { navigate } = useNavigate();

  const fetchNotificationData = async (page) => {
    try {
      setIsLoading(true);
      const response = await getNotificationList.getNotification({ page });
      if (response?.data?.error === false) {
        setNotifications(response?.data.data.data);
        setTotalPages(response?.data?.data?.last_page);
      } else {
        toast.error(data.message);
      }
    } catch (error) {
      console.error("Error:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchNotificationData(currentPage);
  }, [currentPage]);

  const handlePageChange = (page) => {
    setCurrentPage(page);
  };

  const handleNotificationClick = (notification) => {
    // Check if notification has item slug
    if (notification?.item?.slug) {
      const currentUserId = userData?.id; // Get current user ID
      const notificationUserId = notification?.item?.user_id; // Get notification user ID

      if (currentUserId == notificationUserId) {
        // If current user is the same as notification user, redirect to my-listing
        navigate(`/my-listing/${notification.item.slug}`);
      } else {
        // Otherwise, redirect to ad-details
        navigate(`/ad-details/${notification.item.slug}`);
      }
    }
  };
  return isLoading ? (
    <NotificationSkeleton />
  ) : notifications.length > 0 ? (
    <>
      <div className="overflow-hidden border rounded-md">
        <Table>
          <TableHeader className="bg-muted">
            <TableRow className="text-xs sm:text-sm">
              <TableHead className="text-black font-bold ltr:text-left rtl:text-right">
                {t("notification")}
              </TableHead>
              <TableHead className="text-black font-bold text-center">
                {t("date")}
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody className="text-xs sm:text-sm">
            {notifications.map((notification, index) => (
              <TableRow
                key={index}
                className={cn(
                  "hover:bg-muted",
                  notification?.item?.slug && "cursor-pointer"
                )}
                onClick={() => handleNotificationClick(notification)}
              >
                <TableCell>
                  <div className="flex items-center gap-3">
                    <CustomImage
                      src={notification?.image}
                      width={48}
                      height={48}
                      alt="notification icon"
                      className="w-[48px] h-[48px] object-cover rounded"
                    />
                    <div className="flex flex-col gap-1">
                      <p className="font-medium">{notification.title}</p>
                      <p className="text-sm text-muted-foreground">
                        {notification.message}
                      </p>
                    </div>
                  </div>
                </TableCell>
                <TableCell className="text-center">
                  {formatDateMonthYear(notification.created_at)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      <Pagination
        className="mt-7"
        currentPage={currentPage}
        totalPages={totalPages}
        onPageChange={handlePageChange}
      />
    </>
  ) : (
    <NoData name={t("notifications")} />
  );
};
export default Notifications;
