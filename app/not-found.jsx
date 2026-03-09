"use client";
import CustomImage from "@/components/Common/CustomImage";
import notFoundImg from "@/public/assets/no_data_found_illustrator.svg";
import { t } from "@/utils";
import Link from "next/link";
import { FaArrowLeft } from "react-icons/fa";

const NotFound = () => {
  return (
    <div className="flex flex-col items-center justify-center h-screen gap-3">
      <CustomImage src={notFoundImg} width={200} height={200} alt="not found" />
      <h3 className="text-2xl font-semibold text-primary text-center">
        {t("pageNotFound")}
      </h3>
      <Link href="/" className="flex items-center gap-2">
        <FaArrowLeft /> {t("back")}
      </Link>
    </div>
  );
};

export default NotFound;
