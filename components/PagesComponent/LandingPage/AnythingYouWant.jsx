"use client";
import { t } from "@/utils";
import { useEffect, useState } from "react";
import { IoSearchOutline } from "react-icons/io5";
import Img1 from "../../../public/assets/Image1.png";
import Img2 from "../../../public/assets/Image2.png";
import Img3 from "../../../public/assets/Image3.png";
import Img4 from "../../../public/assets/Image4.png";
import Img5 from "../../../public/assets/Image5.png";
import Img6 from "../../../public/assets/Image6.png";
import {
  getCityData,
  getIsBrowserSupported,
  getKilometerRange,
  saveCity,
} from "@/redux/reducer/locationSlice";
import { useDispatch, useSelector } from "react-redux";
import LocationModal from "../../Location/LocationModal";
import { toast } from "sonner";
import { FaLocationCrosshairs } from "react-icons/fa6";
import { getCompanyName } from "@/redux/reducer/settingSlice";
import CustomLink from "@/components/Common/CustomLink";
import { ArrowRight } from "lucide-react";
import { setIsVisitedLandingPage } from "@/redux/reducer/globalStateSlice";
import CustomImage from "@/components/Common/CustomImage";
import LandingAdEditSearchAutocomplete from "@/components/Location/LandingAdEditSearchAutocomplete";

const AnythingYouWant = () => {
  const dispatch = useDispatch();
  const LocationData = useSelector(getCityData);
  const companyName = useSelector(getCompanyName);
  const [selectedCity, setSelectedCity] = useState(LocationData);
  const IsBrowserSupported = useSelector(getIsBrowserSupported);
  const [IsLocationModalOpen, setIsLocationModalOpen] = useState(false);
  const KmRange = useSelector(getKilometerRange);

  useEffect(() => {
    dispatch(setIsVisitedLandingPage(true));
  }, []);

  const handleSearchLocation = () => {
    const isInvalidLocation =
      KmRange > 0
        ? !selectedCity?.lat || !selectedCity?.long
        : !selectedCity?.areaId &&
        !selectedCity?.city &&
        !selectedCity?.state &&
        !selectedCity?.country;

    if (isInvalidLocation) {
      toast.error(t("pleaseSelectLocation"));
      return;
    }
    saveCity(selectedCity);
  };

  return (
    <>
      <section
        id="anythingYouWant"
        className="py-28 bg-muted flex items-center justify-center"
      >
        <div className="container relative">
          <div className="flex flex-col items-center gap-6 text-center">
            <div className="flex flex-col items-center font-bold text-4xl lg:text-5xl gap-3 relative">
              <h1 className="flex flex-column items-center relative z-10 after:content-[''] after:absolute after:bg-[#00b2ca] after:h-[40%] after:w-full after:z-[-1] after:bottom-0">
                {t("buySell")}
              </h1>
              <h1>{t("anythingYouWant")}</h1>
            </div>
            <p className="text-sm font-light md:w-1/2">
              {t("discoverEndlessPossibilitiesAt")} {companyName}{" "}
              {t("goToMarketplace")}
            </p>
            <div className="space-between gap-3 rounded border w-full lg:w-[60%] bg-white py-2 ltr:pr-2 rtl:pl-2 relative">
              <LandingAdEditSearchAutocomplete
                saveOnSuggestionClick={false}
                setSelectedLocation={setSelectedCity}
              />
              <div className="flex items-center gap-3">
                {IsBrowserSupported && (
                  <button
                    className="flex items-center gap-2"
                    onClick={() => setIsLocationModalOpen(true)}
                  >
                    <FaLocationCrosshairs size={22} />
                  </button>
                )}
                <button
                  className="flex items-center gap-2 bg-primary px-3 py-[6px] rounded text-white"
                  onClick={handleSearchLocation}
                >
                  <IoSearchOutline size={22} />
                  <span className="hidden md:block">{t("search")}</span>
                </button>
              </div>
              <CustomLink
                href="/"
                className="hidden sm:flex items-center gap-2 text-destructive"
              >
                <span className="whitespace-nowrap">{t("skip")}</span>
                <ArrowRight size={16} className="rtl:scale-x-[-1]" />
              </CustomLink>
            </div>
            <CustomLink
              href="/"
              className="sm:hidden flex items-center gap-2 text-destructive"
            >
              <span className="whitespace-nowrap">{t("skip")}</span>
              <ArrowRight size={16} className="rtl:scale-x-[-1]" />
            </CustomLink>
          </div>
          <CustomImage
            src={Img1}
            className="hidden xl:block absolute xl:-top-[38%] ltr:xl:left-[3%] rtl:xl:right-[3%] xl:w-[110px] rounded-full"
            height={135}
            width={90}
            alt="landing page image 1"
          />
          <CustomImage
            src={Img2}
            className="hidden xl:block absolute xl:top-[38%] ltr:xl:left-[9%] rtl:xl:right-[9%] xl:w-[110px] rounded-full"
            height={135}
            width={90}
            alt="landing page image 2"
          />
          <CustomImage
            src={Img3}
            className="hidden xl:block absolute xl:top-[120%] ltr:xl:left-[3%] rtl:xl:right-[3%] xl:w-[110px] rounded-full"
            height={90}
            width={90}
            alt="landing page image 3"
          />
          <CustomImage
            src={Img4}
            className="hidden xl:block absolute xl:-top-[38%] ltr:xl:right-[3%] rtl:xl:left-[3%] xl:w-[110px] rounded-full"
            height={135}
            width={90}
            alt="landing page image 4"
          />
          <CustomImage
            src={Img5}
            className="hidden xl:block absolute xl:top-[38%] ltr:xl:right-[9%] rtl:xl:left-[9%] xl:w-[110px] rounded-full"
            height={90}
            width={90}
            alt="landing page image 5"
          />
          <CustomImage
            src={Img6}
            className="hidden xl:block absolute xl:top-[109%] ltr:xl:right-[3%] rtl:xl:left-[3%] xl:w-[110px] rounded-full"
            height={0}
            width={0}
            alt="landing page image 6"
          />
        </div>
      </section>
      <LocationModal
        key={`${IsLocationModalOpen}-location-modal`}
        IsLocationModalOpen={IsLocationModalOpen}
        setIsLocationModalOpen={setIsLocationModalOpen}
      />
    </>
  );
};

export default AnythingYouWant;
