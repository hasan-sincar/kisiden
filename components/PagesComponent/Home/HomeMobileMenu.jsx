"use client";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { t } from "@/utils";
import { useState } from "react";
import { GiHamburgerMenu } from "react-icons/gi";
import LanguageDropdown from "../../Common/LanguageDropdown";
import { GrLocation } from "react-icons/gr";
import {
  IoIosAddCircleOutline,
  IoMdNotificationsOutline,
} from "react-icons/io";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import { usePathname } from "next/navigation";
import CustomImage from "@/components/Common/CustomImage";
import { Loader2 } from "lucide-react";
import { useSelector } from "react-redux";
import { userSignUpData } from "@/redux/reducer/authSlice";
import CustomLink from "@/components/Common/CustomLink";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { BiChat, BiDollarCircle, BiReceipt, BiTrashAlt } from "react-icons/bi";
import { LiaAdSolid } from "react-icons/lia";
import { LuHeart } from "react-icons/lu";
import { MdOutlineRateReview, MdWorkOutline } from "react-icons/md";
import { RiLogoutCircleLine } from "react-icons/ri";
import { settingsData } from "@/redux/reducer/settingSlice";
import FilterTree from "@/components/Filter/FilterTree";

const HomeMobileMenu = ({
  setIsLocationModalOpen,
  setIsRegisterModalOpen,
  setIsLogout,
  locationText,
  handleAdListing,
  IsAdListingClicked,
  setManageDeleteAccount,
}) => {
  const UserData = useSelector(userSignUpData);
  const settings = useSelector(settingsData);

  const [isOpen, setIsOpen] = useState(false);

  const pathname = usePathname();

  const showMenu = !!UserData;
  const showCategories = !pathname.startsWith("/ads");

  const openLocationEditModal = () => {
    setIsOpen(false);
    setIsLocationModalOpen(true);
  };

  const handleLogin = () => {
    setIsOpen(false);
    setIsLoginOpen(true);
  };

  const handleRegister = () => {
    setIsOpen(false);
    setIsRegisterModalOpen(true);
  };

  const handleSignOut = () => {
    setIsOpen(false);
    setIsLogout(true);
  };

  const handleDeleteAccount = () => {
    setIsOpen(false);
    setManageDeleteAccount((prev) => ({
      ...prev,
      IsDeleteAccount: true,
    }));
  };

  // All user links
  const navItems = (
    <div className="flex flex-col px-4 pb-4">
      <CustomLink
        href="/notifications"
        className="flex items-center gap-1 py-4"
      >
        <IoMdNotificationsOutline size={24} />
        <span>{t("notifications")}</span>
      </CustomLink>
      <CustomLink href="/chat" className="flex items-center gap-1 py-4">
        <BiChat size={24} />
        <span>{t("chat")}</span>
      </CustomLink>
      <CustomLink
        href="/user-subscription"
        className="flex items-center gap-1 py-4"
      >
        <BiDollarCircle size={24} />
        <span>{t("subscription")}</span>
      </CustomLink>
      <CustomLink href="/my-ads" className="flex items-center gap-1 py-4">
        <LiaAdSolid size={24} />
        <span>{t("myAds")}</span>
      </CustomLink>
      <CustomLink href="/favorites" className="flex items-center gap-1 py-4">
        <LuHeart size={24} />
        <span>{t("favorites")}</span>
      </CustomLink>
      <CustomLink href="/transactions" className="flex items-center gap-1 py-4">
        <BiReceipt size={24} />
        <span>{t("transaction")}</span>
      </CustomLink>
      <CustomLink href="/reviews" className="flex items-center gap-1 py-4">
        <MdOutlineRateReview size={24} />
        <span>{t("myReviews")}</span>
      </CustomLink>
      <CustomLink
        href="/job-applications"
        className="flex items-center gap-1 py-4"
      >
        <MdWorkOutline size={24} />
        <span>{t("jobApplications")}</span>
      </CustomLink>
      <button onClick={handleSignOut} className="flex items-center gap-1 py-4">
        <RiLogoutCircleLine size={24} />
        <span>{t("signOut")}</span>
      </button>
      <button
        onClick={handleDeleteAccount}
        className="flex items-center gap-1 text-destructive py-4"
      >
        <BiTrashAlt size={24} />
        <span>{t("deleteAccount")}</span>
      </button>
    </div>
  );

  return (
    <Sheet open={isOpen} onOpenChange={setIsOpen} className="lg:hidden">
      <SheetTrigger asChild className="lg:hidden">
        <button
          id="hamburg"
          className="text-2xl cursor-pointer border rounded-lg p-1"
        >
          <GiHamburgerMenu size={25} className="text-primary" />
        </button>
      </SheetTrigger>
      <SheetContent className="[&>button:first-child]:hidden] p-0 overflow-y-auto">
        <SheetHeader className="p-4 border-b border">
          <SheetTitle>
            <CustomImage
              src={settings?.header_logo}
              width={195}
              height={92}
              alt="Logo"
              className="w-full h-[52px] object-contain ltr:object-left rtl:object-right max-w-[195px]"
            />
          </SheetTitle>
          <SheetDescription className="sr-only"></SheetDescription>
        </SheetHeader>
        <div className="p-4 flex flex-col gap-4">
          <div className="flex items-center justify-between gap-3">
            {UserData ? (
              <CustomLink href="/profile" className="flex items-center gap-2">
                <CustomImage
                  src={UserData?.profile}
                  width={48}
                  height={48}
                  alt={UserData?.name}
                  className="rounded-full size-12 aspect-square object-cover border"
                  onClick={() => setIsOpen(false)}
                />
                <p
                  className="line-clamp-2"
                  title={UserData?.name}
                  onClick={() => setIsOpen(false)}
                >
                  {UserData?.name}
                </p>
              </CustomLink>
            ) : (
              <div className="flex items-center gap-2">
                <button onClick={handleLogin}>{t("login")}</button>
                <span className="border-l h-6 self-center"></span>
                <button onClick={handleRegister}>{t("register")}</button>
              </div>
            )}
            <div className="flex-shrink-0">
              <LanguageDropdown />
            </div>
          </div>

          <div
            className="flex items-center gap-1 cursor-pointer"
            onClick={openLocationEditModal}
          >
            <GrLocation size={16} className="flex-shrink-0" />
            <p
              className="line-clamp-2"
              title={locationText ? locationText : t("addLocation")}
            >
              {locationText ? locationText : t("addLocation")}
            </p>
          </div>

          <button
            className="flex items-center justify-center gap-2 bg-primary py-2 px-3 text-white rounded-md"
            disabled={IsAdListingClicked}
            onClick={handleAdListing}
          >
            {IsAdListingClicked ? (
              <Loader2 size={18} className="animate-spin" />
            ) : (
              <IoIosAddCircleOutline size={18} />
            )}
            <span>{t("adListing")}</span>
          </button>
        </div>

        {showMenu && showCategories ? (
          <Tabs defaultValue="menu">
            <TabsList className="flex items-center justify-between bg-muted rounded-none">
              <TabsTrigger
                value="menu"
                className="flex-1 data-state-active:bg-primary"
              >
                {t("menu")}
              </TabsTrigger>
              <TabsTrigger
                value="categories"
                className="flex-1 data-state-active:bg-primary"
              >
                {t("multipleCategories")}
              </TabsTrigger>
            </TabsList>

            <TabsContent value="menu">
              {navItems}
            </TabsContent>

            <TabsContent value="categories" className="mt-4 px-4 pb-4">
              <FilterTree />
            </TabsContent>
          </Tabs>
        ) : showMenu ? (
          navItems
        ) : showCategories ? (
          <div className="px-4 pb-4 flex flex-col gap-4">
            <h1 className="font-medium">{t("multipleCategories")}</h1>
            <FilterTree />
          </div>
        ) : null}
      </SheetContent>
    </Sheet>
  );
};

export default HomeMobileMenu;
