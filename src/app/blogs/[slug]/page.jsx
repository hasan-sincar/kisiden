import Layout from '@/components/Layout/Layout';
import SingleBlog from '@/components/PagesComponent/SingleBlog/SingleBlog'
import JsonLd from '@/components/SEO/JsonLd';
export const generateMetadata = async ({ params }) => {
    try {
        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}blogs?slug=${params?.slug}`,
            { next: { revalidate: 3600 } } // revalidate every 1 hour
        );
        const json = await res.json();
        const data = json?.data?.data?.[0];
        const plainTextDescription = data?.description?.replace(/<\/?[^>]+(>|$)/g, "");
        return {
            title: data?.title ? data?.title : process.env.NEXT_PUBLIC_META_TITLE,
            description: plainTextDescription ? plainTextDescription : process.env.NEXT_PUBLIC_META_DESCRIPTION,
            openGraph: {
                images: data?.image ? [data?.image] : [],
            },
            keywords: data?.tags ? data?.tags : process.env.NEXT_PUBLIC_META_kEYWORDS
        };
    } catch (error) {
        console.error("Error fetching MetaData:", error);
        return null;
    }
};

const fetchSingleBlogItem = async (slug) => {
    try {
        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}blogs?slug=${slug}`,
            { next: { revalidate: 86400 } } // 1 day
        );
        const data = await res.json();
        return data?.data?.data?.[0] || [];
    } catch (error) {
        console.error('Error fetching Blog Item Data:', error);
        return [];
    }
};


const stripHtml = (html) => {
    return html.replace(/<[^>]*>/g, ''); // Regular expression to remove HTML tags
};

// Function to format the date correctly (ISO 8601)
const formatDate = (dateString) => {
    // Remove microseconds and ensure it follows ISO 8601 format
    const validDateString = dateString.slice(0, 19) + 'Z'; // Remove microseconds and add 'Z' for UTC
    return validDateString;
};


const SingleBlogPage = async ({ params }) => {

    const singleBlog = await fetchSingleBlogItem(params?.slug)

    const jsonLd = {
        "@context": "https://schema.org",
        "@type": "BlogPosting",
        headline: singleBlog?.title,
        description: singleBlog?.description ? stripHtml(singleBlog.description) : "No description available", // Strip HTML from description
        url: `${process.env.NEXT_PUBLIC_WEB_URL}/blogs/${singleBlog?.slug}`,
        image: singleBlog?.image,
        datePublished: singleBlog?.created_at ? formatDate(singleBlog.created_at) : "", // Format date to ISO 8601
        keywords: singleBlog?.tags ? singleBlog.tags.join(', ') : "", // Adding tags as keywords
    };

    return (
        <>
            <JsonLd data={jsonLd} />
            <Layout>
                <SingleBlog />
            </Layout>
        </>
    )
}

export default SingleBlogPage