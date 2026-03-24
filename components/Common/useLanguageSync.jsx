"use client";
import { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { getLanguageApi, getLocationApi } from "@/utils/api";
import {
  getReduxCurrentLangCode,
  setCurrentLanguage,
} from "@/redux/reducer/languageSlice";
import {
  getCityData,
  saveCity,
} from "@/redux/reducer/locationSlice";
import {
  getDefaultLanguageCode,
  getIsPaidApi,
} from "@/redux/reducer/settingSlice";
import { setIsFetchingLanguage } from "@/redux/reducer/globalStateSlice";

export function useLanguageSync(langCode) {
  const dispatch = useDispatch();
  const currentLangCode = useSelector(getReduxCurrentLangCode);
  const IsPaidApi = useSelector(getIsPaidApi);
  const location = useSelector(getCityData);

  const defaultLanguageCode = useSelector(getDefaultLanguageCode)

  useEffect(() => {
    if (
      langCode &&
      (!currentLangCode ||
        currentLangCode.toLowerCase() !== langCode.toLowerCase())
    ) {
      // 2. Fetch the new language data
      getLanguageData(langCode.toLowerCase());
    }
  }, [langCode]);


  const getLanguageData = async (language_code = defaultLanguageCode) => {
    try {
      dispatch(setIsFetchingLanguage(true))
      const res = await getLanguageApi.getLanguage({
        language_code,
        type: "web",
      });
      if (res?.data?.error === false) {
        dispatch(setCurrentLanguage(res?.data?.data));
        document.documentElement.lang =
          res?.data?.data?.code?.toLowerCase() || "en";
        getLocationAfterLanguageChange(language_code);
      }
    } catch (error) {
      console.error("Error fetching language:", error);
    } finally {
      dispatch(setIsFetchingLanguage(false))
    }
  };

  const getLocationAfterLanguageChange = async (language_code) => {
    if (IsPaidApi) return;
    if (
      !location?.country &&
      !location?.state &&
      !location?.city &&
      !location?.area
    ) {
      return;
    }

    const response = await getLocationApi.getLocation({
      lat: location?.lat,
      lng: location?.long,
      lang: language_code,
    });

    if (response?.data.error === false) {
      const result = response?.data?.data;
      const updatedLocation = { ...location };

      if (location?.country) updatedLocation.country = result?.country;
      if (location?.state) updatedLocation.state = result?.state;
      if (location?.city) updatedLocation.city = result?.city;
      if (location?.area) {
        updatedLocation.area = result?.area;
        updatedLocation.areaId = result?.area_id;
      }

      const parts = [];
      if (location?.area) parts.push(result?.area_translation);
      if (location?.city) parts.push(result?.city_translation);
      if (location?.state) parts.push(result?.state_translation);
      if (location?.country) parts.push(result?.country_translation);
      updatedLocation.address_translated = parts.filter(Boolean).join(", ");
      saveCity(updatedLocation);
    }
  };
}
