"use client";
import Link from "next/link";
import { useLangFromSearchParams } from "./useLangFromSearchParams";

const CustomLink = ({ href, children, ...props }) => {
  const defaultLangCode = process.env.NEXT_PUBLIC_DEFAULT_LANGUAGE;
  const currentLangCode = useLangFromSearchParams()

  const langCode = currentLangCode || defaultLangCode;

  // Split hash (#) safely from href
  const [baseHref, hash = ""] = href?.split("#");

  // Append lang param safely
  const separator = baseHref.includes("?") ? "&" : "?";
  const newHref = `${baseHref}${separator}lang=${langCode}${hash ? `#${hash}` : ""
    }`;

  return (
    <Link href={newHref} {...props}>
      {children}
    </Link>
  );
};

export default CustomLink;
