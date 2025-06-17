import Layout from '@/components/Layout/Layout';
import TermsAndCondition from '@/components/PagesComponent/TermsAndCondition/TermsAndCondition'


export const generateMetadata = async () => {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=terms-and-conditions`,
      { next: { revalidate: 3600 } } // Revalidate every 1 hour
    );
    const data = await res.json();
    const termsAndConditions = data?.data?.[0];

    return {
      title: termsAndConditions?.title ? termsAndConditions?.title : process.env.NEXT_PUBLIC_META_TITLE,
      description: termsAndConditions?.description ? termsAndConditions?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: termsAndConditions?.image ? [termsAndConditions?.image] : [],
      },
      keywords: termsAndConditions?.keywords ? termsAndConditions?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};


const TermsAndConditionPage = () => {
    return (
        <Layout>
            <TermsAndCondition />
        </Layout>
    )
}

export default TermsAndConditionPage
