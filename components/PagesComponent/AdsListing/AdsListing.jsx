"use client";
import { useEffect, useState } from "react";
import ComponentOne from "./ComponentOne";
import {
  addItemApi,
  categoryApi,
  getCurrenciesApi,
  getCustomFieldsApi,
  getParentCategoriesApi,
} from "@/utils/api";
import ComponentTwo from "./ComponentTwo";
import {
  filterNonDefaultTranslations,
  getDefaultCountryCode,
  isValidURL,
  prepareCustomFieldFiles,
  prepareCustomFieldTranslations,
  t,
  validateExtraDetails,
} from "@/utils";
import { toast } from "sonner";
import ComponentThree from "./ComponentThree";
import ComponentFour from "./ComponentFour";
import ComponentFive from "./ComponentFive";
import { useSelector } from "react-redux";
import AdSuccessModal from "./AdSuccessModal";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import Layout from "@/components/Layout/Layout";
import Checkauth from "@/HOC/Checkauth";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import AdLanguageSelector from "./AdLanguageSelector";
import {
  getDefaultLanguageCode,
  getLanguages,
} from "@/redux/reducer/settingSlice";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { isValidPhoneNumber } from "libphonenumber-js/max";
import { getCurrentCountry } from "@/redux/reducer/locationSlice";

