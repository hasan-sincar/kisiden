"use client";
import ProfileSidebar from "@/components/Profile/ProfileSidebar";
import { usePathname } from "next/navigation";
import Checkauth from "@/HOC/Checkauth";
import Notifications from "../Notifications/Notifications";
import Profile from "@/components/Profile/Profile";
import MyAds from "../MyAds/MyAds";
import Favorites from "../Favorites/Favorites";
import Transactions from "../Transactions/Transactions";
import Reviews from "../Reviews/Reviews";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import Chat from "../Chat/Chat";
import Layout from "@/components/Layout/Layout";
import ProfileSubscription from "../Subscription/ProfileSubscription";
import JobApplications from "../JobApplications/JobApplications";
import { t } from "@/utils";
import { useMediaQuery } from "usehooks-ts";
import BlockedUsersMenu from "../Chat/BlockedUsersMenu";
import { cn } from "@/lib/utils";

const ProfileDashboard = () => {
  const pathname = usePathname();
  const isNotifications = pathname === "/notifications";
  const isSubscriptions = pathname === "/user-subscription";
  const isProfile = pathname === "/profile";
  const isAds = pathname === "/my-ads";
  const isFavorite = pathname === "/favorites";
  const isTransaction = pathname === "/transactions";
  const isReviews = pathname === "/reviews";
  const isChat = pathname == "/chat";
  const isJobApplications = pathname == "/job-applications";

  const isLargeScreen = useMediaQuery("(min-width: 992px)");
  const isSmallerThanLaptop = useMediaQuery("(max-width: 1200px)");

  const renderHeading = () => {
    if (isProfile) {
      return t("myProfile");
    } else if (isNotifications) {
      return t("notifications");
    } else if (isSubscriptions) {
      return t("subscription");
    } else if (isAds) {
      return t("myAds");
    } else if (isFavorite) {
      return t("myFavorites");
    } else if (isTransaction) {
      return t("myTransaction");
    } else if (isReviews) {
      return t("reviews");
    } else if (isChat) {
      return "chat";
    } else if (isJobApplications) {
      return t("jobApplications");
    }
  };

  const renderContent = () => {
    if (isProfile) {
      return <Profile />;
    } else if (isNotifications) {
      return <Notifications />;
    } else if (isSubscriptions) {
      return <ProfileSubscription />;
    } else if (isAds) {
      return <MyAds />;
    } else if (isFavorite) {
      return <Favorites />;
    } else if (isTransaction) {
      return <Transactions />;
    } else if (isReviews) {
      return <Reviews />;
    } else if (isChat) {
      return <Chat />;
    } else if (isJobApplications) {
      return <JobApplications />;
    }
  };
  const breadCrumbTitle = renderHeading();
  return (
    <Layout>
      <BreadCrumb title2={breadCrumbTitle} />
      <div className="container mt-8">
        {isChat && isSmallerThanLaptop ? (
          <div className="flex items-center justify-between">
            <h1 className="sectionTitle">{renderHeading()}</h1>
            <BlockedUsersMenu />
          </div>
        ) : (
          <h1 className="sectionTitle">{renderHeading()}</h1>
        )}

        <div
          className={cn(
            "grid grid-cols-1 lg:grid-cols-4 lg:border rounded-lg mt-6",
            isChat && "border"
          )}
        >
          {isLargeScreen && (
            <div className="max-h-fit lg:col-span-1 ltr:lg:border-r rtl:lg:border-l">
              <ProfileSidebar />
            </div>
          )}

          <div
            className={cn("lg:col-span-3 lg:border-t-0", !isChat && "lg:p-7")}
          >
            {renderContent()}
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default Checkauth(ProfileDashboard);
