"use client";
import { useEffect, useState } from "react";
import SellerLsitings from "./SellerLsitings";
import SellerDetailCard from "./SellerDetailCard";
import { getSellerApi } from "@/utils/api";
import { t } from "@/utils";
import SellerRating from "./SellerRating";
import SellerSkeleton from "./SellerSkeleton";
import NoData from "@/components/EmptyStates/NoData";
import Layout from "@/components/Layout/Layout";
import OpenInAppDrawer from "@/components/Common/OpenInAppDrawer";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import { useSelector } from "react-redux";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";

const Seller = ({ id, searchParams }) => {

  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [steps, setSteps] = useState(1);
  const [IsNoUserFound, setIsNoUserFound] = useState(false);

  const [seller, setSeller] = useState(null);
  const [ratings, setRatings] = useState(null);
  const [isSellerDataLoading, setIsSellerDataLoading] = useState(false);

  const [isLoadMoreReview, setIsLoadMoreReview] = useState(false);
  const [reviewHasMore, setReviewHasMore] = useState(false);
  const [reviewCurrentPage, setReviewCurrentPage] = useState(1);

  const [isOpenInApp, setIsOpenInApp] = useState(false);
  const isShare = searchParams?.share == "true" ? true : false;

  useEffect(() => {
    if (window.innerWidth <= 768 && isShare) {
      setIsOpenInApp(true);
    }
  }, []);

  useEffect(() => {
    getSeller(reviewCurrentPage);
  }, []);

  const getSeller = async (page) => {
    if (page === 1) {
      setIsSellerDataLoading(true);
    }
    try {
      const res = await getSellerApi.getSeller({ id: Number(id), page });
      if (res?.data.error && res?.data?.code === 103) {
        setIsNoUserFound(true);
      } else {
        const sellerData = res?.data?.data?.ratings;
        if (page === 1) {
          setRatings(sellerData);
        } else {
          setRatings({
            ...ratings,
            data: [...ratings?.data, ...sellerData?.data],
          });
        }
        setSeller(res?.data?.data?.seller);
        setReviewCurrentPage(res?.data?.data?.ratings?.current_page);
        if (
          res?.data?.data?.ratings?.current_page <
          res?.data?.data?.ratings?.last_page
        ) {
          setReviewHasMore(true);
        }
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsSellerDataLoading(false);
      setIsLoadMoreReview(false);
    }
  };

  const handleSteps = (step) => {
    setSteps(step);
  };

  if (IsNoUserFound) {
    return <NoData name={t("noSellerFound")} />;
  }

  return (
    <Layout>
      {isSellerDataLoading ? (
        <SellerSkeleton steps={steps} />
      ) : (
        <>
          <BreadCrumb title2={seller?.name} />
          <div className="container mx-auto mt-6">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
              <div className="col-span-12 lg:col-span-4">
                <SellerDetailCard seller={seller} ratings={ratings} />
              </div>
              <div className="flex flex-col gap-8 col-span-12 lg:col-span-8">
                <div className="p-4 flex items-center gap-4 bg-muted border rounded-md w-full">
                  <button
                    onClick={() => handleSteps(1)}
                    className={`py-2 px-4 rounded-md ${
                      steps === 1 ? "bg-primary text-white" : ""
                    }`}
                  >
                    {t("liveAds")}
                  </button>
                  <button
                    onClick={() => handleSteps(2)}
                    className={`py-2 px-4 rounded-md ${
                      steps === 2 ? "bg-primary text-white" : ""
                    }`}
                  >
                    {t("reviews")}
                  </button>
                </div>
                {steps === 1 && <SellerLsitings id={id} />}
                {steps === 2 && (
                  <SellerRating
                    ratingsData={ratings}
                    seller={seller}
                    isLoadMoreReview={isLoadMoreReview}
                    reviewHasMore={reviewHasMore}
                    reviewCurrentPage={reviewCurrentPage}
                    getSeller={getSeller}
                  />
                )}
              </div>
            </div>
          </div>
        </>
      )}
      <OpenInAppDrawer
        isOpenInApp={isOpenInApp}
        setIsOpenInApp={setIsOpenInApp}
      />
    </Layout>
  );
};

export default Seller;
