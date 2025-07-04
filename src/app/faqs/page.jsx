import Layout from '@/components/Layout/Layout';
import FAQS from '@/components/PagesComponent/FAQS/FAQS'


export const generateMetadata = async () => {
    try {
        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=faqs`,
            { next: { revalidate: 3600 } } // Revalidate every 1 hour
        );
        const data = await res.json();
        const faqs = data?.data?.[0];

        return {
            title: faqs?.title ? faqs?.title : process.env.NEXT_PUBLIC_META_TITLE,
            description: faqs?.description ? faqs?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
            openGraph: {
                images: faqs?.image ? [faqs?.image] : [],
            },
            keywords: faqs?.keywords ? faqs?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
        };
    } catch (error) {
        console.error("Error fetching MetaData:", error);
        return null;
    }
};

const page = () => {
    return (
        <Layout>
            <FAQS />
        </Layout>
    )
}

export default page
