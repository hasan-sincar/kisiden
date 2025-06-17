import Layout from "@/components/Layout/Layout";
import SingleProductDetail from "@/components/PagesComponent/SingleProductDetail/SingleProductDetail";
import JsonLd from "@/components/SEO/JsonLd";

export const generateMetadata = async ({ params }) => {
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item?slug=${params?.slug}`, { next: { revalidate: 3600 } });
    const data = await res.json();
    const item = data?.data?.data?.[0];
    const title = item?.name;
    const description = item?.description;
    const keywords = generateKeywords(item?.description);
    const image = item?.image;

    return {
      title: title ? title : process.env.NEXT_PUBLIC_META_TITLE,
      description: description ? description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
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

const generateKeywords = (description) => {


  if (!description) {
    return process.env.NEXT_PUBLIC_META_kEYWORDS
      ? process.env.NEXT_PUBLIC_META_kEYWORDS.split(",").map((keyword) =>
        keyword.trim()
      )
      : [];
  }


  const stopWords = [
    "the",
    "is",
    "in",
    "and",
    "a",
    "to",
    "of",
    "for",
    "on",
    "at",
    "with",
    "by",
    "this",
    "that",
    "or",
    "as",
    "an",
    "from",
    "it",
    "was",
    "are",
    "be",
    "has",
    "have",
    "had",
    "but",
    "if",
    "else",
  ];

  // Convert description to lowercase, remove punctuation, and split into words
  const words = description
    .toLowerCase()
    .replace(/[^\w\s]/g, "")
    .split(/\s+/);

  // Filter out common stop words
  const filteredWords = words.filter((word) => !stopWords.includes(word));

  // Count the frequency of each word
  const wordFrequency = filteredWords.reduce((acc, word) => {
    acc[word] = (acc[word] || 0) + 1;
    return acc;
  }, {});

  // Sort words by frequency and return the top keywords
  const sortedWords = Object.keys(wordFrequency).sort(
    (a, b) => wordFrequency[b] - wordFrequency[a]
  );

  // Return top 10 keywords (or less if there are fewer words)
  return sortedWords.slice(0, 10);
};


const getItemData = async (slug) => {
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item?slug=${slug}`, { next: { revalidate: 86400 } });
    const data = await res.json();
    const item = data?.data?.data?.[0];
    return item;
  } catch (error) {
    console.error("Error fetching item data:", error);
    return null;
  }
}


const SingleProductDetailPage = async ({ params }) => {
  const product = await getItemData(params?.slug);
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "Product",
    productID: product?.id,
    name: product?.name,
    description: product?.description,
    image: product?.image,
    url: `${process.env.NEXT_PUBLIC_WEB_URL}/product-details/${product?.slug}`,
    category: {
      "@type": "Thing",
      name: product?.category?.name || "General Category", // Default category name
    },
    ...(product?.price && {
      offers: {
        "@type": "Offer",
        price: product.price,
        priceCurrency: "USD",
      },
    }),
    countryOfOrigin: product?.country,
  };

  return (
    <>
      <JsonLd data={jsonLd} />
      <Layout>
        <SingleProductDetail slug={params?.slug} />
      </Layout>
    </>
  );
};

export default SingleProductDetailPage;
