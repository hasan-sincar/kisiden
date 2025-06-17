import LandingPage from "@/components/LandingPage"
import Layout from "@/components/Layout/Layout"

export const generateMetadata = async () => {
    try {
        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=landing`,
            { next: { revalidate: 3600 } } // Revalidate every 1 hour
        );
        const data = await res.json();
        const landing = data?.data?.[0];

        return {
            title: landing?.title ? landing?.title : process.env.NEXT_PUBLIC_META_TITLE,
            description: landing?.description ? landing?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
            openGraph: {
                images: landing?.image ? [landing?.image] : [],
            },
            keywords: landing?.keywords ? landing?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
        };
    } catch (error) {
        console.error("Error fetching MetaData:", error);
        return null;
    }
};
const HomePage = () => {
    return (
        <Layout>
            <LandingPage />
        </Layout>
    )
}

export default HomePage