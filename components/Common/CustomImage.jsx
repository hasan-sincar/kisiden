"use client";

import { getPlaceholderImage } from "@/redux/reducer/settingSlice";
import Image from "next/image";
import { useState } from "react";
import { useSelector } from "react-redux";

const CustomImage = ({ src, alt, loading = "lazy", ...props }) => {
  const placeholderImage = useSelector(getPlaceholderImage);
  const fallback = "/assets/Transperant_Placeholder.png";
  // Initial source can be string OR object (StaticImageData)
  const initialSrc =
    (src && (typeof src === "string" ? src.trim() : src)) ||
    (placeholderImage && placeholderImage.trim?.()) ||
    fallback;

  const [imgSrc, setImgSrc] = useState(initialSrc);

  const handleError = () => {
    if (
      imgSrc !== placeholderImage &&
      typeof placeholderImage === "string" &&
      placeholderImage.trim()
    ) {
      setImgSrc(placeholderImage);
    } else if (imgSrc !== fallback) {
      setImgSrc(fallback);
    }
  };

  return (
    <Image
      src={imgSrc}
      alt={alt}
      onError={handleError}
      loading={loading} // Dynamic loading: defaults to "lazy" if not provided
      {...props} // width, height, className etc can still be passed
    />
  );
};

export default CustomImage;
