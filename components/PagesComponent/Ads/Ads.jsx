"use client";
import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import Filter from "../../Filter/Filter";
import {
  allItemApi,
  FeaturedSectionApi,
  getCustomFieldsApi,
  getParentCategoriesApi,
  getSeoSettingsApi,
} from "@/utils/api";
import ProductCard from "@/components/Common/ProductCard";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { TbTransferVertical } from "react-icons/tb";
import ProductHorizontalCard from "@/components/Common/ProductHorizontalCard";
import ProductCardSkeleton from "@/components/Common/ProductCardSkeleton";
import ProductHorizontalCardSkeleton from "@/components/Common/ProductHorizontalCardSkeleton";
import NoData from "@/components/EmptyStates/NoData";
import { IoGrid } from "react-icons/io5";
import { CiGrid2H } from "react-icons/ci";
import { Badge } from "@/components/ui/badge";
import { IoIosCloseCircle } from "react-icons/io";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import Layout from "@/components/Layout/Layout";
import { Button } from "@/components/ui/button";
import { useDispatch, useSelector } from "react-redux";
import {
  BreadcrumbPathData,
  setBreadcrumbPath,
} from "@/redux/reducer/breadCrumbSlice";
import { seoData, t } from "@/utils";
import { getSelectedLocation } from "@/redux/reducer/globalStateSlice";
import { generateKeywords } from "@/utils/generateKeywords";

