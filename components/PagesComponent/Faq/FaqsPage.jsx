"use client";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import { t } from "@/utils";
import { useEffect, useState } from "react";
import { getFaqApi } from "@/utils/api";
import FaqCard from "./FaqCard";
import Layout from "@/components/Layout/Layout";
import { useSelector } from "react-redux";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import PageLoader from "@/components/Common/PageLoader";
import NoData from "@/components/EmptyStates/NoData";

const FaqsPage = () => {
  const [faqs, setFaqs] = useState([]);
  const [loading, setLoading] = useState(false);
  const CurrentLanguage = useSelector(CurrentLanguageData);

  useEffect(() => {
    fetchFaqs();
  }, [CurrentLanguage.id]);

  const fetchFaqs = async () => {
    try {
      setLoading(true);
      const res = await getFaqApi.getFaq();
      setFaqs(res?.data?.data);
    } catch (error) {
      console.log("error", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout>
      <BreadCrumb title2={t("faqs")} />
      {loading ? (
        <PageLoader />
      ) : faqs && faqs?.length > 0 ? (
        <div className="container">
          <div className="flex flex-col gap-6 mt-8">
            <h1 className="text-2xl font-semibold">{t("faqs")}</h1>
            <div className="flex flex-col gap-4 md:gap-8">
              {faqs?.map((faq) => {
                return <FaqCard faq={faq} key={faq?.id} />;
              })}
            </div>
          </div>
        </div>
      ) : (
        <NoData name={t("faqs")} />
      )}
    </Layout>
  );
};

export default FaqsPage;
