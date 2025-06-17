"use client";
import BreadcrumbComponent from "@/components/Breadcrumb/BreadcrumbComponent";
import { settingsData } from "@/redux/reuducer/settingSlice";
import { t } from "@/utils";
import { useSelector } from "react-redux";

const AboutUs = () => {
  const settings = useSelector(settingsData);
  const aboutUs = settings?.data?.about_us;

  return (
    <section className="aboutus">
      <BreadcrumbComponent title2={t("aboutUs")} />
      <div className="container">
        <div className="page_content">
          <div dangerouslySetInnerHTML={{ __html: aboutUs || "" }} />
        </div>
      </div>
    </section>
  );
};

export default AboutUs;
