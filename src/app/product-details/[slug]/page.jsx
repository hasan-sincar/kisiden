import Layout from "@/components/Layout/Layout";
import SingleProductDetail from "@/components/PagesComponent/SingleProductDetail/SingleProductDetail";
import axios from "axios";
export const generateMetadata = async ({ params }) => {
  try {
    const response = await axios.get(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item?slug=${params?.slug}`
    );

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

    const generateKeywords = (description) => {
      if (!description) {
        return process.env.NEXT_PUBLIC_META_kEYWORDS
          ? process.env.NEXT_PUBLIC_META_kEYWORDS.split(",").map((keyword) =>
              keyword.trim()
            )
          : [];
      }

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

    const selfCategory = response?.data?.data?.data[0];
    const title = selfCategory?.name;
    const description = selfCategory?.description;
    const keywords = generateKeywords(selfCategory?.description);
    const image = selfCategory?.image;

    const jsonLd = {
      "@context": "https://schema.org",
      "@type": "Product",
      productID: selfCategory?.id,
      name: title,
      description: description,
      image: image,
      url: `${process.env.NEXT_PUBLIC_WEB_URL}/product-details/${selfCategory?.slug}`,
      category: {
        "@type": "Thing",
        name: selfCategory?.category?.name || "General Category", // Default category name
      },
      offers: {
        "@type": "Offer",
        price: selfCategory?.price,
        priceCurrency: "USD",
      },
      countryOfOrigin: selfCategory?.country,
    };

    return {
      title: title ? title : process.env.NEXT_PUBLIC_META_TITLE,
      description: description
        ? description
        : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: image ? [image] : [],
      },
      keywords: keywords,
      jsonLd: JSON.stringify(jsonLd),
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};
const SingleProductDetailPage = async ({ params }) => {
  const metadata = await generateMetadata({ params });
  const jsonld = metadata?.jsonLd;
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: jsonld }}
      />
      <Layout>
        <SingleProductDetail slug={params?.slug} />
      </Layout>
    </>
  );
};

export default SingleProductDetailPage;
