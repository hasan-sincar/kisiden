"use client";
import { useEffect, useState } from "react";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import {
  editItemApi,
  getCurrenciesApi,
  getCustomFieldsApi,
  getMyItemsApi,
  getParentCategoriesApi,
} from "@/utils/api";
import {
  filterNonDefaultTranslations,
  getMainDetailsTranslations,
  isValidURL,
  prefillExtraDetails,
  prepareCustomFieldFiles,
  prepareCustomFieldTranslations,
  t,
  validateExtraDetails,
} from "@/utils";
import EditComponentOne from "./EditComponentOne";
import EditComponentTwo from "./EditComponentTwo";
import EditComponentThree from "./EditComponentThree";
import EditComponentFour from "./EditComponentFour";
import { toast } from "sonner";
import Layout from "@/components/Layout/Layout";
import Checkauth from "@/HOC/Checkauth";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import { useSelector } from "react-redux";
import AdSuccessModal from "../AdsListing/AdSuccessModal";
import {
  getDefaultLanguageCode,
  getLanguages,
} from "@/redux/reducer/settingSlice";
import AdLanguageSelector from "../AdsListing/AdLanguageSelector";
import PageLoader from "@/components/Common/PageLoader";
import { isValidPhoneNumber } from "libphonenumber-js/max";

