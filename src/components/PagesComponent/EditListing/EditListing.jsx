"use client";
import React, { useEffect, useState } from "react";
import BreadcrumbComponent from "../../Breadcrumb/BreadcrumbComponent";
import EditListingTwo from "./EditListingContentTwo";
import EditListingThree from "./EditListingContentThree";
import EditListingFour from "./EditListingContentFour";
import EditListingFive from "./EditListingContentFive";
import AdEditSuccessfulModal from "../EditListing/AdEditSuccessfulModal";
import { useSelector } from "react-redux";
import { generateSlug, isPdf, isValidURL, t } from "@/utils";
import {
  editItemApi,
  getAreasApi,
  getCitiesApi,
  getCoutriesApi,
  getCustomFieldsApi,
  getStatesApi,
  getParentCategoriesApi,
  getLocationApi,
} from "@/utils/api";
import toast from "react-hot-toast";
import { getMyItemsApi } from "@/utils/api";
import { getIsPaidApi, settingsData } from "@/redux/reuducer/settingSlice";
import { CurrentLanguageData } from "@/redux/reuducer/languageSlice";
import axios from "axios";

const EditListing = ({ id }) => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const systemSettingsData = useSelector(settingsData);
  const settings = systemSettingsData?.data;
  const [activeTab, setActiveTab] = useState(2);
  const [IsAdSuccessfulModal, setIsAdSuccessfulModal] = useState(false);
  const [CurrenCategory, setCurrenCategory] = useState([]);
  const [CustomFields, setCustomFields] = useState([]);
  const [AdListingDetails, setAdListingDetails] = useState({
    title: "",
    slug: "",
    desc: "",
    price: "",
    phonenumber: "",
    link: "",
    salaryMin: "",
    salaryMax: "",
  });
  const [CreatedAdSlug, setCreatedAdSlug] = useState("");
  const [selectedCategoryPath, setSelectedCategoryPath] = useState([]);
  const [selectedCateId, setSelectedCateId] = useState("");
  const [extraDetails, setExtraDetails] = useState({});
  const [uploadedImages, setUploadedImages] = useState([]);
  const [OtherImages, setOtherImages] = useState([]);
  const [Location, setLocation] = useState({});
  const IsPaidApi = useSelector(getIsPaidApi);
  const [CountryStore, setCountryStore] = useState({
    Countries: [],
    SelectedCountry: {},
    CountrySearch: "",
    currentPage: 1,
    hasMore: false,
  });
  const [StateStore, setStateStore] = useState({
    States: [],
    SelectedState: {},
    StateSearch: "",
    currentPage: 1,
    hasMore: false,
  });
  const [CityStore, setCityStore] = useState({
    Cities: [],
    SelectedCity: {},
    CitySearch: "",
    currentPage: 1,
    hasMore: false,
  });
  const [AreaStore, setAreaStore] = useState({
    Areas: [],
    SelectedArea: {},
    AreaSearch: "",
    currentPage: 1,
    hasMore: false,
  });
  const [Address, setAddress] = useState("");
  const [extraFieldValue, setExtraFieldValue] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [deleteImagesId, setDeleteImagesId] = useState("");
  const [allCategoryIds, setAllCategoryIds] = useState("");
  const [filePreviews, setFilePreviews] = useState({});
  const [isAdPlaced, setIsAdPlaced] = useState(false);
  const is_job_category =
    selectedCategoryPath[selectedCategoryPath.length - 1]?.is_job_category;
  const isPriceOptional =
    selectedCategoryPath[selectedCategoryPath.length - 1]?.price_optional === 1;

  const getCountriesData = async (search, page) => {
    try {
      // Fetch countries
      const params = {};
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getCoutriesApi.getCoutries(params);
      let allCountries;
      if (page > 1) {
        allCountries = [...CountryStore?.Countries, ...res?.data?.data?.data];
      } else {
        allCountries = res?.data?.data?.data;
      }
      setCountryStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Countries: allCountries,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
      }));
    } catch (error) {
      console.error("Error fetching countries data:", error);
    }
  };

  const handleCountryScroll = (event) => {
    const { target } = event;
    if (
      target.scrollTop + target.offsetHeight >= target.scrollHeight &&
      CountryStore?.hasMore
    ) {
      getCountriesData("", CountryStore?.currentPage + 1);
    }
  };

  const getStatesData = async (search, page) => {
    try {
      const params = {
        country_id: CountryStore?.SelectedCountry?.id,
      };
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getStatesApi.getStates(params);

      let allStates;
      if (page > 1) {
        allStates = [...StateStore?.States, ...res?.data?.data?.data];
      } else {
        allStates = res?.data?.data?.data;
      }

      setStateStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        States: allStates,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
      }));
    } catch (error) {
      console.error("Error fetching states data:", error);
      return [];
    }
  };

  const handleStateScroll = (event) => {
    const { target } = event;
    if (
      target.scrollTop + target.offsetHeight >= target.scrollHeight &&
      StateStore?.hasMore
    ) {
      getStatesData("", StateStore?.currentPage + 1);
    }
  };
  const getCitiesData = async (search, page) => {
    try {
      const params = {
        state_id: StateStore?.SelectedState?.id,
      };
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getCitiesApi.getCities(params);
      let allCities;
      if (page > 1) {
        allCities = [...CityStore?.Cities, ...res?.data?.data?.data];
      } else {
        allCities = res?.data?.data?.data;
      }
      setCityStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Cities: allCities,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
      }));
    } catch (error) {
      console.error("Error fetching cities data:", error);
      return [];
    }
  };

  const handleCityScroll = (event) => {
    const { target } = event;
    if (
      target.scrollTop + target.offsetHeight >= target.scrollHeight &&
      CityStore?.hasMore
    ) {
      getCitiesData("", CityStore?.currentPage + 1);
    }
  };

  const getAreaData = async (search, page) => {
    const params = {
      city_id: CityStore?.SelectedCity?.id,
    };
    if (search) {
      params.search = search; // Send only 'search' if provided
    } else {
      params.page = page; // Send only 'page' if no search
    }
    try {
      const res = await getAreasApi.getAreas(params);
      let allArea;
      if (page > 1) {
        allArea = [...AreaStore?.Areas, ...res?.data?.data?.data];
      } else {
        allArea = res?.data?.data?.data;
      }
      setAreaStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Areas: allArea,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
      }));
    } catch (error) {
      console.error("Error fetching cities data:", error);
      return [];
    }
  };

  const handleAreaScroll = (event) => {
    const { target } = event;
    if (
      target.scrollTop + target.offsetHeight >= target.scrollHeight &&
      AreaStore?.hasMore
    ) {
      getAreaData("", AreaStore?.currentPage + 1);
    }
  };

  useEffect(() => {
    const timeout = setTimeout(() => {
      getCountriesData(CountryStore?.CountrySearch, 1);
    }, 500);
    return () => {
      clearTimeout(timeout);
    };
  }, [CountryStore?.CountrySearch]);

  useEffect(() => {
    if (CountryStore?.SelectedCountry?.id) {
      const timeout = setTimeout(() => {
        getStatesData(StateStore?.StateSearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [CountryStore?.SelectedCountry?.id, StateStore?.StateSearch]);

  useEffect(() => {
    if (StateStore?.SelectedState?.id) {
      const timeout = setTimeout(() => {
        getCitiesData(CityStore?.CitySearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [StateStore?.SelectedState?.id, CityStore?.CitySearch]);

  useEffect(() => {
    if (CityStore?.SelectedCity?.id) {
      const timeout = setTimeout(() => {
        getAreaData(AreaStore?.AreaSearch);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [CityStore?.SelectedCity?.id, AreaStore?.AreaSearch]);

  const getLocationWithMap = async (pos) => {
    try {
      const { lat, lng } = pos;
      const response = await getLocationApi.getLocation({
        lat,
        lng,
        lang: "en",
      });

      if (response?.data.error === false) {

        if (IsPaidApi) {
          let city = "";
          let state = "";
          let country = "";
          let address = "";

          const results = response?.data?.data?.results;

          results?.forEach((result) => {
            const addressComponents = result.address_components;
            const getAddressComponent = (type) => {
              const component = addressComponents.find((comp) =>
                comp.types.includes(type)
              );
              return component ? component.long_name : "";
            };
            if (!city) city = getAddressComponent("locality");
            if (!state)
              state = getAddressComponent("administrative_area_level_1");
            if (!country) country = getAddressComponent("country");
            if (!address) address = result?.formatted_address;
          });

          const locationData = {
            lat,
            long: lng,
            city,
            state,
            country,
            address,
          };
          setLocation(locationData);
        } else {
          const results = response?.data?.data;
          const formattedAddress = [results?.city, results?.state, results?.country].filter(Boolean).join(", ");
          const cityData = {
            lat: results?.latitude,
            long: results?.longitude,
            city: results?.city || "",
            state: results?.state || "",
            country: results?.country || "",
            address: formattedAddress
          };
          setLocation(cityData);
        }
      } else {
        toast.error(t("errorOccurred"));
      }
    } catch (error) {
      console.error("Error fetching location data:", error);
      toast.error(t("errorOccurred"));
    }
  };

  const getCurrentLocation = async () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          try {
            const { latitude, longitude } = position.coords;
            if (IsPaidApi) {
              const response = await getLocationApi.getLocation({
                lat: latitude,
                lng: longitude,
                lang: "en",
              });

              if (response?.data.error === false) {
                let city = "";
                let state = "";
                let country = "";
                let address = "";
                const results = response?.data?.data?.results;
                results?.forEach((result) => {
                  const addressComponents = result.address_components;
                  const getAddressComponent = (type) => {
                    const component = addressComponents.find((comp) =>
                      comp.types.includes(type)
                    );
                    return component ? component.long_name : "";
                  };
                  if (!city) city = getAddressComponent("locality");
                  if (!state)
                    state = getAddressComponent("administrative_area_level_1");
                  if (!country) country = getAddressComponent("country");
                  if (!address) address = result?.formatted_address;
                });

                const cityData = {
                  lat: latitude,
                  long: longitude,
                  city,
                  state,
                  country,
                  address,
                };
                setLocation(cityData);
              }
            } else {
              const nominatimResponse = await axios.get(
                "https://nominatim.openstreetmap.org/reverse",
                {
                  params: {
                    format: "json",
                    lat: latitude,
                    lon: longitude,
                    "accept-language": "en",
                    zoom: 10,
                  },
                }
              );
              const data = nominatimResponse?.data?.address;
              const address = [data?.city, data?.state, data?.country].filter(Boolean).join(", ");
              const cityData = {
                lat: latitude,
                long: longitude,
                city: data.city || "",
                state: data.state || "",
                country: data.country || "",
                address
              };
              setLocation(cityData);
            }
          } catch (error) {
            console.error("Error fetching location data:", error);
            toast.error(t("errorOccurred"));
          }
        },
        (error) => {
          toast.error(t("locationNotGranted"));
        }
      );
    } else {
      toast.error(t("geoLocationNotSupported"));
    }
  };

  const fetchCategoryPath = async () => {
    try {
      const response = await getParentCategoriesApi.getPaymentCategories({
        child_category_id: selectedCateId,
      });
      setSelectedCategoryPath(response?.data?.data);
    } catch (error) {
      console.log(error);
    }
  };

  const getCustomFieldsData = async (id) => {
    try {
      const res = await getCustomFieldsApi.getCustomFields({
        category_ids: id,
      });
      const data = res?.data?.data;
      setCustomFields(data);
      const tempExtraDetails = {};
      data?.forEach((field) => {
        const fieldId = field.id;
        const extraField = extraFieldValue.find((item) => item.id === fieldId);
        const fieldValue = extraField ? extraField?.value : null;

        if (field.type === "checkbox") {
          // For checkbox fields, initialize with the values from extraFieldValue
          const checkboxValues = fieldValue || [];
          tempExtraDetails[fieldId] = checkboxValues;
        } else if (field.type === "radio") {
          // For radio fields, initialize as a single value
          const radioValue = fieldValue ? fieldValue[0] : "";
          tempExtraDetails[fieldId] = radioValue;
        } else if (field.type === "fileinput") {
          // For fileinput fields, initialize with null or empty string

          if (fieldValue) {
            setFilePreviews((prevPreviews) => ({
              ...prevPreviews,
              [fieldId]: {
                url: fieldValue[0],
                isPdf: isPdf(extraField.custom_field_value.value),
              },
            }));
          }

          tempExtraDetails[fieldId] = "";
        } else {
          // For other fields
          const initialValue = fieldValue ? fieldValue[0] : "";
          tempExtraDetails[fieldId] = initialValue;
        }
      });

      setExtraDetails(tempExtraDetails);
    } catch (error) {
      console.log(error);
    }
  };

  useEffect(() => {
    if (allCategoryIds) {
      getCustomFieldsData(allCategoryIds);
    }
  }, [allCategoryIds]);

  useEffect(() => {
    if (selectedCateId) {
      fetchCategoryPath();
    }
  }, [selectedCateId]);

  useEffect(() => { }, [selectedCategoryPath]);

  const handleGoBack = () => {
    if (activeTab == 4 && CustomFields?.length == 0) {
      setActiveTab((prev) => prev - 2);
    } else {
      setActiveTab((prev) => prev - 1);
    }
  };

  const handleAdListingChange = (e) => {
    const { name, value } = e.target;
    setAdListingDetails((prevDetails) => {
      const updatedDetails = {
        ...prevDetails,
        [name]: value,
      };
      if (name === "title") {
        updatedDetails.slug = generateSlug(value);
      }
      return updatedDetails;
    });
  };

  const handleDetailsSubmit = () => {
    const isValidSlug = /^[a-z0-9-]+$/.test(AdListingDetails.slug.trim());
    if (AdListingDetails.title?.trim() == "") {
      toast.error(t("titleRequired"));
      return;
    } else if (AdListingDetails.desc.trim() == "") {
      toast.error(t("descriptionRequired"));
      return;
    }
    if (is_job_category === 1) {
      // Validation for job listings (salary min/max) - optional but validate if provided
      if (AdListingDetails.salaryMin && AdListingDetails.salaryMin < 0) {
        toast.error(t("enterValidSalaryMin"));
        return;
      } else if (AdListingDetails.salaryMax && AdListingDetails.salaryMax < 0) {
        toast.error(t("enterValidSalaryMax"));
        return;
      } else if (
        AdListingDetails.salaryMin &&
        AdListingDetails.salaryMax &&
        Number(AdListingDetails.salaryMin) ===
        Number(AdListingDetails.salaryMax)
      ) {
        toast.error(t("salaryMinCannotBeEqualMax"));
        return;
      } else if (
        AdListingDetails.salaryMin &&
        AdListingDetails.salaryMax &&
        Number(AdListingDetails.salaryMin) > Number(AdListingDetails.salaryMax)
      ) {
        toast.error(t("salaryMinCannotBeGreaterThanMax"));
        return;
      }
    } else {
      // Validation for regular listings (price)
      if (!isPriceOptional && !AdListingDetails.price) {
        toast.error(t("priceRequired"));
        return;
      } else if (AdListingDetails?.price && AdListingDetails?.price < 0) {
        toast.error(t("enterValidPrice"));
        return;
      }
    }

    if (!AdListingDetails.phonenumber) {
      toast.error(t("phoneRequired"));
      return;
    } else if (AdListingDetails.slug.trim() && !isValidSlug) {
      toast.error(t("addValidSlug"));
      return;
    }

    if (CustomFields?.length === 0) {
      setActiveTab(4);
    } else {
      setActiveTab(3);
    }
  };

  const submitExtraDetails = (e) => {
    if (!validateExtraDetails(CustomFields, extraDetails)) {
      return;
    }
    setActiveTab(4);
  };

  const handleImageSubmit = () => {
    if (uploadedImages.length === 0) {
      toast.error(t("uploadMainPicture"));
      return;
    }
    setActiveTab(5);
  };

  const validateExtraDetails = (CustomFields, extraDetails) => {
    for (const field of CustomFields) {
      const { name, type, required, id, min_length } = field;
      if (required) {
        if (
          type !== "checkbox" &&
          type !== "radio" &&
          type !== "fileinput" &&
          !(type === "textbox" ? extraDetails[id]?.trim() : extraDetails[id])
        ) {
          toast.error(`${t("fillDetails")} ${name}.`);
          return false;
        }

        if (type === "fileinput" && !extraDetails[id] && !filePreviews[id]) {
          toast.error(`${t("fillDetails")} ${name}.`);
          return false;
        }

        if (
          (type === "checkbox" || type === "radio") &&
          extraDetails[id].length === 0
        ) {
          toast.error(`${t("selectAtleastOne")} ${name}.`);
          return false;
        }

        // Required field with min_length validation
        if (
          extraDetails[id] &&
          type === "textbox" &&
          extraDetails[id].trim().length < min_length
        ) {
          toast.error(
            `${name} ${t("mustBeAtleast")} ${min_length} ${t("charactersLong")}`
          );
          return false;
        }
        if (
          extraDetails[id] &&
          type === "number" &&
          extraDetails[id].length < min_length
        ) {
          toast.error(
            `${name} ${t("mustBeAtleast")} ${min_length} ${t("digitLong")}`
          );
          return false;
        }
      }

      // Non-required field with min_length validation
      if (
        !required &&
        extraDetails[id] &&
        type === "textbox" &&
        extraDetails[id].length < min_length
      ) {
        toast.error(
          `${name} ${t("mustBeAtleast")} ${min_length} ${t("charactersLong")}`
        );
        return false;
      }

      if (
        !required &&
        extraDetails[id] &&
        type === "number" &&
        extraDetails[id].length < min_length
      ) {
        toast.error(
          `${name} ${t("mustBeAtleast")} ${min_length} ${t("digitLong")}`
        );
        return false;
      }
    }
    return true;
  };

  const editAd = async () => {
    const transformedCustomFields = {};
    const customFieldFiles = [];

    Object.entries(extraDetails).forEach(([key, value]) => {
      if (value === null || value === undefined || value === "") {
        // Handle the case where the input file is null
        return;
      }
      if (
        value instanceof File ||
        (Array.isArray(value) && value[0] instanceof File)
      ) {
        customFieldFiles.push({ key, files: value });
      } else {
        transformedCustomFields[key] = Array.isArray(value) ? value : [value];
      }
    });

    const show_only_to_premium = 1;
    const allData = {
      id: id,
      name: AdListingDetails.title,
      slug: AdListingDetails.slug.trim(),
      description: AdListingDetails?.desc,
      price: AdListingDetails.price,
      contact: AdListingDetails.phonenumber,
      video_link: AdListingDetails?.link,
      custom_fields: transformedCustomFields,
      image: typeof uploadedImages == "string" ? null : uploadedImages[0],
      gallery_images: OtherImages,
      address: Location?.address,
      latitude: Location?.lat,
      longitude: Location?.long,
      custom_field_files: customFieldFiles,
      show_only_to_premium: show_only_to_premium,
      country: Location?.country,
      state: Location?.state,
      city: Location?.city,
      ...(AreaStore?.SelectedArea?.id
        ? { area_id: Number(AreaStore.SelectedArea.id) }
        : {}),
      delete_item_image_id: deleteImagesId,
    };

    if (is_job_category === 1) {
      // Only add salary fields if they're provided
      allData.min_salary = AdListingDetails.salaryMin;
      allData.max_salary = AdListingDetails.salaryMax;
    } else {
      allData.price = AdListingDetails.price;
    }

    try {
      setIsAdPlaced(true);
      const res = await editItemApi.editItem(allData);
      if (res?.data?.error === false) {
        setIsAdSuccessfulModal(true);
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

  const handleFullSubmission = () => {
    const {
      title,
      desc,
      price,
      slug,
      phonenumber,
      link,
      salaryMin,
      salaryMax,
    } = AdListingDetails;

    const isValidSlug = /^[a-z0-9-]+$/.test(slug.trim());

    if (!title.trim() || !desc.trim() || !phonenumber) {
      toast.error(t("completeDetails"));
      setActiveTab(2);
      return;
    }

    if (is_job_category === 1) {
      // Salary fields are optional, but validate if provided
      if (salaryMin && salaryMin < 0) {
        toast.error(t("enterValidSalaryMin"));
        setActiveTab(2);
        return;
      }

      if (salaryMax && salaryMax < 0) {
        toast.error(t("enterValidSalaryMax"));
        setActiveTab(2);
        return;
      }

      if (salaryMin && salaryMax && Number(salaryMin) === Number(salaryMax)) {
        toast.error(t("salaryMinCannotBeEqualMax"));
        setActiveTab(2);
        return;
      }

      if (salaryMin && salaryMax && Number(salaryMin) > Number(salaryMax)) {
        toast.error(t("salaryMinCannotBeGreaterThanMax"));
        setActiveTab(2);
        return;
      }
    } else {
      if (!isPriceOptional && !price) {
        toast.error(t("completeDetails"));
        setActiveTab(2);
        return;
      }

      if (price && price < 0) {
        toast.error(t("enterValidPrice"));
        setActiveTab(2);
        return;
      }
    }
    if (slug.trim() && !isValidSlug) {
      toast.error(t("addValidSlug"));
      setActiveTab(2);
      return;
    }

    if (link && !isValidURL(link)) {
      toast.error(t("enterValidUrl"));
      setActiveTab(2);
      return;
    }

    if (
      CustomFields.length !== 0 &&
      !validateExtraDetails(CustomFields, extraDetails)
    ) {
      setActiveTab(3);
      return;
    }

    if (uploadedImages.length === 0) {
      toast.error(t("uploadMainPicture"));
      setActiveTab(4);
      return;
    }

    if (
      !Location?.country ||
      !Location?.state ||
      !Location?.city ||
      !Location?.address
    ) {
      toast.error(t("pleaseSelectCity"));
      return;
    }
    editAd();
  };

  const getSingleListingData = async () => {
    try {
      const res = await getMyItemsApi.getMyItems({ id: Number(id) });
      const listingData = res?.data?.data?.[0];
      setUploadedImages(listingData?.image);
      setOtherImages(listingData?.gallery_images);
      setAllCategoryIds(listingData?.all_category_ids);
      setSelectedCateId(listingData?.category_id);
      await setEditCategory(listingData?.all_category_ids);
      setAdListingDetails((prevState) => ({
        ...prevState,
        title: listingData?.name || "",
        slug: listingData?.slug || "",
        desc: listingData?.description || "",
        price: listingData?.price || "",
        phonenumber: listingData?.contact || "",
        link: listingData?.video_link || "",
        salaryMin: listingData?.min_salary || "",
        salaryMax: listingData?.max_salary || "",
      }));

      setLocation({
        country: listingData?.country,
        state: listingData?.state,
        city: listingData?.city,
        address: listingData?.address,
        lat: listingData?.latitude,
        long: listingData?.longitude,
      });

      setExtraFieldValue(listingData?.custom_fields);
    } catch (error) {
      console.log(error);
    }
  };

  useEffect(() => {
    const getData = async () => {
      await getSingleListingData();
    };
    getData();
  }, []);
  const setEditCategory = async (category) => {
    const selectedCategoryIds = category
      ?.split(",")
      ?.map((id) => parseInt(id, 10));
    const filteredCategories = CurrenCategory?.filter((category) =>
      selectedCategoryIds?.includes(category.id)
    );
    const sequencedCategories = [];
    const traverseCategories = (categories) => {
      for (const category of categories) {
        if (selectedCategoryIds?.includes(category?.id)) {
          sequencedCategories.push(category);
        }
        if (category.subcategories && category.subcategories.length > 0) {
          traverseCategories(category.subcategories);
        }
      }
    };
    traverseCategories(filteredCategories);
  };

  return isLoading == false ? (
    <>
      <BreadcrumbComponent title2={t("editListing")} />
      <section className="adListingSect container">
        <div className="row">
          <div className="col-12">
            <span className="heading">{t("editListing")}</span>
          </div>
        </div>
        <div className="row tabsWrapper">
          <div className="col-12">
            <div className="tabsHeader">
              <span
                className={`tab ${activeTab === 2 ? "activeTab" : ""}`}
                onClick={() => setActiveTab(2)}
              >
                {t("details")}
              </span>
              {CustomFields.length !== 0 && (
                <span
                  className={`tab ${activeTab === 3 ? "activeTab" : ""}`}
                  onClick={() => setActiveTab(3)}
                >
                  {t("extraDetails")}
                </span>
              )}
              <span
                className={`tab ${activeTab === 4 ? "activeTab" : ""}`}
                onClick={() => setActiveTab(4)}
              >
                {t("images")}
              </span>
              <span
                className={`tab ${activeTab === 5 ? "activeTab" : ""}`}
                onClick={() => setActiveTab(5)}
              >
                {t("location")}
              </span>
            </div>
          </div>
          {activeTab === 2
            ? selectedCategoryPath &&
            selectedCategoryPath?.length > 0 && (
              <div className="col-12">
                <div className="tabBreadcrumb">
                  <span className="title1">
                    {t("selected")} {""} {t("category")}
                  </span>
                  <div className="selected_wrapper">
                    {selectedCategoryPath &&
                      selectedCategoryPath?.map((item, index) => (
                        <span className="title2edit" key={item.id}>
                          {item.name}
                          {index !== selectedCategoryPath?.length - 1 &&
                            selectedCategoryPath?.length > 1
                            ? ","
                            : ""}
                        </span>
                      ))}
                  </div>
                </div>
              </div>
            )
            : null}
          <div className="col-12">
            <div className="contentWrapper">
              <div className="row">
                {activeTab === 2 && (
                  <EditListingTwo
                    AdListingDetails={AdListingDetails}
                    handleAdListingChange={handleAdListingChange}
                    handleDetailsSubmit={handleDetailsSubmit}
                    handleGoBack={handleGoBack}
                    systemSettingsData={systemSettingsData}
                    is_job_category={is_job_category}
                    isPriceOptional={isPriceOptional}
                  />
                )}

                {activeTab === 3 && CustomFields.length !== 0 && (
                  <EditListingThree
                    CustomFields={CustomFields}
                    extraDetails={extraDetails}
                    setExtraDetails={setExtraDetails}
                    submitExtraDetails={submitExtraDetails}
                    handleGoBack={handleGoBack}
                    filePreviews={filePreviews}
                    setFilePreviews={setFilePreviews}
                  />
                )}

                {activeTab === 4 && (
                  <EditListingFour
                    setUploadedImages={setUploadedImages}
                    uploadedImages={uploadedImages}
                    OtherImages={OtherImages}
                    setOtherImages={setOtherImages}
                    handleImageSubmit={handleImageSubmit}
                    handleGoBack={handleGoBack}
                    setDeleteImagesId={setDeleteImagesId}
                  />
                )}

                {activeTab === 5 && (
                  <EditListingFive
                    getCurrentLocation={getCurrentLocation}
                    handleGoBack={handleGoBack}
                    Location={Location}
                    setLocation={setLocation}
                    handleFullSubmission={handleFullSubmission}
                    getLocationWithMap={getLocationWithMap}
                    Address={Address}
                    setAddress={setAddress}
                    isAdPlaced={isAdPlaced}
                    setCountryStore={setCountryStore}
                    CountryStore={CountryStore}
                    handleCountryScroll={handleCountryScroll}
                    StateStore={StateStore}
                    setStateStore={setStateStore}
                    handleStateScroll={handleStateScroll}
                    CityStore={CityStore}
                    setCityStore={setCityStore}
                    handleCityScroll={handleCityScroll}
                    AreaStore={AreaStore}
                    setAreaStore={setAreaStore}
                    handleAreaScroll={handleAreaScroll}
                  />
                )}
              </div>
            </div>
          </div>
        </div>
      </section>
      <AdEditSuccessfulModal
        IsAdSuccessfulModal={IsAdSuccessfulModal}
        OnHide={() => setIsAdSuccessfulModal(false)}
        CreatedAdSlug={CreatedAdSlug}
      />
    </>
  ) : (
    <p>{t("loading")}</p>
  );
};

export default EditListing;
