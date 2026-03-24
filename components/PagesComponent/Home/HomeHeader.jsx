"use client";
import LanguageDropdown from "@/components/Common/LanguageDropdown";
import {
  getIsFreAdListing,
  getOtpServiceProvider,
  settingsData,
} from "@/redux/reducer/settingSlice";
import { t, truncate } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import { useSelector } from "react-redux";
import { GrLocation } from "react-icons/gr";
import HomeMobileMenu from "./HomeMobileMenu.jsx";
import MailSentSuccessModal from "@/components/Auth/MailSentSuccessModal.jsx";
import { useEffect, useState } from "react";
import {
  getIsLoggedIn,
  logoutSuccess,
  userSignUpData,
} from "@/redux/reducer/authSlice.js";
import ProfileDropdown from "./ProfileDropdown.jsx";
import { toast } from "sonner";
import FirebaseData from "@/utils/Firebase.js";
import { IoIosAddCircleOutline } from "react-icons/io";
import dynamic from "next/dynamic";
import {
  getIsLoginModalOpen,
  setIsLoginOpen,
} from "@/redux/reducer/globalStateSlice.js";
import ReusableAlertDialog from "@/components/Common/ReusableAlertDialog";
import { deleteUserApi, getLimitsApi, logoutApi } from "@/utils/api.js";
import { useMediaQuery } from "usehooks-ts";
import UnauthorizedModal from "@/components/Auth/UnauthorizedModal.jsx";
import CustomImage from "@/components/Common/CustomImage.jsx";
import { Loader2 } from "lucide-react";
import { useNavigate } from "@/components/Common/useNavigate.jsx";
import { usePathname } from "next/navigation.js";
import { Skeleton } from "@/components/ui/skeleton.jsx";
import HeaderCategories from "./HeaderCategories.jsx";
import { deleteUser, getAuth } from "firebase/auth";
import DeleteAccountVerifyOtpModal from "@/components/Auth/DeleteAccountVerifyOtpModal.jsx";
import useGetCategories from "@/components/Layout/useGetCategories.jsx";
import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams.jsx";
import PackageRequiredModal from "./PackageRequiredModal.jsx";
import { getCityData } from "@/redux/reducer/locationSlice.js";

const Search = dynamic(() => import("./Search.jsx"), {
  ssr: false,
});
const LoginModal = dynamic(() => import("@/components/Auth/LoginModal.jsx"), {
  ssr: false,
});
const RegisterModal = dynamic(
  () => import("@/components/Auth/RegisterModal.jsx"),
  {
    ssr: false,
  }
);
const LocationModal = dynamic(
  () => import("@/components/Location/LocationModal.jsx"),
  {
    ssr: false,
  }
);

const HeaderCategoriesSkeleton = () => {
  return (
    <div className="container">
      <div className="py-1.5 border-b">
        <Skeleton className="w-full h-[40px]" />
      </div>
    </div>
  );
};

