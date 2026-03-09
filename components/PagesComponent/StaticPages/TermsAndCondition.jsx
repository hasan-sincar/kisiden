"use client";
import { settingsData } from "@/redux/reducer/settingSlice";
import { useSelector } from "react-redux";
import parse from "html-react-parser";
import Layout from "@/components/Layout/Layout";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import { t } from "@/utils";

const TermsAndCondition = () => {
  const settings = useSelector(settingsData);
  const termsAndCondition = settings?.terms_conditions;

  return (
    <Layout>
      <BreadCrumb title2={t("termsConditions")} />
      <div className="container">
        <div className="max-w-full prose lg:prose-lg py-7">{parse(termsAndCondition || "")}</div>
      </div>
    </Layout>
  );
};

export default TermsAndCondition;