const AdsListing = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const currentCountry = useSelector(getCurrentCountry);
  const [step, setStep] = useState(1);
  const [categories, setCategories] = useState();
  const [categoriesLoading, setCategoriesLoading] = useState(false);
  const [isLoadMoreCat, setIsLoadMoreCat] = useState(false);
  const [categoryPath, setCategoryPath] = useState([]);
  const [currentPage, setCurrentPage] = useState();
  const [lastPage, setLastPage] = useState();
  const [disabledTab, setDisabledTab] = useState({
    categoryTab: false,
    detailTab: true,
    extraDetailTabl: true,
    images: true,
    location: true,
  });
  const [customFields, setCustomFields] = useState([]);
  const [filePreviews, setFilePreviews] = useState({});
  const [uploadedImages, setUploadedImages] = useState([]);
  const [otherImages, setOtherImages] = useState([]);
  const [location, setLocation] = useState({});
  const [currencies, setCurrencies] = useState([]);
  const [isAdPlaced, setIsAdPlaced] = useState(false);
  const [openSuccessModal, setOpenSuccessModal] = useState(false);
  const [createdAdSlug, setCreatedAdSlug] = useState("");
  const userData = useSelector(userSignUpData);

  const languages = useSelector(getLanguages);
  const defaultLanguageCode = useSelector(getDefaultLanguageCode);
  const defaultLangId = languages?.find(
    (lang) => lang.code === defaultLanguageCode
  )?.id;

  const [extraDetails, setExtraDetails] = useState({
    [defaultLangId]: {},
  });
  const [langId, setLangId] = useState(defaultLangId);

  const countryCode =
    userData?.country_code?.replace("+", "") || getDefaultCountryCode();
  const mobile = userData?.mobile || "";
  const regionCode =
    userData?.region_code?.toLowerCase() ||
    process.env.NEXT_PUBLIC_DEFAULT_COUNTRY?.toLowerCase() ||
    "in";

  const [translations, setTranslations] = useState({
    [langId]: {
      contact: mobile,
      country_code: countryCode,
      region_code: regionCode,
    },
  });
  const hasTextbox = customFields.some((field) => field.type === "textbox");

  const defaultDetails = translations[defaultLangId] || {};
  const currentDetails = translations[langId] || {};
  const currentExtraDetails = extraDetails[langId] || {};

  const is_job_category =
    Number(categoryPath[categoryPath.length - 1]?.is_job_category) === 1;
  const isPriceOptional =
    Number(categoryPath[categoryPath.length - 1]?.price_optional) === 1;

  const allCategoryIdsString = categoryPath
    .map((category) => category.id)
    .join(",");
  let lastItemId = categoryPath[categoryPath.length - 1]?.id;

  useEffect(() => {
    if (step === 1) {
      handleFetchCategories();
    }
  }, [CurrentLanguage.id]);

  useEffect(() => {
    if (step !== 1 && allCategoryIdsString) {
      getCustomFieldsData();
    }
  }, [allCategoryIdsString, CurrentLanguage.id]);

  useEffect(() => {
    // Update category path translations when language changes
    if (categoryPath.length > 0) {
      const lastCategoryId = categoryPath[categoryPath.length - 1]?.id;
      if (lastCategoryId) {
        getParentCategoriesApi
          .getPaymentCategories({
            child_category_id: lastCategoryId,
          })
          .then((res) => {
            const updatedPath = res?.data?.data;
            if (updatedPath?.length > 0) {
              setCategoryPath(updatedPath);
            }
          })
          .catch((err) => {
            console.log("Error updating category path:", err);
          });
      }
    }
  }, [CurrentLanguage.id]);

  useEffect(() => {
    getCurrencies();
  }, [countryCode]);

  const getCurrencies = async () => {
    try {
      let params = {};

      if (currentCountry) {
        params.country = currentCountry;
      }
      const res = await getCurrenciesApi.getCurrencies(params);
      const currenciesData = res?.data?.data || [];
      setCurrencies(currenciesData);
      // 🚫 IMPORTANT: If no currencies, REMOVE currency_id
      if (currenciesData.length === 0) {
        setTranslations((prev) => {
          const updated = { ...prev };

          if (updated[langId]?.currency_id) {
            delete updated[langId].currency_id;
          }

          return updated;
        });
        return;
      }
      // ✅ Normal case: set default currency
      const defaultCurrency =
        currenciesData.find((c) => c.selected == 1) || currenciesData[0];

      if (defaultCurrency && !translations[langId]?.currency_id) {
        setTranslations((prev) => ({
          ...prev,
          [langId]: {
            ...prev[langId],
            currency_id: defaultCurrency.id,
          },
        }));
      }
    } catch (error) {
      console.log("error", error);
    }
  };

  const handleFetchCategories = async (
    category,
    isWaitForApiResToUpdatePath = false
  ) => {
    setCategoriesLoading(true);
    try {
      const categoryId = category ? category?.id : null;

      const res = await categoryApi.getCategory({
        category_id: categoryId,
        listing: 1,
      });
      if (res?.data?.error === false) {
        const data = res?.data?.data?.data;
        setCategories(data);
        setCurrentPage(res?.data?.data?.current_page);
        setLastPage(res?.data?.data?.last_page);
        if (isWaitForApiResToUpdatePath) {
          setCategoryPath((prevPath) => [...prevPath, category]);
          if (category.subcategories_count == 0) {
            setStep(2);
            setDisabledTab({
              categoryTab: true,
              detailTab: false,
              extraDetailTabl: false,
              images: false,
              location: false,
            });
          }
        } else {
          const index = categoryPath.findIndex(
            (item) => item.id === category?.id
          );
          setCategoryPath((prevPath) => prevPath.slice(0, index + 1));
        }
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log("error", error);
    } finally {
      setCategoriesLoading(false);
    }
  };

  const getCustomFieldsData = async () => {
    try {
      const res = await getCustomFieldsApi.getCustomFields({
        category_ids: allCategoryIdsString,
      });
      const data = res?.data?.data;
      setCustomFields(data);

      const initializedDetails = {};

      languages.forEach((lang) => {
        const langFields = {};

        data.forEach((item) => {
          if (lang.id !== defaultLangId && item.type !== "textbox") return;

          let initialValue = "";
          switch (item.type) {
            case "checkbox":
            case "radio":
              initialValue = [];
              break;
            case "fileinput":
              initialValue = null;
              break;
            case "dropdown":
            case "textbox":
            case "number":
            case "text":
              initialValue = "";
              break;
            default:
              break;
          }
          langFields[item.id] = initialValue;
        });
        initializedDetails[lang.id] = langFields;
      });
      setExtraDetails(initializedDetails);
    } catch (error) {
      console.log(error);
    }
  };

  const handleCategoryTabClick = async (category) => {
    await handleFetchCategories(category, true);
  };

  const handleSelectedTabClick = (id) => {
    setCustomFields([]);
    setLangId(defaultLangId);
    setTranslations({
      [defaultLangId]: {
        contact: mobile,
        country_code: countryCode,
        region_code: regionCode,
      },
    });
    setExtraDetails({
      [defaultLangId]: {},
    });
    if (step !== 1) {
      setStep(1);
      setDisabledTab({
        categoryTab: false,
        detailTab: true,
        extraDetailTabl: true,
        images: true,
        location: true,
      });
    }
    // ✅ SINGLE CATEGORY EDGE CASE

    const index = categoryPath.findIndex((item) => item.id === id);

    if (index === 0) {
      setCategoryPath([]);
      // Fetch root / all categories
      handleFetchCategories(null);
      return;
    }

    // ✅ NORMAL BACK-NAVIGATION FLOW
    const secondLast = categoryPath[index - 1];

    if (secondLast) {
      handleFetchCategories(secondLast);
    }
  };

  const handleDetailsSubmit = () => {
    if (customFields?.length === 0) {
      setStep(4);
    } else {
      setStep(3);
    }
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

    // Step 1: Must pick a category
    const catId = categoryPath.at(-1)?.id;

    if (!catId) {
      toast.error(t("selectCategory"));
      return setStep(1);
    }
    // Step 2: Get data for default (selected) language
    if (isEmpty(name) || isEmpty(description)) {
      toast.error(t("completeDetails")); // Title, desc, phone required
      return setStep(2);
    }

    // ✅ Validate phone number ONLY if user entered one as it is optional
    if (Boolean(contact) && !isValidPhoneNumber(`+${country_code}${contact}`)) {
      toast.error(t("invalidPhoneNumber"));
      return setStep(2);
    }

    // Step 3: Validate job or price fields
    if (is_job_category) {
      const min = min_salary ? Number(min_salary) : null;
      const max = max_salary ? Number(max_salary) : null;

      if (min !== null && min < 0) {
        toast.error(t("enterValidSalaryMin"));
        return setStep(2);
      }
      if (max !== null && max < 0) {
        toast.error(t("enterValidSalaryMax"));
        return setStep(2);
      }
      if (min !== null && max !== null) {
        if (min === max) {
          toast.error(t("salaryMinCannotBeEqualMax"));
          return setStep(2);
        }
        if (min > max) {
          toast.error(t("salaryMinCannotBeGreaterThanMax"));
          return setStep(2);
        }
      }
    } else {
      if (!isPriceOptional && isEmpty(price)) {
        toast.error(t("completeDetails")); // Price is required
        return setStep(2);
      }
      if (!isEmpty(price) && isNegative(price)) {
        toast.error(t("enterValidPrice"));
        return setStep(2);
      }
    }

    // Step 4: Video URL check
    if (!isEmpty(video_link) && !isValidURL(video_link)) {
      toast.error(t("enterValidUrl"));
      return setStep(2);
    }

    // Step 5: Slug validation
    if (!isEmpty(slug) && !SLUG_RE.test(slug.trim())) {
      toast.error(t("addValidSlug"));
      return setStep(2);
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
      return setStep(3);
    }
    if (uploadedImages.length === 0) {
      toast.error(t("uploadMainPicture"));
      setStep(4);
      return;
    }

    if (
      !location?.country ||
      !location?.state ||
      !location?.city ||
      !location?.formattedAddress
    ) {
      toast.error(t("pleaseSelectCity"));
      return;
    }
    postAd();
  };

  const postAd = async () => {
    const catId = categoryPath.at(-1)?.id;
    const customFieldTranslations =
      prepareCustomFieldTranslations(extraDetails);

    const customFieldFiles = prepareCustomFieldFiles(
      extraDetails,
      defaultLangId
    );
    const nonDefaultTranslations = filterNonDefaultTranslations(
      translations,
      defaultLangId
    );

    const allData = {
      name: defaultDetails.name,
      slug: defaultDetails.slug.trim(),
      description: defaultDetails?.description,
      category_id: catId,
      all_category_ids: allCategoryIdsString,
      price: defaultDetails.price,
      contact: defaultDetails.contact,
      video_link: defaultDetails?.video_link,
      // custom_fields: transformedCustomFields,
      image: uploadedImages[0],
      gallery_images: otherImages,
      address: location?.formattedAddress,
      latitude: location?.lat,
      longitude: location?.long,
      custom_field_files: customFieldFiles,
      country: location?.country,
      state: location?.state,
      city: location?.city,
      ...(location?.area_id ? { area_id: Number(location?.area_id) } : {}),
      ...(Object.keys(nonDefaultTranslations).length > 0 && {
        translations: nonDefaultTranslations,
      }),
      ...(Object.keys(customFieldTranslations).length > 0 && {
        custom_field_translations: customFieldTranslations,
      }),
      ...(defaultDetails?.currency_id && {
        currency_id: defaultDetails?.currency_id,
      }),
      region_code: defaultDetails?.region_code?.toUpperCase() || "",
    };
    if (is_job_category) {
      // Only add salary fields if they're provided
      if (defaultDetails.min_salary) {
        allData.min_salary = defaultDetails.min_salary;
      }
      if (defaultDetails.max_salary) {
        allData.max_salary = defaultDetails.max_salary;
      }
    } else {
      allData.price = defaultDetails.price;
    }

    try {
      setIsAdPlaced(true);
      const res = await addItemApi.addItem(allData);
      if (res?.data?.error === false) {
        setOpenSuccessModal(true);
        setCreatedAdSlug(res?.data?.data[0]?.slug);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsAdPlaced(false);
    }
  };

  const handleGoBack = () => {
    setStep((prev) => {
      if (customFields.length === 0 && step === 4) {
        return prev - 2;
      } else {
        return prev - 1;
      }
    });
  };

  const fetchMoreCategory = async () => {
    setIsLoadMoreCat(true);
    try {
      const response = await categoryApi.getCategory({
        page: `${currentPage + 1}`,
        category_id: lastItemId,
        listing: 1,
      });
      const { data } = response.data;
      setCategories((prev) => [...prev, ...data.data]);
      setCurrentPage(data?.current_page); // Update the current page
      setLastPage(data?.last_page); // Update the current page
    } catch (error) {
      console.error("Error:", error);
    } finally {
      setIsLoadMoreCat(false);
    }
  };

  const handleTabClick = (tab) => {
    if (tab === 1 && !disabledTab.categoryTab) {
      setStep(1);
    } else if (tab === 2 && !disabledTab.detailTab) {
      setStep(2);
    } else if (tab === 3 && !disabledTab.extraDetailTabl) {
      setStep(3);
    } else if (tab === 4 && !disabledTab.images) {
      setStep(4);
    } else if (tab === 5 && !disabledTab.location) {
      setStep(5);
    }
  };

  const handleDeatilsBack = () => {
    setCustomFields([]);
    setLangId(defaultLangId);
    setTranslations({
      [defaultLangId]: {
        contact: mobile,
        country_code: countryCode,
        region_code: regionCode,
      },
    });
    setExtraDetails({
      [defaultLangId]: {},
    });

    if (step !== 1) {
      setStep(1);
      setDisabledTab({
        selectCategory: false,
        details: true,
        extraDet: true,
        img: true,
        loc: true,
      });
    }
    const secondLast = categoryPath.at(-2);
    if (secondLast) {
      handleFetchCategories(secondLast);
    }
  };

  return (
    <Layout>
      <BreadCrumb title2={t("adListing")} />
      <div className="container">
        <div className="flex flex-col gap-8 mt-8">
          <h1 className="text-2xl font-medium">{t("adListing")}</h1>
          <div className="flex flex-col gap-6 border rounded-md p-4">
            <div className="flex items-center gap-3 justify-between bg-muted px-4 py-2 rounded-md flex-wrap">
              <div className="flex items-center gap-3 flex-wrap">
                <div
                  className={`transition-all duration-300 p-2 cursor-pointer ${step === 1 ? "bg-primary text-white" : ""
                    } rounded-md ${disabledTab?.categoryTab == true ? "opacity-60" : " "
                    }`}
                  onClick={() => handleTabClick(1)}
                >
                  {t("selectedCategory")}
                </div>
                <div
                  className={`transition-all duration-300 p-2 cursor-pointer ${step === 2 ? "bg-primary text-white" : ""
                    } rounded-md ${disabledTab?.detailTab == true ? "opacity-60" : " "
                    }`}
                  onClick={() => handleTabClick(2)}
                >
                  {t("details")}
                </div>

                {customFields?.length > 0 && (
                  <div
                    className={`transition-all duration-300 p-2 cursor-pointer ${step === 3 ? "bg-primary text-white" : ""
                      } rounded-md ${disabledTab?.extraDetailTabl == true ? "opacity-60" : " "
                      }`}
                    onClick={() => handleTabClick(3)}
                  >
                    {t("extraDetails")}
                  </div>
                )}

                <div
                  className={`transition-all duration-300 p-2 cursor-pointer ${step === 4 ? "bg-primary text-white" : ""
                    } rounded-md  ${disabledTab?.images == true ? "opacity-60" : " "
                    }`}
                  onClick={() => handleTabClick(4)}
                >
                  {t("images")}
                </div>

                <div
                  className={`transition-all duration-300 p-2 cursor-pointer ${step === 5 ? "bg-primary text-white" : ""
                    } rounded-md ${disabledTab?.location == true ? "opacity-60" : " "
                    }`}
                  onClick={() => handleTabClick(5)}
                >
                  {t("location")}
                </div>
              </div>

              {(step == 2 || (step === 3 && hasTextbox)) && (
                <AdLanguageSelector
                  langId={langId}
                  setLangId={setLangId}
                  languages={languages}
                  setTranslations={setTranslations}
                />
              )}
            </div>

            {(step == 1 || step == 2) && categoryPath?.length > 0 && (
              <div className="flex flex-col gap-2">
                <p className="font-medium text-xl">{t("selectedCategory")}</p>
                <div className="flex">
                  {categoryPath?.map((item, index) => {
                    const shouldShowComma =
                      categoryPath.length > 1 &&
                      index !== categoryPath.length - 1;
                    return (
                      <button
                        key={item.id}
                        className="text-primary ltr:text-left rtl:text-right"
                        onClick={() => handleSelectedTabClick(item?.id)}
                        disabled={categoriesLoading}
                      >
                        {item.translated_name || item.name}
                        {shouldShowComma && ", "}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
            <div>
              {step == 1 && (
                <ComponentOne
                  categories={categories}
                  setCategoryPath={setCategoryPath}
                  fetchMoreCategory={fetchMoreCategory}
                  lastPage={lastPage}
                  currentPage={currentPage}
                  isLoadMoreCat={isLoadMoreCat}
                  handleCategoryTabClick={handleCategoryTabClick}
                  categoriesLoading={categoriesLoading}
                />
              )}

              {step == 2 && (
                <ComponentTwo
                  currencies={currencies}
                  setTranslations={setTranslations}
                  current={currentDetails}
                  langId={langId}
                  defaultLangId={defaultLangId}
                  handleDetailsSubmit={handleDetailsSubmit}
                  handleDeatilsBack={handleDeatilsBack}
                  is_job_category={is_job_category}
                  isPriceOptional={isPriceOptional}
                />
              )}

              {step == 3 && (
                <ComponentThree
                  customFields={customFields}
                  setExtraDetails={setExtraDetails}
                  filePreviews={filePreviews}
                  setFilePreviews={setFilePreviews}
                  setStep={setStep}
                  handleGoBack={handleGoBack}
                  currentExtraDetails={currentExtraDetails}
                  langId={langId}
                  defaultLangId={defaultLangId}
                />
              )}

              {step == 4 && (
                <ComponentFour
                  uploadedImages={uploadedImages}
                  setUploadedImages={setUploadedImages}
                  otherImages={otherImages}
                  setOtherImages={setOtherImages}
                  setStep={setStep}
                  handleGoBack={handleGoBack}
                />
              )}

              {step == 5 && (
                <ComponentFive
                  location={location}
                  setLocation={setLocation}
                  handleFullSubmission={handleFullSubmission}
                  isAdPlaced={isAdPlaced}
                  handleGoBack={handleGoBack}
                />
              )}
            </div>
          </div>
        </div>
        <AdSuccessModal
          openSuccessModal={openSuccessModal}
          setOpenSuccessModal={setOpenSuccessModal}
          createdAdSlug={createdAdSlug}
        />
      </div>
    </Layout>
  );
};

export default Checkauth(AdsListing);
