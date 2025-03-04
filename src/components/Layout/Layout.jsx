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
  saveCity,
  setIsBrowserSupported,
  setKilometerRange,
} from "@/redux/reuducer/locationSlice";
import { protectedRoutes } from "@/app/routes/routes";
import Swal from "sweetalert2";
import { IsLandingPageOn, getDefaultLatLong, getPlaceApiKey, t } from "@/utils";
import Image from "next/image";
import UnderMaitenance from "../../../public/assets/something_went_wrong.svg";
import axios from "axios";
import { getIsLoggedIn } from "@/redux/reuducer/authSlice";
import PushNotificationLayout from "../firebaseNotification/PushNotificationLayout";

const Layout = ({ children }) => {
  const pathname = usePathname();
  const dispatch = useDispatch();
  const cityData = useSelector((state) => state?.Location?.cityData);
  const data = useSelector(settingsData);
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(true);
  const requiresAuth = protectedRoutes.some((route) => route.test(pathname));
  const appliedRange = useSelector(getKilometerRange);
  const IsLoggedIn = useSelector(getIsLoggedIn);

  const handleNotificationReceived = (data) => {
    console.log("notification received");
  };

  useEffect(() => {
    handleRouteAccess();
  }, [pathname, IsLoggedIn]);

  const handleRouteAccess = () => {
    if (requiresAuth && !IsLoggedIn) {
      router.push("/");
      Swal.fire({
        icon: "error",
        title: t("oops"),
        text: t("loginToAccess"),
        allowOutsideClick: false,
        customClass: {
          confirmButton: "Swal-confirm-buttons",
        },
      });
    }
  };

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
        requestLocationPermission(); // Request location after settings are loaded
      } catch (error) {
        console.error("Error:", error);
      } finally {
        setIsLoading(false);
      }
    };
    getSystemSettings();
  }, []);

  const getLocationWithoutLanding = async (pos) => {
    const placeApiKey = getPlaceApiKey();

    try {
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=${placeApiKey}`
      );
      let city = "";
      let state = "";
      let country = "";

      response.data.results.forEach((result) => {
        const addressComponents = result.address_components;
        const getAddressComponent = (type) => {
          const component = addressComponents.find((comp) =>
            comp.types.includes(type)
          );
          return component ? component.long_name : "";
        };
        if (!city) city = getAddressComponent("locality");
        if (!state) state = getAddressComponent("administrative_area_level_1");
        if (!country) country = getAddressComponent("country");
      });

      const locationData = {
        lat: pos.latitude,
        long: pos.longitude,
        city,
        state,
        country,
      };

      saveCity(locationData);
    } catch (error) {
      console.log(error);
    }
  };

  const requestLocationPermission = () => {
    const isLanding = IsLandingPageOn();
    const letLong = getDefaultLatLong();

    const isSafari = /^((?!chrome|android).)*safari/i.test(navigator.userAgent);

    if (isSafari) {
      dispatch(setIsBrowserSupported(false));
      return;
    }

    const noLocationData =
      cityData?.city === "" &&
      cityData?.state === "" &&
      cityData?.country === "";

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const locationData = {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          };

          if (isLanding === 0 && noLocationData) {
            getLocationWithoutLanding(locationData);
          }
        },
        (error) => {
          if (
            isLanding === 0 &&
            (error.code === 1 || error.code === 2 || error.code === 3) &&
            noLocationData
          ) {
            getLocationWithoutLanding(letLong);
          }
        }
      );
      dispatch(setIsBrowserSupported(true));
    } else {
      console.error("Geolocation is not supported by this browser.");
      dispatch(setIsBrowserSupported(false));
    }
  };

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
                Our website is currently undergoing maintenance and will be
                temporarily unavailable.
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
