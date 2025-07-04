import Layout from "@/components/Layout/Layout";
import Subscription from "@/components/PagesComponent/Subscription/Subscription"

export const generateMetadata = async () => {
    
    try {
    
        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=subscription`,
            {
                next: { revalidate: 3600 }, // Revalidate every 1 hour
            }
        );

        const data = await res.json();
        const subscription = data?.data?.[0];

        return {
            title: subscription?.title ? subscription?.title : process.env.NEXT_PUBLIC_META_TITLE,
            description: subscription?.description ? subscription?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
            openGraph: {
                images: subscription?.image ? [subscription?.image] : [],
            },
            keywords: subscription?.keywords ? subscription?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
        };
    } catch (error) {
        console.error("Error fetching MetaData:", error);
        return null;
    }
};
const SubscriptionPage = () => {
    return (
        <Layout>
            <Subscription />
        </Layout>
    )
}

export default SubscriptionPage