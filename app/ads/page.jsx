import StructuredData from "@/components/Layout/StructuredData";
import Products from "@/components/PagesComponent/Ads/Ads";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";
import { generateKeywords } from "@/utils/generateKeywords";

export const dynamic = "force-dynamic";

const buildIndexableParams = (searchParams) => {
  const {
    category,
    query,
    country,
    state,
    city,
    areaId,
    sortBy,
    min_price,
    max_price,
    date_posted,
    lat,
    lng,
    km_range,
  } = searchParams || {};
  const params = new URLSearchParams();
  // Non-location filters
  if (category) params.append("category_slug", category);
  if (query) params.append("search", query);
  if (sortBy) params.append("sort_by", sortBy);
  if (min_price) params.append("min_price", Number(min_price));
  if (max_price) params.append("max_price", Number(max_price));
  if (date_posted) params.append("posted_since", date_posted);
  // Location logic
  if (Number(km_range) > 0) {
    if (lat) params.append("latitude", lat);
    if (lng) params.append("longitude", lng);
    params.append("radius", km_range);
  } else {
    if (areaId) {
      params.append("area_id", Number(areaId));
    } else if (city) {
      params.append("city", city);
    } else if (state) {
      params.append("state", state);
    } else if (country) {
      params.append("country", country);
    }
  }
  return params.toString();
};

const buildCanonicalParams = (searchParams) => {
  const params = new URLSearchParams();
  const { category, query, lang } = searchParams || {};
  if (category) params.append("category", category);
  if (query) params.append("search", query);
  // Add lang to canonical params for consistency with sitemap
  if (lang) params.append("lang", lang);
  return params.toString();
};

export const generateMetadata = async ({ searchParams }) => {
  if (process.env.NEXT_PUBLIC_SEO === "false") return;

  try {
    const originalSearchParams = await searchParams;
    const langCode = originalSearchParams?.lang || "en";
    const slug = originalSearchParams?.category || ""; // change to your param name if needed

    let title = process.env.NEXT_PUBLIC_META_TITLE;
    let description = process.env.NEXT_PUBLIC_META_DESCRIPTION;
    let keywords = process.env.NEXT_PUBLIC_META_kEYWORDS;
    let image = "";

    if (slug) {
      // Fetch category-specific SEO
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-categories?slug=${slug}`,
        {
          headers: { "Content-Language": langCode || "en" },
          next: {
            revalidate: SEO_REVALIDATE_SECONDS,
          },
        }
      );

      const data = await response.json();
      const selfCategory = data?.self_category;

      title = selfCategory?.translated_name || title;
      description = selfCategory?.translated_description || description;
      keywords =
        generateKeywords(selfCategory?.translated_description) || keywords;
      image = selfCategory?.image || image;
    } else {
      // Fetch default ad listing SEO
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=ad-listing`,
        {
          headers: { "Content-Language": langCode || "en" },
          next: {
            revalidate: SEO_REVALIDATE_SECONDS,
          },
        }
      );
      const data = await res.json();
      const adListing = data?.data?.[0];

      title = adListing?.translated_title || title;
      description = adListing?.translated_description || description;
      keywords = adListing?.translated_keywords || keywords;
      image = adListing?.image || image;
    }

    const baseUrl = process.env.NEXT_PUBLIC_WEB_URL;
    const paramsStr = buildCanonicalParams(originalSearchParams);
    const canonicalUrl = `${baseUrl}/ads${paramsStr ? `?${paramsStr}` : ""}`;

    return {
      title,
      description,
      openGraph: {
        images: image ? [image] : [],
      },
      keywords,
      alternates: {
        canonical: canonicalUrl,
      },
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const getAllItems = async (langCode, searchParams) => {
  if (process.env.NEXT_PUBLIC_SEO === "false") return;

  try {
    const queryString = buildIndexableParams(searchParams)
      ? buildIndexableParams(searchParams)
      : "";
    const url = `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT
      }get-item?page=1${queryString ? `&${queryString}` : ""}`;

    const res = await fetch(url, {
      headers: {
        "Content-Language": langCode || "en",
      },
      next: {
        revalidate: SEO_REVALIDATE_SECONDS,
      },
    });

    const data = await res.json();
    return data?.data?.data || [];
  } catch (error) {
    console.error("Error fetching Product Items Data:", error);
    return [];
  }
};

const AdsPage = async ({ searchParams }) => {
  const originalSearchParams = await searchParams;
  const langCode = originalSearchParams?.lang || "en";
  const AllItems = await getAllItems(langCode, originalSearchParams);

  const jsonLd = AllItems
    ? {
      "@context": "https://schema.org",
      "@type": "ItemList",
      itemListElement: AllItems.map((product, index) => ({
        "@type": "ListItem",
        position: index + 1, // Position starts at 1
        item: {
          "@type": "Product",
          productID: product?.id,
          name: product?.translated_item?.name || "",
          description: product?.translated_item?.description || "",
          image: product?.image || "",
          url: `${process.env.NEXT_PUBLIC_WEB_URL}/ad-details/${product?.slug}`,
          category: {
            "@type": "Thing",
            name: product?.category?.translated_name || "",
          },
          offers: {
            "@type": "Offer",
            price: product.price || undefined,
            priceCurrency: product?.price ? "USD" : undefined,
            availability: product?.price
              ? "https://schema.org/InStock"
              : "https://schema.org/PreOrder",
          },
          countryOfOrigin: product?.translated_item?.country || "",
        },
      })),
    }
    : null;

  return (
    <>
      <StructuredData data={jsonLd} />
      <Products searchParams={originalSearchParams} />
    </>
  );
};
export default AdsPage;
