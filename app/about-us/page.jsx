import AboutUs from "@/components/PagesComponent/StaticPages/AboutUs";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";

export const dynamic = "force-dynamic";


export const generateMetadata = async ({ searchParams }) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    const params = await searchParams;
    const langCode = params?.lang || "en";
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=about-us`,
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
    const aboutUs = data?.data?.[0];

    return {
      title: aboutUs?.translated_title || process.env.NEXT_PUBLIC_META_TITLE,
      description:
        aboutUs?.translated_description ||
        process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: aboutUs?.image ? [aboutUs?.image] : [],
      },
      keywords:
        aboutUs?.translated_keywords || process.env.NEXT_PUBLIC_META_kEYWORDS,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const AboutUsPage = () => {
  return <AboutUs />;
};

export default AboutUsPage;
