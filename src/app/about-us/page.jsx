import Layout from '@/components/Layout/Layout';
import AboutUs from '@/components/PagesComponent/AboutUs/AboutUs'


export const generateMetadata = async () => {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=about-us`,
      { next: { revalidate: 3600 } } // Revalidate every 1 hour
    );
    const data = await res.json();
    const aboutUs = data?.data?.[0];
    return {
      title: aboutUs?.title ? aboutUs?.title : process.env.NEXT_PUBLIC_META_TITLE,
      description: aboutUs?.description ? aboutUs?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: aboutUs?.image ? [aboutUs?.image] : [],
      },
      keywords: aboutUs?.keywords ? aboutUs?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};


const AboutUsPage = () => {
  return (
    <Layout>
      <AboutUs />
    </Layout>
  )
}

export default AboutUsPage
