import StructuredData from "@/components/Layout/StructuredData";
import ProductDetail from "@/components/PagesComponent/ProductDetail/ProductDetails";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";
import { generateKeywords } from "@/utils/generateKeywords";

export const generateMetadata = async ({ params, searchParams }) => {
  if (process.env.NEXT_PUBLIC_SEO === "false") return;
  try {
    const { slug } = await params;
    const langCode = (await searchParams)?.lang || "en";
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item?slug=${slug}`,
      {
        headers: {
          "Content-Language": langCode || "en",
        },
        next: {
          revalidate: SEO_REVALIDATE_SECONDS,
        },
      }
    );

    const data = await res.json();
    const item = data?.data?.data?.[0];
    const title = item?.translated_item?.name;
    const description = item?.translated_item?.description;
    const keywords = generateKeywords(item?.translated_item?.description);
    const image = item?.image;

    return {
      title: title || process.env.NEXT_PUBLIC_META_TITLE,
      description: description || process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: image ? [image] : [],
      },
      keywords: keywords,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const getItemData = async (slug, langCode) => {
  if (process.env.NEXT_PUBLIC_SEO === "false") return;
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item?slug=${slug}`,
      {
        headers: {
          "Content-Language": langCode || "en",
        },
        next: {
          revalidate: SEO_REVALIDATE_SECONDS,
        },
      }
    );

    const data = await res.json();
    const item = data?.data?.data?.[0];
    return item;
  } catch (error) {
    console.error("Error fetching item data:", error);
    return null;
  }
};

const ProductDetailPage = async ({ params, searchParams }) => {
  const { slug } = await params;
  const langCode = (await searchParams).lang || "en";
  const product = await getItemData(slug, langCode);
  const jsonLd = product
    ? {
        "@context": "https://schema.org",
        "@type": "Product",
        productID: product?.id,
        name: product?.translated_item?.name,
        description: product?.translated_item?.description,
        image: product?.image,
        url: `${process.env.NEXT_PUBLIC_WEB_URL}/ad-details/${product?.slug}`,
        category: {
          "@type": "Thing",
          name: product?.category?.translated_name || "General Category", // Default category name
        },
        ...(product?.price && {
          offers: {
            "@type": "Offer",
            price: product.price,
            priceCurrency: "USD",
          },
        }),
        countryOfOrigin: product?.translated_item?.country,
      }
    : null;

  return (
    <>
      <StructuredData data={jsonLd} />
      <ProductDetail slug={slug} />
    </>
  );
};

export default ProductDetailPage;
