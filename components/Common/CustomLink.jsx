"use client";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import { getDefaultLanguageCode } from "@/redux/reducer/settingSlice";
import Link from "next/link";
import { useSelector } from "react-redux";

const CustomLink = ({ href, children, ...props }) => {
  const defaultLangCode = useSelector(getDefaultLanguageCode);
  const currentLangCode = useSelector(getCurrentLangCode);

  const langCode = currentLangCode || defaultLangCode;

  // Split hash (#) safely from href
  const [baseHref, hash = ""] = href.split("#");

  // Append lang param safely
  const separator = baseHref.includes("?") ? "&" : "?";
  const newHref = `${baseHref}${separator}lang=${langCode}${
    hash ? `#${hash}` : ""
  }`;

  return (
    <Link href={newHref} {...props}>
      {children}
    </Link>
  );
};

export default CustomLink;
