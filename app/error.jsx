"use client"; // Error components must be Client Components
import { useEffect } from "react";
import somthingWrong from "../public/assets/something_went_wrong.svg";
import { t } from "@/utils";
import { Button } from "@/components/ui/button";
import CustomImage from "@/components/Common/CustomImage";
import { useNavigate } from "@/components/Common/useNavigate";

export default function Error({ error }) {
  const { navigate } = useNavigate();
  useEffect(() => {
    // Log the error to an error reporting service
    console.error(error);
  }, [error]);
  const navigateHome = () => {
    navigate("/");
  };
  return (
    <div className="flex flex-col gap-4 items-center justify-center h-screen">
      <CustomImage
        src={somthingWrong}
        alt="something went wrong"
        width={200}
        height={200}
      />
      <h3 className="text-2xl font-semibold text-primary text-center">
        {t("somthingWentWrong")}
      </h3>
      <div className="flex flex-col gap-2">
        <span>{t("tryLater")}</span>
        <Button variant="outline" onClick={navigateHome}>
          {t("home")}
        </Button>
      </div>
    </div>
  );
}
