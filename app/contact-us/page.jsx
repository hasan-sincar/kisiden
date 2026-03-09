import ContactUs from "@/components/PagesComponent/Contact/ContactUs";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";

export const dynamic = "force-dynamic";


export const generateMetadata = async ({ searchParams }) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    const params = await searchParams;
    const langCode = params?.lang || "en";
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=contact-us`,
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
    const contactUs = data?.data?.[0];
    return {
      title: contactUs?.translated_title || process.env.NEXT_PUBLIC_META_TITLE,
      description:
        contactUs?.translated_description ||
        process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: contactUs?.image ? [contactUs?.image] : [],
      },
      keywords:
        contactUs?.translated_keywords || process.env.NEXT_PUBLIC_META_kEYWORDS,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const ContactUsPage = () => {
  return <ContactUs />;
};

export default ContactUsPage;