const Ads = () => {
  const dispatch = useDispatch();
  const searchParams = useSearchParams();
  const newSearchParams = new URLSearchParams(searchParams);
  const BreadcrumbPath = useSelector(BreadcrumbPathData);

  const [view, setView] = useState("grid");
  const [advertisements, setAdvertisements] = useState({
    data: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: false,
  });
  const [featuredTitle, setFeaturedTitle] = useState("");

  const selectedLocation = useSelector(getSelectedLocation);

  const query = searchParams.get("query") || "";
  const slug = searchParams.get("category") || "";
  const country = searchParams.get("country") || "";
  const state = searchParams.get("state") || "";
  const city = searchParams.get("city") || "";
  const area = searchParams.get("area") || "";
  const areaId = Number(searchParams.get("areaId")) || "";
  const lat = Number(searchParams.get("lat"));
  const lng = Number(searchParams.get("lng"));
  const min_price = searchParams.get("min_price")
    ? Number(searchParams.get("min_price"))
    : "";
  const max_price = searchParams.get("max_price")
    ? Number(searchParams.get("max_price"))
    : "";
  const date_posted = searchParams.get("date_posted") || "";
  const km_range = searchParams.get("km_range") || "";
  const sortBy = searchParams.get("sort_by") || "new-to-old";
  const langCode = searchParams.get("lang");
  const featured_section = searchParams.get("featured_section") || "";

  const isMinPrice =
    min_price !== "" &&
    min_price !== null &&
    min_price !== undefined &&
    min_price >= 0;

  const knownParams = [
    "country",
    "state",
    "city",
    "area",
    "areaId",
    "lat",
    "lng",
    "min_price",
    "max_price",
    "date_posted",
    "km_range",
    "sort_by",
    "category",
    "query",
    "lang",
    "featured_section",
  ];

  const title = useMemo(() => {
    if (BreadcrumbPath.length === 2) {
      return BreadcrumbPath[1]?.name;
    }

    if (BreadcrumbPath.length > 2) {
      const last = BreadcrumbPath[BreadcrumbPath.length - 1]?.name;
      const secondLast = BreadcrumbPath[BreadcrumbPath.length - 2]?.name;
      return `${last} ${t("in")} ${secondLast}`;
    }

    return t("ads");
  }, [BreadcrumbPath, t]);

  const category =
    BreadcrumbPath.length > 1 &&
    BreadcrumbPath[BreadcrumbPath.length - 1]?.name;

  const [customFields, setCustomFields] = useState([]);

  const initialExtraDetails = useMemo(() => {
    const temprorayExtraDet = {};
    Array.from(searchParams.entries() || []).forEach(([key, value]) => {
      if (!knownParams?.includes(key)) {
        temprorayExtraDet[key] = value?.includes(",")
          ? value?.split(",")
          : value;
      }
    });
    return temprorayExtraDet;
  }, [
    JSON.stringify(
      Array.from(searchParams.entries()).filter(
        ([key]) => !knownParams.includes(key)
      )
    ),
  ]);

  const [extraDetails, setExtraDetails] = useState(initialExtraDetails);

  // Count active filters
  const getActiveFilterCount = () => {
    let count = 0;

    // Location filter
    if (country || state || city || areaId) count++;

    // KM Range filter
    if (km_range) count++;

    if (category) count++;

    if (featured_section) count++;

    // Query filter
    if (query) count++;

    // Date Posted filter
    if (date_posted) count++;

    // Price Range filter
    if (isMinPrice && max_price) count++;

    // Extra Details filters
    if (initialExtraDetails && Object.keys(initialExtraDetails).length > 0) {
      count += Object.keys(initialExtraDetails).length;
    }

    return count;
  };

  const activeFilterCount = getActiveFilterCount();

  useEffect(() => {
    const fetchFeaturedSectionData = async () => {
      try {
        const response = await FeaturedSectionApi.getFeaturedSections({
          slug: featured_section,
        });

        if (response?.data?.error === false) {
          setFeaturedTitle(
            response?.data?.data?.[0]?.translated_name ||
            response?.data?.data?.[0]?.title
          );
        } else {
          console.error(response?.data?.message);
        }
      } catch (error) {
        console.error("Error:", error);
      }
    };
    if (featured_section) {
      fetchFeaturedSectionData();
    }
  }, [langCode, featured_section]);

  useEffect(() => {
    if (slug) {
      constructBreadcrumbPath();
    } else {
      dispatch(
        setBreadcrumbPath([
          {
            name: t("allCategories"),
            key: "all-categories",
            slug: "/ads",
            isAllCategories: true,
          },
        ])
      );
      setCustomFields([]);
      setExtraDetails({});
      const fetchSeoSettings = async () => {
        const res = await getSeoSettingsApi.getSeoSettings({
          page: "ad-listing",
        });
        const data = res.data.data[0];
        const title =
          data?.translated_title ||
          data?.title ||
          process.env.NEXT_PUBLIC_META_TITLE;
        const description =
          data?.translated_description ||
          process.env.NEXT_PUBLIC_META_DESCRIPTION;
        const keywords =
          data?.translated_keywords || process.env.NEXT_PUBLIC_META_kEYWORDS;
        const image = data?.image || "";
        const canonicalUrl = process.env.NEXT_PUBLIC_WEB_URL;
        seoData({ title, description, keywords, image, canonicalUrl });
      };
      fetchSeoSettings();
    }
  }, [slug, langCode]);

  const getCustomFieldsData = async (categoryIds) => {
    try {
      const res = await getCustomFieldsApi.getCustomFields({
        category_ids: categoryIds,
        filter: true,
      });
      const data = res?.data?.data;
      setCustomFields(data);
      const isShowCustomfieldFilter =
        data.length > 0 &&
        data.some(
          (field) =>
            field.type === "checkbox" ||
            field.type === "radio" ||
            field.type === "dropdown"
        );

      if (isShowCustomfieldFilter) {
        const initialExtraDetails = {};
        data.forEach((field) => {
          const value = searchParams.get(field.id);
          if (value) {
            initialExtraDetails[field.id] =
              field.type === "checkbox" ? value.split(",") : value;
          }
        });
        setExtraDetails(initialExtraDetails);
      } else {
        setExtraDetails({});
      }
    } catch (error) {
      console.log(error);
    }
  };

  const constructBreadcrumbPath = async () => {
    try {
      const res = await getParentCategoriesApi.getPaymentCategories({
        slug,
        tree: 0,
      });
      const data = res?.data?.data || [];
      const selectedCategory = data?.at(-1);
      if (selectedCategory) {
        seoData({
          title:
            selectedCategory?.translated_name || process.env.NEXT_PUBLIC_META_TITLE,
          description:
            selectedCategory?.translated_description ||
            process.env.NEXT_PUBLIC_META_DESCRIPTION,
          keywords:
            generateKeywords(selectedCategory?.translated_description) ||
            process.env.NEXT_PUBLIC_META_kEYWORDS,
          image: selectedCategory?.image,
          canonicalUrl: `${process.env.NEXT_PUBLIC_WEB_URL}?category=${selectedCategory?.slug}&lang=${langCode}`,
        });
      }
      const breadcrumbArray = [
        {
          name: t("allCategories"),
          key: "all-categories",
          slug: "/ads",
          isAllCategories: true,
        },
        ...data.map((item) => ({
          name: item.translated_name,
          key: item.slug,
          slug: `/ads?category=${item.slug}`,
        })),
      ];
      dispatch(setBreadcrumbPath(breadcrumbArray));
      const categoryIds = data.map((category) => category.id).join(",");
      await getCustomFieldsData(categoryIds);
    } catch (error) {
      console.log(error);
    }
  };

  useEffect(() => {
    getSingleCatItem(1);
  }, [
    lat,
    lng,
    areaId,
    city,
    state,
    country,
    min_price,
    max_price,
    date_posted,
    km_range,
    sortBy,
    initialExtraDetails,
    slug,
    query,
    langCode,
    featured_section,
  ]);

  const getSingleCatItem = async (page) => {
    try {
      const parameters = { page, limit: 12 };
      if (sortBy) parameters.sort_by = sortBy;
      if (isMinPrice) parameters.min_price = min_price;
      if (max_price) parameters.max_price = max_price;
      if (date_posted) parameters.posted_since = date_posted;
      if (slug) parameters.category_slug = slug;
      if (extraDetails) parameters.custom_fields = extraDetails;
      if (featured_section) parameters.featured_section_slug = featured_section;

      if (Number(km_range) > 0) {
        parameters.latitude = lat;
        parameters.longitude = lng;
        parameters.radius = km_range;
      } else {
        if (areaId) {
          parameters.area_id = areaId;
        } else if (city) {
          parameters.city = city;
        } else if (state) {
          parameters.state = state;
        } else if (country) {
          parameters.country = country;
        }
      }
      if (query) {
        parameters.search = query;
      }
      page === 1
        ? setAdvertisements((prev) => ({ ...prev, isLoading: true }))
        : setAdvertisements((prev) => ({ ...prev, isLoadMore: true }));

      const res = await allItemApi.getItems(parameters);
      const data = res?.data;

      if (data.error === false) {
        page > 1
          ? setAdvertisements((prev) => ({
            ...prev,
            data: [...prev.data, ...data?.data?.data],
            currentPage: data?.data?.current_page,
            hasMore: data?.data?.last_page > data?.data?.current_page,
          }))
          : setAdvertisements((prev) => ({
            ...prev,
            data: data?.data?.data,
            currentPage: data?.data?.current_page,
            hasMore: data?.data?.last_page > data?.data?.current_page,
          }));
      }
    } catch (error) {
      console.log(error);
    } finally {
      setAdvertisements((prev) => ({
        ...prev,
        isLoading: false,
        isLoadMore: false,
      }));
    }
  };

  const handleProdLoadMore = async () => {
    setAdvertisements((prev) => ({ ...prev, isLoadMore: true }));
    await getSingleCatItem(advertisements.currentPage + 1);
  };

  const handleSortBy = (value) => {
    newSearchParams.set("sort_by", value);
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleLike = (id) => {
    const updatedItems = advertisements.data.map((item) => {
      if (item.id === id) {
        return { ...item, is_liked: !item.is_liked };
      }
      return item;
    });
    setAdvertisements((prev) => ({ ...prev, data: updatedItems }));
  };

  const handleClearLocation = () => {
    newSearchParams.delete("country");
    newSearchParams.delete("state");
    newSearchParams.delete("city");
    newSearchParams.delete("area");
    newSearchParams.delete("areaId");
    newSearchParams.delete("lat");
    newSearchParams.delete("lng");
    newSearchParams.delete("km_range");
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearRange = () => {
    newSearchParams.delete("km_range");
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearDatePosted = () => {
    newSearchParams.delete("date_posted");
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearBudget = () => {
    newSearchParams.delete("min_price");
    newSearchParams.delete("max_price");
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearFeaturedSection = () => {
    newSearchParams.delete("featured_section");
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearCategory = () => {
    newSearchParams.delete("category");
    Object.keys(extraDetails || {})?.forEach((key) => {
      newSearchParams.delete(key);
    });
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearExtraDetail = (keyToRemove) => {
    const updatedExtraDetails = { ...extraDetails };
    delete updatedExtraDetails[keyToRemove];
    setExtraDetails(updatedExtraDetails);

    newSearchParams.delete(keyToRemove);
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearAll = () => {
    newSearchParams.delete("country");
    newSearchParams.delete("state");
    newSearchParams.delete("city");
    newSearchParams.delete("area");
    newSearchParams.delete("areaId");
    newSearchParams.delete("lat");
    newSearchParams.delete("lng");
    newSearchParams.delete("km_range");
    newSearchParams.delete("date_posted");
    newSearchParams.delete("min_price");
    newSearchParams.delete("max_price");
    newSearchParams.delete("category");
    newSearchParams.delete("query");
    newSearchParams.delete("featured_section");
    Object.keys(initialExtraDetails || {})?.forEach((key) => {
      newSearchParams.delete(key);
    });
    setExtraDetails({});
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const handleClearQuery = () => {
    newSearchParams.delete("query");
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };

  const postedSince =
    date_posted === "all-time"
      ? t("allTime")
      : date_posted === "today"
        ? t("today")
        : date_posted === "within-1-week"
          ? t("within1Week")
          : date_posted === "within-2-week"
            ? t("within2Weeks")
            : date_posted === "within-1-month"
              ? t("within1Month")
              : date_posted === "within-3-month"
                ? t("within3Months")
                : "";

  return (
    <Layout>
      <BreadCrumb />
      <div className="container mt-8">
        <div className="flex flex-col">
          <h1 className="text-2xl font-semibold mb-6">{title}</h1>
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
            <div className="xl:col-span-3 lg:col-span-4 col-span-1">
              <Filter
                customFields={customFields}
                extraDetails={extraDetails}
                setExtraDetails={setExtraDetails}
                newSearchParams={newSearchParams}
                country={country}
                state={state}
                city={city}
                area={area}
              />
            </div>
            <div className="xl:col-span-9 lg:col-span-8 col-span-1 flex flex-col gap-5">
              <div className="flex justify-between items-center">
                <div>
                  <div className="flex flex-col md:flex-row  items-start md:items-center gap-2">
                    <div className="flex gap-2 items-center whitespace-nowrap">
                      <TbTransferVertical />
                      {t("sortBy")}
                    </div>
                    <Select value={sortBy} onValueChange={handleSortBy}>
                      <SelectTrigger className="max-w-[180px] font-semibold">
                        <SelectValue
                          placeholder={t("sortBy")}
                          className="font-semibold"
                        />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectGroup className="font-semibold">
                          <SelectItem value="new-to-old">
                            {t("newestToOldest")}
                          </SelectItem>
                          <SelectItem value="old-to-new">
                            {t("oldestToNewest")}
                          </SelectItem>
                          <SelectItem value="price-high-to-low">
                            {t("priceHighToLow")}
                          </SelectItem>
                          <SelectItem value="price-low-to-high">
                            {t("priceLowToHigh")}
                          </SelectItem>
                          <SelectItem value="popular_items">
                            {t("popular")}
                          </SelectItem>
                        </SelectGroup>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setView("list")}
                    className={`text-muted-foreground p-3 rounded-full ${view === "list" ? "bg-primary text-white" : ""
                      }`}
                  >
                    <CiGrid2H size={22} />
                  </button>
                  <button
                    onClick={() => setView("grid")}
                    className={` text-muted-foreground  p-3 rounded-full  ${view === "grid" ? "bg-primary text-white" : ""
                      }`}
                  >
                    <IoGrid size={22} />
                  </button>
                </div>
              </div>

              <div className="flex items-center justify-between gap-2">
                <div className="flex gap-2 flex-wrap">
                  {category && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("category")}: {category}
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearCategory}
                      />
                    </Badge>
                  )}

                  {query && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("search")}: {query}
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearQuery}
                      />
                    </Badge>
                  )}

                  {(country || state || city || area) && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("location")}:{" "}
                        {selectedLocation?.translated_name ||
                          selectedLocation?.name}
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearLocation}
                      />
                    </Badge>
                  )}
                  {Number(km_range) > 0 && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("nearByRange")}: {km_range} KM
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearRange}
                      />
                    </Badge>
                  )}

                  {date_posted && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("datePosted")}: {postedSince}
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearDatePosted}
                      />
                    </Badge>
                  )}

                  {isMinPrice && max_price && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("budget")}: {min_price}-{max_price}
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearBudget}
                      />
                    </Badge>
                  )}

                  {featured_section && (
                    <Badge
                      variant="outline"
                      className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                    >
                      <span>
                        {t("featuredSection")}: {featuredTitle}
                      </span>
                      <IoIosCloseCircle
                        size={22}
                        className="cursor-pointer "
                        onClick={handleClearFeaturedSection}
                      />
                    </Badge>
                  )}
                  {initialExtraDetails &&
                    Object.entries(initialExtraDetails || {}).map(
                      ([key, value]) => {
                        const field = customFields.find(
                          (f) => f.id.toString() === key.toString()
                        );

                        const fieldName = field?.translated_name || field?.name;

                        // Function to get translated value
                        const getTranslatedValue = (val) => {
                          if (!field?.values || !field?.translated_value)
                            return val;
                          const idx = field.values.indexOf(val);
                          return idx !== -1 ? field.translated_value[idx] : val;
                        };

                        const displayValue = Array.isArray(value)
                          ? value.map((v) => getTranslatedValue(v)).join(", ")
                          : getTranslatedValue(value);

                        return (
                          <Badge
                            key={key}
                            variant="outline"
                            className="px-4 text-base font-normal py-2 rounded-full flex items-center gap-2 bg-muted"
                          >
                            <span>
                              {fieldName}: {displayValue}
                            </span>
                            <IoIosCloseCircle
                              size={22}
                              className="cursor-pointer"
                              onClick={() => handleClearExtraDetail(key)}
                            />
                          </Badge>
                        );
                      }
                    )}
                </div>
                {activeFilterCount > 1 && (
                  <button
                    className="text-primary whitespace-nowrap"
                    onClick={handleClearAll}
                  >
                    {t("clearAll")}
                  </button>
                )}
              </div>

              <div className="grid grid-cols-12 gap-4">
                {advertisements?.isLoading ? (
                  Array.from({ length: 12 }).map((_, index) =>
                    view === "list" ? (
                      <div className="col-span-12" key={index}>
                        <ProductHorizontalCardSkeleton />
                      </div>
                    ) : (
                      <div
                        key={index}
                        className="col-span-12 sm:col-span-6 xl:col-span-4"
                      >
                        <ProductCardSkeleton />
                      </div>
                    )
                  )
                ) : advertisements.data && advertisements.data.length > 0 ? (
                  advertisements.data?.map((item, index) =>
                    view === "list" ? (
                      <div className="col-span-12" key={index}>
                        <ProductHorizontalCard
                          item={item}
                          handleLike={handleLike}
                        />
                      </div>
                    ) : (
                      <div
                        className="col-span-12 sm:col-span-6 xl:col-span-4"
                        key={index}
                      >
                        <ProductCard item={item} handleLike={handleLike} />
                      </div>
                    )
                  )
                ) : (
                  <div className="col-span-12">
                    <NoData name={t("ads")} />
                  </div>
                )}
              </div>
              {advertisements.data &&
                advertisements.data.length > 0 &&
                advertisements.hasMore && (
                  <div className="text-center mt-6">
                    <Button
                      variant="outline"
                      className="text-sm sm:text-base text-primary w-[256px]"
                      disabled={
                        advertisements.isLoading || advertisements.isLoadMore
                      }
                      onClick={handleProdLoadMore}
                    >
                      {advertisements.isLoadMore ? t("loading") : t("loadMore")}
                    </Button>
                  </div>
                )}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default Ads;
