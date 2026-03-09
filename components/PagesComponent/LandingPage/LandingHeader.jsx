"use client";
import { t } from "@/utils";
import { useSelector } from "react-redux";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import { settingsData } from "@/redux/reducer/settingSlice";
import LanguageDropdown from "../../Common/LanguageDropdown";
import LandingMobileMenu from "@/components/PagesComponent/LandingPage/LandingMobileMenu";
import { useState, useEffect } from "react";
import CustomImage from "@/components/Common/CustomImage";
import CustomLink from "@/components/Common/CustomLink";

const LandingHeader = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const settings = useSelector(settingsData);
  const [isShowMobileMenu, setIsShowMobileMenu] = useState(false);
  const [activeSection, setActiveSection] = useState("anythingYouWant");

  const handleMobileMenuClose = () => {
    if (isShowMobileMenu) {
      setIsShowMobileMenu(false);
    }
  };

  // Intersection Observer to track which section is currently visible
  useEffect(() => {
    const sections = ["anythingYouWant", "work_process", "faq", "ourBlogs"];
    const observerOptions = {
      root: null,
      rootMargin: "0px", // Trigger when section is 20% from top
      threshold: 0.7,
    };
    const observerCallback = (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          setActiveSection(entry.target.id);
        }
      });
    };
    const observer = new IntersectionObserver(
      observerCallback,
      observerOptions
    );
    // Observe all sections
    sections.forEach((sectionId) => {
      const element = document.getElementById(sectionId);
      if (element) {
        observer.observe(element);
      }
    });
    // Cleanup observer on component unmount
    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <>
      <header className="sticky top-0 z-50 bg-white shadow-xs">
        <nav className="shadow-md">
          <div className="container py-5 lg:flex lg:items-center lg:justify-between">
            <div className="flex w-100 items-center justify-between">
              <CustomImage
                src={settings?.header_logo}
                className="w-full h-[52px] object-contain ltr:object-left rtl:object-right max-w-[195px]"
                alt="logo"
                width={195}
                height={52}
              />

              <LandingMobileMenu
                isOpen={isShowMobileMenu}
                setIsOpen={setIsShowMobileMenu}
                activeSection={activeSection}
              />
            </div>
            <div className="hidden lg:flex gap-6">
              <ul className="flex items-center gap-6">
                <li>
                  <CustomLink
                    href="#anythingYouWant"
                    className={`cursor-pointer transition-all duration-200 ${
                      activeSection === "anythingYouWant"
                        ? "text-primary"
                        : "hover:text-primary"
                    }`}
                  >
                    {t("home")}
                  </CustomLink>
                </li>
                <li>
                  <CustomLink
                    href="#work_process"
                    className={`cursor-pointer transition-all duration-200 ${
                      activeSection === "work_process"
                        ? "text-primary"
                        : "hover:text-primary"
                    }`}
                    onClick={handleMobileMenuClose}
                  >
                    {t("whyChooseUs")}
                  </CustomLink>
                </li>
                <li>
                  <CustomLink
                    href="#faq"
                    className={`cursor-pointer transition-all duration-200 ${
                      activeSection === "faq"
                        ? "text-primary"
                        : "hover:text-primary"
                    }`}
                    onClick={handleMobileMenuClose}
                  >
                    {t("faqs")}
                  </CustomLink>
                </li>
                <li>
                  <CustomLink
                    href="#ourBlogs"
                    className={`cursor-pointer transition-all duration-200 ${
                      activeSection === "ourBlogs"
                        ? "text-primary"
                        : "hover:text-primary"
                    }`}
                    onClick={handleMobileMenuClose}
                  >
                    {t("blog")}
                  </CustomLink>
                </li>
              </ul>
            </div>
            <div className="hidden lg:flex">
              <LanguageDropdown />
            </div>
          </div>
        </nav>
      </header>
    </>
  );
};

export default LandingHeader;