const EditListing = ({ id }) => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [step, setStep] = useState(1);
  const [CreatedAdSlug, setCreatedAdSlug] = useState("");
  const [openSuccessModal, setOpenSuccessModal] = useState(false);
  const [selectedCategoryPath, setSelectedCategoryPath] = useState([]);
  const [customFields, setCustomFields] = useState([]);
  const [uploadedImages, setUploadedImages] = useState([]);
  const [OtherImages, setOtherImages] = useState([]);
  const [Location, setLocation] = useState({});
  const [currencies, setCurrencies] = useState([]);
  const [filePreviews, setFilePreviews] = useState({});
  const [deleteImagesId, setDeleteImagesId] = useState("");
  const [isAdPlaced, setIsAdPlaced] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const languages = useSelector(getLanguages);
  const defaultLanguageCode = useSelector(getDefaultLanguageCode);
  const defaultLangId = languages?.find(
    (lang) => lang.code === defaultLanguageCode
  )?.id;

  const [extraDetails, setExtraDetails] = useState({
    [defaultLangId]: {},
  });
  const [langId, setLangId] = useState(defaultLangId);

  const [translations, setTranslations] = useState({
    [defaultLangId]: {},
  });
  const hasTextbox = customFields.some((field) => field.type === "textbox");

  const defaultDetails = translations[defaultLangId] || {};
  const currentDetails = translations[langId] || {};
  const currentExtraDetails = extraDetails[langId] || {};

  const is_job_category =
    Number(
      selectedCategoryPath[selectedCategoryPath.length - 1]?.is_job_category
    ) === 1;
  const isPriceOptional =
    Number(
      selectedCategoryPath[selectedCategoryPath.length - 1]?.price_optional
    ) === 1;

  useEffect(() => {
    getSingleListingData();
  }, [CurrentLanguage.id]);

  const fetchCategoryPath = async (childCategoryId) => {
    try {
      const categoryResponse =
        await getParentCategoriesApi.getPaymentCategories({
          child_category_id: childCategoryId,
        });
      setSelectedCategoryPath(categoryResponse?.data?.data);
    } catch (error) {
      console.log("Error fetching category path:", error);
    }
  };

  const getCustomFields = async (categoryIds, extraFieldValue) => {
    try {
      const customFieldsRes = await getCustomFieldsApi.getCustomFields({
        category_ids: categoryIds,
      });
      const data = customFieldsRes?.data?.data;
      setCustomFields(data);
      const tempExtraDetails = prefillExtraDetails({
        data,
        languages,
        defaultLangId,
        extraFieldValue,
        setFilePreviews,
      });
      setExtraDetails(tempExtraDetails);
      setLangId(defaultLangId);
    } catch (error) {
      console.log("Error fetching custom fields:", error);
    }
  };

  const getCurrencies = async () => {
    try {
      const res = await getCurrenciesApi.getCurrencies();
      const currenciesData = res?.data?.data || [];
      setCurrencies(currenciesData);
      return currenciesData; // Return the currencies data
    } catch (error) {
      console.log("error", error);
      return [];
    }
  };

  const getSingleListingData = async () => {
    try {
      setIsLoading(true);
      const res = await getMyItemsApi.getMyItems({ id: Number(id) });
      const listingData = res?.data?.data?.data?.[0];

      if (!listingData) {
        throw new Error("Listing not found");
      }
      // Get currencies data directly
      const [_, __, currenciesData] = await Promise.all([
        getCustomFields(
          listingData.all_category_ids,
          listingData?.all_translated_custom_fields
        ),
        fetchCategoryPath(listingData?.category_id),
        getCurrencies(),
      ]);

      setUploadedImages(listingData?.image);
      setOtherImages(listingData?.gallery_images);

      const mainDetailsTranslation = getMainDetailsTranslations(
        listingData,
        languages,
        defaultLangId,
        currenciesData
      );
      setTranslations(mainDetailsTranslation);
      setLocation({
        country: listingData?.country,
        state: listingData?.state,
        city: listingData?.city,
        formattedAddress: listingData?.translated_address,
        lat: listingData?.latitude,
        long: listingData?.longitude,
        area_id: listingData?.area_id ? listingData?.area_id : null,
      });
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleDetailsSubmit = () => {
    if (customFields?.length === 0) {
      setStep(3);
      return;
    }
    setStep(2);
  };

  const handleImageSubmit = () => {
    if (uploadedImages.length === 0) {
      toast.error(t("uploadMainPicture"));
      return;
    }
    setStep(4);
  };

  const handleGoBack = () => {
    if (step == 3 && customFields?.length == 0) {
      setStep((prev) => prev - 2);
    } else {
      setStep((prev) => prev - 1);
    }
  };

  const handleTabClick = (tab) => {
    if (tab === 1) {
      setStep(1);
    } else if (tab === 2) {
      setStep(2);
    } else if (tab === 3) {
      setStep(3);
    } else if (tab === 4) {
      setStep(4);
    }
  };

  const submitExtraDetails = () => {
    setStep(3);
  };

  const SLUG_RE = /^[a-z0-9-]+$/i;
  const isEmpty = (x) => !x || !x.toString().trim();
  const isNegative = (n) => Number(n) < 0;

  const handleFullSubmission = () => {
    const {
      name,
      description,
      price,
      slug,
      contact,
      video_link,
      min_salary,
      max_salary,
      country_code,
    } = defaultDetails;

    if (!name.trim() || !description.trim()) {
      toast.error(t("completeDetails"));
      setStep(1);
      return;
    }

    // ✅ Validate phone number ONLY if user entered one as it is optional
    if (Boolean(contact) && !isValidPhoneNumber(`+${country_code}${contact}`)) {
      toast.error(t("invalidPhoneNumber"));
      return setStep(1);
    }

    if (is_job_category) {
      const min = min_salary ? Number(min_salary) : null;
      const max = max_salary ? Number(max_salary) : null;

      // Salary fields are optional, but validate if provided
      if (min !== null && min < 0) {
        toast.error(t("enterValidSalaryMin"));
        setStep(1);
        return;
      }

      if (max !== null && max < 0) {
        toast.error(t("enterValidSalaryMax"));
        setStep(1);
        return;
      }
      if (min !== null && max !== null) {
        if (min === max) {
          toast.error(t("salaryMinCannotBeEqualMax"));
          return setStep(1);
        }
        if (min > max) {
          toast.error(t("salaryMinCannotBeGreaterThanMax"));
          return setStep(1);
        }
      }
    } else {
      if (!isPriceOptional && isEmpty(price)) {
        toast.error(t("completeDetails"));
        return setStep(1);
      }

      if (!isEmpty(price) && isNegative(price)) {
        toast.error(t("enterValidPrice"));
        return setStep(1);
      }
    }

    if (!isEmpty(slug) && !SLUG_RE.test(slug.trim())) {
      toast.error(t("addValidSlug"));
      return setStep(1);
    }

    if (!isEmpty(video_link) && !isValidURL(video_link)) {
      toast.error(t("enterValidUrl"));
      setStep(1);
      return;
    }

    if (
      customFields.length !== 0 &&
      !validateExtraDetails({
        languages,
        defaultLangId,
        extraDetails,
        customFields,
        filePreviews,
      })
    ) {
      setStep(2);
      return;
    }

    if (uploadedImages.length === 0) {
      toast.error(t("uploadMainPicture"));
      setStep(3);
      return;
    }

    if (
      !Location?.country ||
      !Location?.state ||
      !Location?.city ||
      !Location?.formattedAddress
    ) {
      toast.error(t("pleaseSelectCity"));
      return;
    }
    editAd();
  };

  const editAd = async () => {
    const nonDefaultTranslations = filterNonDefaultTranslations(
      translations,
      defaultLangId
    );
    const customFieldTranslations =
      prepareCustomFieldTranslations(extraDetails);

    const customFieldFiles = prepareCustomFieldFiles(
      extraDetails,
      defaultLangId
    );

    const allData = {
      id: id,
      name: defaultDetails.name,
      slug: defaultDetails.slug.trim(),
      description: defaultDetails?.description,
      price: defaultDetails.price,
      contact: defaultDetails.contact,
      region_code: defaultDetails?.region_code?.toUpperCase() || "",
      video_link: defaultDetails?.video_link,
      // custom_fields: transformedCustomFields,
      image: typeof uploadedImages == "string" ? null : uploadedImages[0],
      gallery_images: OtherImages,
      address: Location?.formattedAddress,
      latitude: Location?.lat,
      longitude: Location?.long,
      custom_field_files: customFieldFiles,
      country: Location?.country,
      state: Location?.state,
      city: Location?.city,
      ...(Location?.area_id ? { area_id: Number(Location?.area_id) } : {}),
      delete_item_image_id: deleteImagesId,
      ...(Object.keys(nonDefaultTranslations).length > 0 && {
        translations: nonDefaultTranslations,
      }),
      ...(defaultDetails?.currency_id && {
        currency_id: defaultDetails?.currency_id,
      }),
      ...(Object.keys(customFieldTranslations).length > 0 && {
        custom_field_translations: customFieldTranslations,
      }),
      // expiry_date: '2025-10-13'
    };

    if (is_job_category) {
      // Only add salary fields if they're provided
      allData.min_salary = defaultDetails.min_salary;
      allData.max_salary = defaultDetails.max_salary;
    } else {
      allData.price = defaultDetails.price;
    }

    try {
      setIsAdPlaced(true);
      const res = await editItemApi.editItem(allData);
      if (res?.data?.error === false) {
        setOpenSuccessModal(true);
        setCreatedAdSlug(res?.data?.data[0]?.slug);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsAdPlaced(false);
    }
  };

  return (
    <Layout>
      {isLoading ? (
        <PageLoader />
      ) : (
        <>
          <BreadCrumb title2={t("editListing")} />
          <div className="container">
            <div className="flex flex-col gap-6 mt-8">
              <h1 className="text-2xl font-medium">{t("editListing")}</h1>
              <div className="flex flex-col gap-6 border rounded-md p-4">
                <div className="flex items-center gap-3 justify-between bg-muted px-4 py-2 rounded-md flex-wrap">
                  <div className="flex items-center gap-3 flex-wrap">
                    <div
                      className={`transition-all duration-300 p-2 cursor-pointer ${step === 1 ? "bg-primary text-white" : ""
                        } rounded-md `}
                      onClick={() => handleTabClick(1)}
                    >
                      {t("details")}
                    </div>
                    {customFields?.length > 0 && (
                      <div
                        className={`transition-all duration-300 p-2 cursor-pointer ${step === 2 ? "bg-primary text-white" : ""
                          } rounded-md`}
                        onClick={() => handleTabClick(2)}
                      >
                        {t("extraDetails")}
                      </div>
                    )}
                    <div
                      className={`transition-all duration-300 p-2 cursor-pointer ${step === 3 ? "bg-primary text-white" : ""
                        } rounded-md  `}
                      onClick={() => handleTabClick(3)}
                    >
                      {t("images")}
                    </div>
                    <div
                      className={`transition-all duration-300 p-2 cursor-pointer ${step === 4 ? "bg-primary text-white" : ""
                        } rounded-md `}
                      onClick={() => handleTabClick(4)}
                    >
                      {t("location")}
                    </div>
                  </div>
                  {(step === 1 || (step === 2 && hasTextbox)) && (
                    <AdLanguageSelector
                      langId={langId}
                      setLangId={setLangId}
                      languages={languages}
                      setTranslations={setTranslations}
                    />
                  )}
                </div>
                {step === 1 &&
                  selectedCategoryPath &&
                  selectedCategoryPath?.length > 0 && (
                    <div className="flex flex-col gap-2">
                      <h1 className="font-medium text-xl">
                        {t("selectedCategory")}
                      </h1>
                      <div className="flex">
                        {selectedCategoryPath?.map((item, index) => {
                          const shouldShowComma =
                            selectedCategoryPath.length > 1 &&
                            index !== selectedCategoryPath.length - 1;
                          return (
                            <span className="text-primary" key={item.id}>
                              {item.name}
                              {shouldShowComma && ", "}
                            </span>
                          );
                        })}
                      </div>
                    </div>
                  )}
                <div>
                  {step == 1 && (
                    <EditComponentOne
                      setTranslations={setTranslations}
                      current={currentDetails}
                      langId={langId}
                      defaultLangId={defaultLangId}
                      handleDetailsSubmit={handleDetailsSubmit}
                      is_job_category={is_job_category}
                      isPriceOptional={isPriceOptional}
                      currencies={currencies}
                    />
                  )}

                  {step == 2 && customFields.length > 0 && (
                    <EditComponentTwo
                      customFields={customFields}
                      extraDetails={extraDetails}
                      setExtraDetails={setExtraDetails}
                      handleGoBack={handleGoBack}
                      filePreviews={filePreviews}
                      setFilePreviews={setFilePreviews}
                      submitExtraDetails={submitExtraDetails}
                      currentExtraDetails={currentExtraDetails}
                      langId={langId}
                      defaultLangId={defaultLangId}
                    />
                  )}

                  {step == 3 && (
                    <EditComponentThree
                      setUploadedImages={setUploadedImages}
                      uploadedImages={uploadedImages}
                      OtherImages={OtherImages}
                      setOtherImages={setOtherImages}
                      handleImageSubmit={handleImageSubmit}
                      handleGoBack={handleGoBack}
                      setDeleteImagesId={setDeleteImagesId}
                    />
                  )}

                  {step == 4 && (
                    <EditComponentFour
                      handleGoBack={handleGoBack}
                      location={Location}
                      setLocation={setLocation}
                      handleFullSubmission={handleFullSubmission}
                      isAdPlaced={isAdPlaced}
                    />
                  )}
                </div>
              </div>
            </div>
          </div>
          <AdSuccessModal
            openSuccessModal={openSuccessModal}
            setOpenSuccessModal={setOpenSuccessModal}
            createdAdSlug={CreatedAdSlug}
          />
        </>
      )}
    </Layout>
  );
};

export default Checkauth(EditListing);
