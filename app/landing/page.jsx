import Layout from "@/components/Layout/Layout";
import AnythingYouWant from "@/components/PagesComponent/LandingPage/AnythingYouWant";
import OurBlogs from "@/components/PagesComponent/LandingPage/OurBlogs";
import QuickAnswers from "@/components/PagesComponent/LandingPage/QuickAnswers";
import WorkProcess from "@/components/PagesComponent/LandingPage/WorkProcess";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";

export const dynamic = "force-dynamic";

export const generateMetadata = async ({ searchParams }) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    const params = await searchParams;
    const langCode = params?.lang || "en";
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=landing`,
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
    const landing = data?.data?.[0];

    return {
      title: landing?.translated_title || process.env.NEXT_PUBLIC_META_TITLE,
      description:
        landing?.translated_description ||
        process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: landing?.image ? [landing?.image] : [],
      },
      keywords:
        landing?.translated_keywords || process.env.NEXT_PUBLIC_META_kEYWORDS,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const LandingPage = () => {
  return (
    <Layout>
      <AnythingYouWant />
      <WorkProcess />
      <OurBlogs />
      <QuickAnswers />
    </Layout>
  );
};

export default LandingPage;
