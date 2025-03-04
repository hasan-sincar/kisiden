"use client";
import BreadcrumbComponent from "@/components/Breadcrumb/BreadcrumbComponent";
import { store } from "@/redux/store";
import { t } from "@/utils";

const AboutUs = () => {
  const settingsData = store.getState().Settings?.data;
  const aboutUs = settingsData?.data?.about_us;

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
