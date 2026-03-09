"use client";
import { useEffect, useState } from "react";
import { allItemApi, getMyItemsApi, setItemTotalClickApi } from "@/utils/api";
import ProductFeature from "./ProductFeature";
import ProductDescription from "./ProductDescription";
import ProductDetailCard from "./ProductDetailCard";
import SellerDetailCard from "./SellerDetailCard";
import ProductLocation from "./ProductLocation";
import AdsReportCard from "./AdsReportCard";
import SimilarProducts from "./SimilarProducts";
import MyAdsListingDetailCard from "./MyAdsListingDetailCard";
import AdsStatusChangeCards from "./AdsStatusChangeCards";
import { usePathname, useSearchParams } from "next/navigation";
import Layout from "@/components/Layout/Layout";
import ProductGallery from "./ProductGallery";
import {
  getFilteredCustomFields,
  getYouTubeVideoId,
  t,
  truncate,
} from "@/utils";
import PageLoader from "@/components/Common/PageLoader";
import OpenInAppDrawer from "@/components/Common/OpenInAppDrawer";
import { useDispatch, useSelector } from "react-redux";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import { setBreadcrumbPath } from "@/redux/reducer/breadCrumbSlice";
import MakeFeaturedAd from "./MakeFeaturedAd";
import RenewAd from "./RenewAd";
import AdEditedByAdmin from "./AdEditedByAdmin";
import NoData from "@/components/EmptyStates/NoData";

