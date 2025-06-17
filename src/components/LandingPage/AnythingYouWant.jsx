"use client";
import { useState } from "react";
import Image from "next/image";
import Img1 from "../../../public/assets/Image1.svg";
import Img2 from "../../../public/assets/Image2.svg";
import Img3 from "../../../public/assets/Image3.svg";
import Img4 from "../../../public/assets/Image4.svg";
import Img5 from "../../../public/assets/Image5.svg";
import Img6 from "../../../public/assets/Image6.svg";
import { SlLocationPin } from "react-icons/sl";
import { FaArrowRight, FaLocationCrosshairs } from "react-icons/fa6";
import { IoSearchOutline } from "react-icons/io5";
import { placeholderImage, t } from "@/utils";
import { settingsData } from "@/redux/reuducer/settingSlice";
import { useSelector } from "react-redux";
import { CurrentLanguageData } from "@/redux/reuducer/languageSlice";
import LocationModal from "./LocationModal";
import useSearchAutocomplete from "./useSearchAutocomplete";
import { useRouter } from "next/navigation";
import { saveCity } from "@/redux/reuducer/locationSlice";
import toast from "react-hot-toast";
import SearchAutocomplete from "./SearchAutocomplete";
import Link from "next/link";

const AnythingYouWant = () => {

  const router = useRouter();
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const systemSettingsData = useSelector(settingsData);
  const settings = systemSettingsData?.data;
  const [IsLocationModalOpen, setIsLocationModalOpen] = useState(false);
  const saveOnSuggestionClick = false;

  const {
    search,
    handleSearchChange,
    handleInputFocus,
    handleInputBlur,
    handleSuggestionClick,
    autoState,
    KmRange,
    selectedLocation
  } = useSearchAutocomplete(saveOnSuggestionClick);


  const handleSearchLocation = () => {
    const isInvalidLocation =
      KmRange > 0
        ? !selectedLocation?.lat || !selectedLocation?.long
        : !selectedLocation?.areaId && !selectedLocation?.city && !selectedLocation?.state && !selectedLocation?.country;

    if (isInvalidLocation) {
      toast.error(t("pleaseSelectLocation"));
      return;
    }

    saveCity(selectedLocation);
    router.push("/");
  };

  return (
    <>
      <section id="anything_you_want">
        <div className="container">
          <div className="main_wrapper">
            <div className="left_side_images">
              <Image
                src={Img1}
                className="upper_img"
                height={0}
                width={0}
                alt=""
                loading="lazy"
                onErrorCapture={placeholderImage}
              />
              <Image
                src={Img2}
                className="center_img"
                height={0}
                width={0}
                alt=""
                loading="lazy"
                onErrorCapture={placeholderImage}
              />
              <Image
                src={Img3}
                className="down_img"
                height={0}
                width={0}
                alt=""
                loading="lazy"
                onErrorCapture={placeholderImage}
              />
            </div>
            <div className="center_content">
              <div className="main_heading">
                <h1>{t("buySell")} </h1>
                <h1>{t("anythingYouWant")}</h1>
              </div>
              <div className="main_decs">
                <p>
                  {t("discoverEndlessPossibilitiesAt")} {""}{" "}
                  {settings?.company_name} {""} {t("goToMarketplace")}
                </p>
              </div>
              <div className="search_main_div">
                <div className="right_input">
                  <SlLocationPin size={22} />
                  <SearchAutocomplete
                    search={search}
                    handleSearchChange={handleSearchChange}
                    handleInputFocus={handleInputFocus}
                    handleInputBlur={handleInputBlur}
                    autoState={autoState}
                    handleSuggestionClick={handleSuggestionClick}
                  />
                </div>
                <div className="left_buttons">
                  <button
                    className="locate_me"
                    onClick={() => setIsLocationModalOpen(true)}
                  >
                    <FaLocationCrosshairs className="seach_field_icons" />
                  </button>
                  <button className="serach" onClick={handleSearchLocation}>
                    <IoSearchOutline className="seach_field_icons" />
                    <span className="seach_field_labels">{t("search")}</span>
                  </button>
                  <Link href='/' className="ad_listing_btn">
                    <span>Skip this</span>
                    <FaArrowRight className="arrow_right" />
                  </Link>
                </div>
              </div>
              <Link href='/' className="skip_this_btn">
                <span>{t('skipThis')}</span>
                <FaArrowRight className="arrow_right" />
              </Link>
            </div>
            <div className="right_side_images">
              <Image
                src={Img4}
                className="upper_img"
                height={0}
                width={0}
                alt=""
                loading="lazy"
                onErrorCapture={placeholderImage}
              />
              <Image
                src={Img5}
                className="center_img"
                height={0}
                width={0}
                alt=""
                loading="lazy"
                onErrorCapture={placeholderImage}
              />
              <Image
                src={Img6}
                className="down_img"
                height={0}
                width={0}
                alt=""
                loading="lazy"
                onErrorCapture={placeholderImage}
              />
            </div>
          </div>
        </div>
      </section>
      <LocationModal
        key={IsLocationModalOpen}
        IsLocationModalOpen={IsLocationModalOpen}
        OnHide={() => setIsLocationModalOpen(false)}
      />
    </>
  );
};

export default AnythingYouWant;
