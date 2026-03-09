"use client";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import { getDefaultLanguageCode } from "@/redux/reducer/settingSlice";
import { useRouter } from "next/navigation";
import { useSelector } from "react-redux";

export const useNavigate = () => {
  const router = useRouter();
  const currentLangCode = useSelector(getCurrentLangCode);
  const defaultLangCode = useSelector(getDefaultLanguageCode);

  const langCode = currentLangCode || defaultLangCode;

  const navigate = (path, options = {}) => {
    if (path.includes("?")) {
      // Path already has query parameters, add lang parameter
      const langParam = langCode ? `&lang=${langCode}` : "";
      router.push(`${path}${langParam}`, options);
    } else {
      // Path has no query parameters, add lang parameter with ?
      const langParam = langCode ? `?lang=${langCode}` : "";
      router.push(`${path}${langParam}`, options);
    }
  };

  return { navigate };
};
