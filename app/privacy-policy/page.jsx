import PrivacyPolicy from "@/components/PagesComponent/StaticPages/PrivacyPolicy";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";

export const dynamic = "force-dynamic";

export const generateMetadata = async ({ searchParams }) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    const params = await searchParams;
    const langCode = params?.lang || "en";
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=privacy-policy`,
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
    const privacyPolicy = data?.data?.[0];

    return {
      title:
        privacyPolicy?.translated_title || process.env.NEXT_PUBLIC_META_TITLE,
      description:
        privacyPolicy?.translated_description ||
        process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: privacyPolicy?.image ? [privacyPolicy?.image] : [],
      },
      keywords:
        privacyPolicy?.translated_keywords ||
        process.env.NEXT_PUBLIC_META_kEYWORDS,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const PrivacyPolicyPage = () => {
  return <PrivacyPolicy />;
};
export default PrivacyPolicyPage;
