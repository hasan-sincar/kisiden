"use client";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  CurrentLanguageData,
  setCurrentLanguage,
} from "@/redux/reducer/languageSlice";
import { getCityData, saveCity } from "@/redux/reducer/locationSlice";
import { getIsPaidApi, settingsData } from "@/redux/reducer/settingSlice";
import { isEmptyObject, updateStickyNoteTranslations } from "@/utils";
import { getLanguageApi, getLocationApi } from "@/utils/api";
import {
  setHasFetchedCategories,
  setHasFetchedSystemSettings,
} from "@/utils/getFetcherStatus";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "sonner";
import CustomImage from "./CustomImage";

const LanguageDropdown = () => {
  const IsPaidApi = useSelector(getIsPaidApi);
  const router = useRouter();
  const dispatch = useDispatch();
  const pathname = usePathname();
  const location = useSelector(getCityData);
  const settings = useSelector(settingsData);
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const currentLangCode = CurrentLanguage?.code;
  const languages = settings && settings?.languages;
  const isRTL = CurrentLanguage.rtl;

  const searchParams = useSearchParams();
  const langCode = searchParams?.get("lang");
  const params = new URLSearchParams(searchParams.toString());

  const setDefaultLanguage = async () => {
    try {
      params.set("lang", settings?.default_language.toLowerCase());
      router.push(`${pathname}?${params.toString()}`, { scroll: false });
      const language_code = settings?.default_language;
      const res = await getLanguageApi.getLanguage({
        language_code,
        type: "web",
      });
      if (res?.data?.error === false) {
        dispatch(setCurrentLanguage(res?.data?.data));
        document.documentElement.lang =
          res?.data?.data?.code?.toLowerCase() ||
          settings?.default_language.toLowerCase();
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    }
  };

  useEffect(() => {
    // Check if Redux language is empty or invalid
    if (isEmptyObject(CurrentLanguage)) {
      setDefaultLanguage();
      return;
    }

    // If URL has lang parameter and languages are loaded, check if valid and update if needed
    if (langCode && languages.length > 0) {
      const urlLang = languages.find(
        (lang) => lang.code?.toUpperCase() === langCode.toUpperCase()
      );
      if (
        urlLang &&
        currentLangCode?.toUpperCase() !== urlLang.code.toUpperCase()
      ) {
        getLanguageData(urlLang.code);
        return;
      }
    }

    // Check if current language code is no longer valid (language was removed from settings)
    if (languages && !languages.some((lang) => lang.code === currentLangCode)) {
      setDefaultLanguage();
      return;
    }
    if (!langCode) {
      params.set("lang", currentLangCode);
      router.push(`${pathname}?${params.toString()}`, { scroll: false });
    }
  }, [langCode]);

  const getLanguageData = async (
    language_code = settings?.default_language
  ) => {
    try {
      const res = await getLanguageApi.getLanguage({
        language_code,
        type: "web",
      });
      if (res?.data?.error === false) {
        dispatch(setCurrentLanguage(res?.data?.data));
        getLocationAfterLanguageChange(language_code);
        document.documentElement.lang =
          res?.data?.data?.code?.toLowerCase() || "en";

        setHasFetchedSystemSettings(false);
        setHasFetchedCategories(false);
        updateStickyNoteTranslations();
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    }
  };

  const getLocationAfterLanguageChange = async (language_code) => {
    if (IsPaidApi) {
      return;
    }

    // If no country/state/city/area stored, skip API call
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
      const updatedLocation = {};

      if (location?.country) updatedLocation.country = result?.country;
      if (location?.state) updatedLocation.state = result?.state;
      if (location?.city) updatedLocation.city = result?.city;
      if (location?.area) {
        updatedLocation.area = result?.area;
        updatedLocation.areaId = result?.area_id;
      }
      updatedLocation.lat = location?.lat;
      updatedLocation.long = location?.long;

      // ✅ Dynamically build formattedAddress only with existing parts
      const parts = [];
      if (location?.area) parts.push(result?.area_translation);
      if (location?.city) parts.push(result?.city_translation);
      if (location?.state) parts.push(result?.state_translation);
      if (location?.country) parts.push(result?.country_translation);
      updatedLocation.address_translated = parts.filter(Boolean).join(", ");
      saveCity(updatedLocation);
    }
  };

  const handleLanguageSelect = (id) => {
    const lang = languages?.find((item) => item.id === Number(id));
    if (CurrentLanguage.id === lang.id) {
      return;
    }
    params.set("lang", lang.code.toLowerCase()); // Store language code
    // Push new URL with lang param
    router.push(`${pathname}?${params.toString()}`, { scroll: false });
    getLanguageData(lang?.code);
  };
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="border rounded-full py-2 px-4">
        <div className="flex items-center gap-1">
          <CustomImage
            key={CurrentLanguage?.id}
            src={CurrentLanguage?.image}
            alt={CurrentLanguage?.name || "language"}
            width={20}
            height={20}
            className="rounded-full"
          />
          <span>{CurrentLanguage?.code}</span>
        </div>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        className="min-w-0 max-h-[250px] overflow-y-auto"
        align={isRTL ? "start" : "end"}
      >
        {languages &&
          languages.map((lang) => (
            <DropdownMenuItem
              key={lang?.id}
              onClick={() => handleLanguageSelect(lang.id)}
              className="cursor-pointer"
            >
              <CustomImage
                src={lang?.image}
                alt={lang.name || "english"}
                width={20}
                height={20}
                className="rounded-full"
              />
              <span>{lang.code}</span>
            </DropdownMenuItem>
          ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export default LanguageDropdown;
