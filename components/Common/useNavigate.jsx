"use client";
import { useRouter } from "next/navigation";
import { useLangFromSearchParams } from "./useLangFromSearchParams";

export const useNavigate = () => {
  const router = useRouter();
  const currentLangCode = useLangFromSearchParams()
  const defaultLangCode = process.env.NEXT_PUBLIC_DEFAULT_LANGUAGE;

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
