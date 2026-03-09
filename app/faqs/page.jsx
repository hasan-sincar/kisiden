import FaqsPage from "@/components/PagesComponent/Faq/FaqsPage";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";

export const dynamic = "force-dynamic";

export const generateMetadata = async ({ searchParams }) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    const params = await searchParams;
    const langCode = params?.lang || "en";
    const response = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=faqs`,
      {
        headers: {
          "Content-Language": langCode || "en",
        },
        next: {
          revalidate: SEO_REVALIDATE_SECONDS,
        },
      }
    );
    const data = await response.json();
    const faqs = data?.data?.[0];
    return {
      title: faqs?.translated_title || process.env.NEXT_PUBLIC_META_TITLE,
      description:
        faqs?.translated_description ||
        process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: faqs?.image ? [faqs?.image] : [],
      },
      keywords:
        faqs?.translated_keywords || process.env.NEXT_PUBLIC_META_kEYWORDS,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const page = () => {
  return <FaqsPage />;
};

export default page;
