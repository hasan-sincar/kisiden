"use client";
import { useEffect, useState } from "react";
import MainHeader from "./MainHeader";
import Footer from "./Footer";
import Loader from "@/components/Loader/Loader";
import { settingsData, settingsSucess } from "@/redux/reuducer/settingSlice";
import { settingsApi } from "@/utils/api";
import { useDispatch, useSelector } from "react-redux";
import { usePathname, useRouter } from "next/navigation";
import ScrollToTopButton from "./ScrollToTopButton";
import {
  getKilometerRange,
  setIsBrowserSupported,
  setKilometerRange,
} from "@/redux/reuducer/locationSlice";
import { protectedRoutes } from "@/app/routes/routes";
import Image from "next/image";
import UnderMaitenance from "../../../public/assets/something_went_wrong.svg";
import { getIsLoggedIn } from "@/redux/reuducer/authSlice";
import PushNotificationLayout from "../firebaseNotification/PushNotificationLayout";
import { CurrentLanguageData } from "@/redux/reuducer/languageSlice";
import { getIsVisitedLandingPage, setIsVisitedLandingPage } from "@/redux/reuducer/globalStateSlice";


const Layout = ({ children }) => {
  const pathname = usePathname();
  const dispatch = useDispatch();
  const data = useSelector(settingsData);
  const lang = useSelector(CurrentLanguageData);
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const requiresAuth = protectedRoutes.some((route) => route.test(pathname));
  const appliedRange = useSelector(getKilometerRange);
  const IsLoggedIn = useSelector(getIsLoggedIn);
  const IsVisitedLandingPage = useSelector(getIsVisitedLandingPage);
  const handleNotificationReceived = (data) => {
    console.log("notification received");
  };

  useEffect(() => {
    handleRouteAccess();
  }, [pathname, IsLoggedIn]);

  const handleRouteAccess = () => {
    if (requiresAuth && !IsLoggedIn) {
      router.push("/");
    }
  };

  useEffect(() => {
    if (lang && lang.rtl === true) {
      document.documentElement.dir = "rtl";
    } else {
      document.documentElement.dir = "ltr";
    }
  }, [lang]);

  useEffect(() => {
    const getSystemSettings = async () => {
      try {
        const response = await settingsApi.getSettings({
          type: "", // or remove this line if you don't need to pass the "type" parameter
        });
        const data = response.data;
        dispatch(settingsSucess({ data }));
        const min_range = Number(data?.data.min_length);
        const max_range = Number(data?.data.max_length);

        if (appliedRange < min_range) {
          dispatch(setKilometerRange(min_range));
        } else if (appliedRange > max_range) {
          dispatch(setKilometerRange(max_range));
        }
        document.documentElement.style.setProperty(
          "--primary-color",
          data?.data?.web_theme_color
        );

        const LandingPage = Number(data?.data?.show_landing_page);
        if (LandingPage === 1 && pathname === "/" && !IsVisitedLandingPage) {
          router.push("/home");
          dispatch(setIsVisitedLandingPage(true));
        }

      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsLoading(false);
      }
    };

    const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);
    if (isSafari) {
      dispatch(setIsBrowserSupported(false));
    }
    getSystemSettings();
  }, []);


  return (
    <>
      {isLoading ? (
        <Loader />
      ) : (
        <>
          {Number(data?.data?.maintenance_mode) === 1 ? (
            <div className="underMaitenance">
              <Image src={UnderMaitenance} height={255} width={255} />
              <p className="maintenance_label">
                {t('underMaintenance')}
              </p>
            </div>
          ) : pathname === "/chat" ? (
            <>
              <MainHeader />
              {children}
              <Footer />
            </>
          ) : (
            <PushNotificationLayout
              onNotificationReceived={handleNotificationReceived}
            >
              <MainHeader />
              {children}
              <Footer />
            </PushNotificationLayout>
          )}
          <ScrollToTopButton />
        </>
      )}
    </>
  );
};

export default Layout;
