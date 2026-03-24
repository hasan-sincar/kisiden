"use client";
import { t } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import { usePathname } from "next/navigation";
import { BiChat, BiDollarCircle, BiReceipt, BiTrashAlt } from "react-icons/bi";
import { FiUser } from "react-icons/fi";
import { IoMdNotificationsOutline } from "react-icons/io";
import { LiaAdSolid } from "react-icons/lia";
import { LuHeart } from "react-icons/lu";
import { MdOutlineRateReview, MdWorkOutline } from "react-icons/md";
import { RiLogoutCircleLine } from "react-icons/ri";
import FirebaseData from "@/utils/Firebase";
import { logoutSuccess, userSignUpData } from "@/redux/reducer/authSlice";
import { toast } from "sonner";
import { useState } from "react";
import { deleteUserApi, logoutApi } from "@/utils/api";
import { deleteUser, getAuth } from "firebase/auth";
import ReusableAlertDialog from "../Common/ReusableAlertDialog";
import { useSelector } from "react-redux";
import { useNavigate } from "../Common/useNavigate";
import DeleteAccountVerifyOtpModal from "../Auth/DeleteAccountVerifyOtpModal";
import { getOtpServiceProvider } from "@/redux/reducer/settingSlice";

const ProfileSidebar = () => {
  const { navigate } = useNavigate();
  const pathname = usePathname();
  const userData = useSelector(userSignUpData);
  const otp_service_provider = useSelector(getOtpServiceProvider);
  const [IsLogout, setIsLogout] = useState(false);
  const [IsDeleting, setIsDeleting] = useState(false);
  const [IsDeleteAccount, setIsDeleteAccount] = useState(false);
  const [IsLoggingOut, setIsLoggingOut] = useState(false);
  const [IsVerifyOtpBeforeDelete, setIsVerifyOtpBeforeDelete] = useState(false);
  const { signOut } = FirebaseData();

  const handleLogout = async () => {
    try {
      setIsLoggingOut(true);
      await signOut();
      const res = await logoutApi.logoutApi({
        ...(userData?.fcm_id && { fcm_token: userData?.fcm_id }),
      });
      if (res?.data?.error === false) {
        logoutSuccess();
        toast.success(t("signOutSuccess"));
        setIsLogout(false);
        if (pathname !== "/") {
          navigate("/");
        }
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log("Failed to logout", error);
    } finally {
      setIsLoggingOut(false);
    }
  };


  const handleDeleteAcc = async () => {
    try {
      setIsDeleting(true);
      const auth = getAuth();
      const user = auth.currentUser;
      const isMobileLogin = userData?.type == "phone";
      const needsOtpVerification = isMobileLogin && !user && otp_service_provider === "firebase";
      if (user) {
        await deleteUser(user);
      } else if (needsOtpVerification) {
        setIsDeleteAccount(false);
        setIsVerifyOtpBeforeDelete(true);
        return;
      }
      await deleteUserApi.deleteUser();
      logoutSuccess();
      toast.success(t("userDeleteSuccess"));
      setIsDeleteAccount(false);
      if (pathname !== "/") {
        navigate("/");
      }
    } catch (error) {
      console.error("Error deleting user:", error.message);
      const isMobileLogin = userData?.type === "phone";
      if (error.code === "auth/requires-recent-login" || error.message?.includes("CREDENTIAL_TOO_OLD_LOGIN_AGAIN")) {
        if (isMobileLogin) {
          setIsDeleteAccount(false);
          setIsVerifyOtpBeforeDelete(true);
          return;
        }
        logoutSuccess();
        toast.error(t("deletePop"));
        setIsDeleteAccount(false);
      }
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <>
      <div className="flex flex-col gap-4 py-6 px-4 h-full">
        <CustomLink
          href="/profile"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/profile" ? "profileActiveTab" : ""
            }`}
        >
          <FiUser size={24} />
          <span>{t("profile")}</span>
        </CustomLink>
        <CustomLink
          href="/notifications"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/notifications" ? "profileActiveTab" : ""
            }`}
        >
          <IoMdNotificationsOutline size={24} />
          <span>{t("notifications")}</span>
        </CustomLink>
        <CustomLink
          href="/chat"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/chat" ? "profileActiveTab" : ""
            }`}
        >
          <BiChat size={24} />
          <span>{t("chat")}</span>
        </CustomLink>
        <CustomLink
          href="/user-subscription"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/user-subscription" ? "profileActiveTab" : ""
            }`}
        >
          <BiDollarCircle size={24} />
          <span>{t("subscription")}</span>
        </CustomLink>
        <CustomLink
          href="/my-ads"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/my-ads" ? "profileActiveTab" : ""
            }`}
        >
          <LiaAdSolid size={24} />
          <span>{t("myAds")}</span>
        </CustomLink>
        <CustomLink
          href="/favorites"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/favorites" ? "profileActiveTab" : ""
            }`}
        >
          <LuHeart size={24} />
          <span>{t("favorites")}</span>
        </CustomLink>
        <CustomLink
          href="/transactions"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/transactions" ? "profileActiveTab" : ""
            }`}
        >
          <BiReceipt size={24} />
          <span>{t("transaction")}</span>
        </CustomLink>
        <CustomLink
          href="/reviews"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/reviews" ? "profileActiveTab" : ""
            }`}
        >
          <MdOutlineRateReview size={24} />
          <span>{t("myReviews")}</span>
        </CustomLink>
        <CustomLink
          href="/job-applications"
          className={`flex items-center gap-1 py-2 px-4 ${pathname === "/job-applications" ? "profileActiveTab" : ""
            }`}
        >
          <MdWorkOutline size={24} />
          <span>{t("jobApplications")}</span>
        </CustomLink>

        <button
          onClick={() => setIsLogout(true)}
          className="flex items-center gap-1 py-2 px-4"
        >
          <RiLogoutCircleLine size={24} />
          <span>{t("signOut")}</span>
        </button>
        <button
          onClick={() => setIsDeleteAccount(true)}
          className="flex items-center gap-1 py-2 px-4 text-destructive"
        >
          <BiTrashAlt size={24} />
          <span>{t("deleteAccount")}</span>
        </button>
      </div>

      {/* Logout Alert Dialog */}
      <ReusableAlertDialog
        open={IsLogout}
        onCancel={() => setIsLogout(false)}
        onConfirm={handleLogout}
        title={t("confirmLogout")}
        description={t("areYouSureToLogout")}
        cancelText={t("cancel")}
        confirmText={t("yes")}
        confirmDisabled={IsLoggingOut}
      />

      {/* Delete Account Alert Dialog */}
      <ReusableAlertDialog
        open={IsDeleteAccount}
        onCancel={() => setIsDeleteAccount(false)}
        onConfirm={handleDeleteAcc}
        title={t("areYouSure")}
        description={
          <ul className="list-disc list-inside mt-2">
            <li>{t("adsAndTransactionWillBeDeleted")}</li>
            <li>{t("accountsDetailsWillNotRecovered")}</li>
            <li>{t("subWillBeCancelled")}</li>
            <li>{t("savedMesgWillBeLost")}</li>
          </ul>
        }
        cancelText={t("cancel")}
        confirmText={t("yes")}
        confirmDisabled={IsDeleting}
      />
      <DeleteAccountVerifyOtpModal
        isOpen={IsVerifyOtpBeforeDelete}
        setIsOpen={setIsVerifyOtpBeforeDelete}
        key={IsVerifyOtpBeforeDelete}
        pathname={pathname}
        navigate={navigate}
      />
    </>
  );
};

export default ProfileSidebar;