const HomeHeader = () => {
  // 📦 Framework & Firebase
  const { navigate } = useNavigate();
  const { signOut } = FirebaseData();
  const pathname = usePathname();

  // 🔌 Redux State (via useSelector)

  // User & Auth
  const userData = useSelector(userSignUpData);
  const IsLoggedin = useSelector(getIsLoggedIn);
  const IsLoginOpen = useSelector(getIsLoginModalOpen);
  const otp_service_provider = useSelector(getOtpServiceProvider);


  // Ads & Categories
  // const isCategoryLoading = useSelector(getIsCatLoading);
  // const cateData = useSelector(CategoryData);
  const { getCategories, cateData, isCatLoading: isCategoryLoading } = useGetCategories();
  const IsFreeAdListing = useSelector(getIsFreAdListing);

  // Location
  const cityData = useSelector(getCityData);

  // Language & Settings
  const langCode = useLangFromSearchParams();
  const settings = useSelector(settingsData);

  // 🎛️ Local UI State (via useState)

  // Modals
  const [IsRegisterModalOpen, setIsRegisterModalOpen] = useState(false);
  const [IsLocationModalOpen, setIsLocationModalOpen] = useState(false);
  const [IsVerifyOtpBeforeDelete, setIsVerifyOtpBeforeDelete] = useState(false);

  // Auth State
  const [IsLogout, setIsLogout] = useState(false);
  const [IsLoggingOut, setIsLoggingOut] = useState(false);

  // Profile
  const [IsUpdatingProfile, setIsUpdatingProfile] = useState(false);

  // Ad Listing
  const [IsAdListingClicked, setIsAdListingClicked] = useState(false);
  const [IsPackageRequired, setIsPackageRequired] = useState(false);

  // Email Status
  const [IsMailSentSuccess, setIsMailSentSuccess] = useState(false);

  // 📱 Media Query
  const isLargeScreen = useMediaQuery("(min-width: 992px)");

  //delete account state
  const [manageDeleteAccount, setManageDeleteAccount] = useState({
    IsDeleteAccount: false,
    IsDeleting: false,
  });


  useEffect(() => {
    getCategories(1);
  }, [langCode]);


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
        // avoid redirect if already on home page otherwise router.push triggering server side api calls
        if (pathname !== "/") {
          navigate("/");
        }
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log("Failed to log out", error);
    } finally {
      setIsLoggingOut(false);
    }
  };

  const handleAdListing = async () => {
    if (!IsLoggedin) {
      setIsLoginOpen(true);
      return;
    }
    if (!userData?.name || !userData?.email) {
      setIsUpdatingProfile(true);
      return;
    }

    if (IsFreeAdListing) {
      navigate("/ad-listing");
      return;
    }
    try {
      setIsAdListingClicked(true);
      const res = await getLimitsApi.getLimits({
        package_type: "item_listing",
      });
      if (res?.data?.error === false) {
        navigate("/ad-listing");
      } else {
        setIsPackageRequired(true);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsAdListingClicked(false);
    }
  };

  const handleUpdateProfile = () => {
    setIsUpdatingProfile(false);
    navigate("/profile");
  };

  const locationText =
    cityData?.address_translated || cityData?.formattedAddress;



  const handleDeleteAcc = async () => {
    try {
      setManageDeleteAccount((prev) => ({ ...prev, IsDeleting: true }));
      const auth = getAuth();
      const user = auth.currentUser;
      const isMobileLogin = userData?.type == "phone";
      const needsOtpVerification = isMobileLogin && !user && otp_service_provider === "firebase";
      if (user) {
        await deleteUser(user);
      } else if (needsOtpVerification) {
        setManageDeleteAccount((prev) => ({ ...prev, IsDeleteAccount: false }));
        setIsVerifyOtpBeforeDelete(true);
        return;
      }
      await deleteUserApi.deleteUser();
      logoutSuccess();
      toast.success(t("userDeleteSuccess"));
      setManageDeleteAccount((prev) => ({ ...prev, IsDeleteAccount: false }));
      // avoid redirect if already on home page otherwise router.push triggering server side api calls
      if (pathname !== "/") {
        navigate("/");
      }
    } catch (error) {
      console.error("Error deleting user:", error.message);
      const isMobileLogin = userData?.type === "phone";
      if (error.code === "auth/requires-recent-login" || error.message?.includes("CREDENTIAL_TOO_OLD_LOGIN_AGAIN")) {
        if (isMobileLogin) {
          setManageDeleteAccount((prev) => ({
            ...prev,
            IsDeleteAccount: false, // close delete modal
          }));
          setIsVerifyOtpBeforeDelete(true); // open OTP screen
          return;
        }
        logoutSuccess();
        toast.error(t("deletePop"));
        setManageDeleteAccount((prev) => ({ ...prev, IsDeleteAccount: false }));
      }
    } finally {
      setManageDeleteAccount((prev) => ({ ...prev, IsDeleting: false }));
    }
  };

  return (
    <>
      <header className="py-5 border-b">
        <nav className="container">
          <div className="space-between">
            <CustomLink href="/">
              <CustomImage
                src={settings?.header_logo}
                alt="logo"
                width={195}
                height={52}
                className="w-full h-[52px] object-contain ltr:object-left rtl:object-right max-w-[195px]"
              />
            </CustomLink>
            {/* desktop category search select */}

            {isLargeScreen && (
              <div className="flex items-center border leading-none rounded">
                <Search />
              </div>
            )}

            <button
              className="hidden lg:flex items-center gap-1"
              onClick={() => setIsLocationModalOpen(true)}
            >
              <GrLocation
                size={16}
                className="flex-shrink-0"
                title={locationText ? locationText : t("addLocation")}
              />
              <p
                className="hidden xl:block text-sm"
                title={locationText ? locationText : t("addLocation")}
              >
                {locationText
                  ? truncate(locationText, 12)
                  : truncate(t("addLocation"), 12)}
              </p>
            </button>

            <div className="hidden lg:flex items-center gap-2">
              {IsLoggedin ? (
                <ProfileDropdown
                  setIsLogout={setIsLogout}
                  IsLogout={IsLogout}
                />
              ) : (
                <>
                  <button
                    onClick={() => setIsLoginOpen(true)}
                    title={t("login")}
                  >
                    {truncate(t("login"), 12)}
                  </button>
                  <span className="border-l h-6 self-center"></span>
                  <button
                    onClick={() => setIsRegisterModalOpen(true)}
                    title={t("register")}
                  >
                    {truncate(t("register"), 12)}
                  </button>
                </>
              )}

              <button
                className="bg-primary px-2 xl:px-4 py-2 items-center text-white rounded-md  flex gap-1"
                disabled={IsAdListingClicked}
                onClick={handleAdListing}
                title={t("adListing")}
              >
                {IsAdListingClicked ? (
                  <Loader2 size={18} className="animate-spin" />
                ) : (
                  <IoIosAddCircleOutline size={18} />
                )}

                <span className="hidden xl:inline">
                  {truncate(t("adListing"), 12)}
                </span>
              </button>

              <LanguageDropdown />
            </div>
            <HomeMobileMenu
              setIsLocationModalOpen={setIsLocationModalOpen}
              setIsRegisterModalOpen={setIsRegisterModalOpen}
              setIsLogout={setIsLogout}
              locationText={locationText}
              handleAdListing={handleAdListing}
              IsAdListingClicked={IsAdListingClicked}
              setManageDeleteAccount={setManageDeleteAccount}
            />
          </div>

          {!isLargeScreen && (
            <div className="flex items-center border leading-none rounded mt-2">
              <Search />
            </div>
          )}
        </nav>
      </header>
      {isCategoryLoading && !cateData.length ? (
        <HeaderCategoriesSkeleton />
      ) : (
        cateData &&
        cateData.length > 0 && <HeaderCategories cateData={cateData} />
      )}

      <LoginModal
        key={IsLoginOpen}
        IsLoginOpen={IsLoginOpen}
        setIsRegisterModalOpen={setIsRegisterModalOpen}
      />

      <RegisterModal
        setIsMailSentSuccess={setIsMailSentSuccess}
        IsRegisterModalOpen={IsRegisterModalOpen}
        setIsRegisterModalOpen={setIsRegisterModalOpen}
        key={`${IsRegisterModalOpen}-register-modal`}
      />
      <MailSentSuccessModal
        IsMailSentSuccess={IsMailSentSuccess}
        setIsMailSentSuccess={setIsMailSentSuccess}
      />

      {/* Reusable Alert Dialog for Logout */}
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

      {/* Reusable Alert Dialog for Updating Profile */}
      <ReusableAlertDialog
        open={IsUpdatingProfile}
        onCancel={() => setIsUpdatingProfile(false)}
        onConfirm={handleUpdateProfile}
        title={t("updateProfile")}
        description={t("youNeedToUpdateProfile")}
        confirmText={t("yes")}
      />

      {!isLargeScreen && (
        <ReusableAlertDialog
          open={manageDeleteAccount?.IsDeleteAccount}
          onCancel={() =>
            setManageDeleteAccount((prev) => ({
              ...prev,
              IsDeleteAccount: false,
            }))
          }
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
          confirmDisabled={manageDeleteAccount?.IsDeleting}
        />
      )}

      <LocationModal
        key={`${IsLocationModalOpen}-location-modal`}
        IsLocationModalOpen={IsLocationModalOpen}
        setIsLocationModalOpen={setIsLocationModalOpen}
      />
      <UnauthorizedModal />
      <PackageRequiredModal
        open={IsPackageRequired}
        onClose={() => setIsPackageRequired(false)}
      />
      <DeleteAccountVerifyOtpModal
        isOpen={IsVerifyOtpBeforeDelete}
        setIsOpen={setIsVerifyOtpBeforeDelete}
        key={`${IsVerifyOtpBeforeDelete}-delete-account-verify-otp-modal`}
        pathname={pathname}
        navigate={navigate}
      />
    </>
  );
};

export default HomeHeader;
