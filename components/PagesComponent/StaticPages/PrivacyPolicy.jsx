"use client";

import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import Layout from "@/components/Layout/Layout";
import { settingsData } from "@/redux/reducer/settingSlice";
import { t } from "@/utils";
import parse from "html-react-parser";
import { useSelector } from "react-redux";

const PrivacyPolicy = () => {
  const settings = useSelector(settingsData);
  const privacy = settings?.privacy_policy;

  return (
    <Layout>
      <BreadCrumb title2={t("privacyPolicy")} />
      <div className="container">
        <div className="max-w-full py-7 prose lg:prose-lg">
          {parse(privacy || "")}
        </div>
      </div>
    </Layout>
  );
};

export default PrivacyPolicy;