const ProductDetails = ({ slug }) => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const dispatch = useDispatch();
  const pathName = usePathname();
  const searchParams = useSearchParams();
  const isShare = searchParams.get("share") == "true" ? true : false;
  const isMyListing = pathName?.startsWith("/my-listing") ? true : false;
  const [productDetails, setProductDetails] = useState(null);
  const [galleryImages, setGalleryImages] = useState([]);
  const [status, setStatus] = useState("");
  const [videoData, setVideoData] = useState({
    url: "",
    thumbnail: "",
  });
  const [isLoading, setIsLoading] = useState(false);
  const [isOpenInApp, setIsOpenInApp] = useState(false);

  const IsShowFeaturedAd =
    isMyListing &&
    !productDetails?.is_feature &&
    productDetails?.status === "approved";

  const isMyAdExpired = isMyListing && productDetails?.status === "expired";
  const isEditedByAdmin =
    isMyListing && productDetails?.is_edited_by_admin === 1;

  useEffect(() => {
    fetchProductDetails();
  }, [CurrentLanguage?.id]);

  useEffect(() => {
    if (window.innerWidth <= 768 && !isMyListing && isShare) {
      setIsOpenInApp(true);
    }
  }, []);

  const fetchMyListingDetails = async (slug) => {
    const response = await getMyItemsApi.getMyItems({ slug });
    const product = response?.data?.data?.data?.[0];
    if (!product) throw new Error("My listing product not found");
    setProductDetails(product);
    const videoLink = product?.video_link;
    if (videoLink) {
      const videoId = getYouTubeVideoId(videoLink);
      const thumbnail = videoId
        ? `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`
        : "";
      setVideoData((prev) => ({ ...prev, url: videoLink, thumbnail }));
    }

    const galleryImages =
      product?.gallery_images?.map((image) => image?.image) || [];
    setGalleryImages([product?.image, ...galleryImages]);
    setStatus(product?.status);
    dispatch(
      setBreadcrumbPath([
        {
          name: t("myAds"),
          slug: "/my-ads",
        },
        {
          name: truncate(product?.translated_item?.name || product?.name, 80),
        },
      ])
    );
  };
  const incrementViews = async (item_id) => {
    try {
      if (!item_id) {
        console.error("Invalid item_id for incrementViews");
        return;
      }
      const res = await setItemTotalClickApi.setItemTotalClick({ item_id });
    } catch (error) {
      console.error("Error incrementing views:", error);
    }
  };

  const fetchPublicListingDetails = async (slug) => {
    const response = await allItemApi.getItems({ slug });
    const product = response?.data?.data?.data?.[0];

    if (!product) throw new Error("Public listing product not found");
    setProductDetails(product);
    const videoLink = product?.video_link;
    if (videoLink) {
      setVideoData((prev) => ({ ...prev, url: videoLink }));
      const videoId = getYouTubeVideoId(videoLink);
      const thumbnail = videoId
        ? `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`
        : "";
      setVideoData((prev) => ({ ...prev, thumbnail }));
    }

    const galleryImages =
      product?.gallery_images?.map((image) => image?.image) || [];
    setGalleryImages([product?.image, ...galleryImages]);
    await incrementViews(product?.id);
  };

  const fetchProductDetails = async () => {
    try {
      setIsLoading(true);
      if (isMyListing) {
        await fetchMyListingDetails(slug);
      } else {
        await fetchPublicListingDetails(slug);
      }
    } catch (error) {
      console.error("Failed to fetch product details:", error);
      // You can also show a toast or error message here
    } finally {
      setIsLoading(false);
    }
  };

  const filteredFields = getFilteredCustomFields(
    productDetails?.all_translated_custom_fields,
    CurrentLanguage?.id
  );

  return (
    <Layout>
      {isLoading ? (
        <PageLoader />
      ) : productDetails ? (
        <>
          {isMyListing ? (
            <BreadCrumb />
          ) : (
            <BreadCrumb
              title2={truncate(
                productDetails?.translated_item?.name || productDetails?.name,
                80
              )}
            />
          )}
          <div className="container mt-8">
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-7 mt-6">
              <div className="col-span-1 lg:col-span-8">
                <div className="flex flex-col gap-7">
                  <ProductGallery
                    galleryImages={galleryImages}
                    videoData={videoData}
                  />

                  {IsShowFeaturedAd && (
                    <MakeFeaturedAd
                      item_id={productDetails?.id}
                      setProductDetails={setProductDetails}
                    />
                  )}

                  {filteredFields.length > 0 && (
                    <ProductFeature filteredFields={filteredFields} />
                  )}
                  <ProductDescription productDetails={productDetails} />
                </div>
              </div>
              <div className="flex flex-col col-span-1 lg:col-span-4 gap-7">
                {isMyListing ? (
                  <MyAdsListingDetailCard productDetails={productDetails} />
                ) : (
                  <ProductDetailCard
                    productDetails={productDetails}
                    setProductDetails={setProductDetails}
                  />
                )}

                {!isMyListing && (
                  <SellerDetailCard
                    productDetails={productDetails}
                    setProductDetails={setProductDetails}
                  />
                )}

                {isMyListing && (
                  <AdsStatusChangeCards
                    productDetails={productDetails}
                    setProductDetails={setProductDetails}
                    status={status}
                    setStatus={setStatus}
                  />
                )}

                {isEditedByAdmin && (
                  <AdEditedByAdmin
                    admin_edit_reason={productDetails?.admin_edit_reason}
                  />
                )}

                {isMyAdExpired && (
                  <RenewAd
                    item_id={productDetails?.id}
                    setProductDetails={setProductDetails}
                    currentLanguageId={CurrentLanguage?.id}
                    setStatus={setStatus}
                  />
                )}

                <ProductLocation productDetails={productDetails} />

                {!isMyListing && !productDetails?.is_already_reported && (
                  <AdsReportCard
                    productDetails={productDetails}
                    setProductDetails={setProductDetails}
                  />
                )}
              </div>
            </div>
            {!isMyListing && (
              <SimilarProducts
                productDetails={productDetails}
                key={`similar-products-${CurrentLanguage?.id}`}
              />
            )}
            <OpenInAppDrawer
              isOpenInApp={isOpenInApp}
              setIsOpenInApp={setIsOpenInApp}
            />
          </div>
        </>
      ) : (
        <div className="container mt-8">
          <NoData name={t("oneAdvertisement")} />
        </div>
      )}
    </Layout>
  );
};

export default ProductDetails;
