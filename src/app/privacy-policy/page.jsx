import Layout from '@/components/Layout/Layout';
import PrivacyPolicy from '@/components/PagesComponent/PrivacyPolicy/PrivacyPolicy'


export const generateMetadata = async () => {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=privacy-policy`,
      { next: { revalidate: 3600 } } // Revalidate every 1 hour
    );
    const data = await res.json();
    const privacyPolicy = data?.data?.[0];

    return {
      title: privacyPolicy?.title ? privacyPolicy?.title : process.env.NEXT_PUBLIC_META_TITLE,
      description: privacyPolicy?.description ? privacyPolicy?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: privacyPolicy?.image ? [privacyPolicy?.image] : [],
      },
      keywords: privacyPolicy?.keywords ? privacyPolicy?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};


const PrivacyPolicyPage = () => {
  return (
    <Layout>
      <PrivacyPolicy />
    </Layout>
  )
}

export default PrivacyPolicyPage
