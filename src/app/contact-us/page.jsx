import Layout from "@/components/Layout/Layout";
import ContactUs from "@/components/PagesComponent/ContactUs/ContactUs"

export const generateMetadata = async () => {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=contact-us`,
      { next: { revalidate: 3600 } } // Revalidate every 1 hour
    );
    const data = await res.json();
    const contactUs = data?.data?.[0];

    return {
      title: contactUs?.title ? contactUs?.title : process.env.NEXT_PUBLIC_META_TITLE,
      description: contactUs?.description ? contactUs?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: contactUs?.image ? [contactUs?.image] : [],
      },
      keywords: contactUs?.keywords ? contactUs?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const ContactUsPage = () => {
  return (
    <Layout>
      <ContactUs />
    </Layout>
  
  )
}

export default ContactUsPage