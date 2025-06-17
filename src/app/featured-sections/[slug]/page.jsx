import Layout from '@/components/Layout/Layout';
import FeaturedViewAll from '@/components/PagesComponent/FeaturedViewAll/FeaturedViewAll'
import JsonLd from '@/components/SEO/JsonLd';

export const generateMetadata = async ({ params }) => {
    try {

        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-featured-section?slug=${params?.slug}`,
            { next: { revalidate: 3600 } } // 1 hour
        );

        const data = await res.json();
        const section = data?.data?.[0];

        const stopWords = ['the', 'is', 'in', 'and', 'a', 'to', 'of', 'for', 'on', 'at', 'with', 'by', 'this', 'that', 'or', 'as', 'an', 'from', 'it', 'was', 'are', 'be', 'has', 'have', 'had', 'but', 'if', 'else'];

        const generateKeywords = (description) => {
            if (!description) {
                return process.env.NEXT_PUBLIC_META_kEYWORDS
                    ? process.env.NEXT_PUBLIC_META_kEYWORDS.split(',').map(keyword => keyword.trim())
                    : [];
            }

            // Convert description to lowercase, remove punctuation, and split into words
            const words = description
                .toLowerCase()
                .replace(/[^\w\s]/g, '')
                .split(/\s+/);

            // Filter out common stop words
            const filteredWords = words.filter(word => !stopWords.includes(word));

            // Count the frequency of each word
            const wordFrequency = filteredWords.reduce((acc, word) => {
                acc[word] = (acc[word] || 0) + 1;
                return acc;
            }, {});

            // Sort words by frequency and return the top keywords
            const sortedWords = Object.keys(wordFrequency).sort((a, b) => wordFrequency[b] - wordFrequency[a]);

            // Return top 10 keywords (or less if there are fewer words)
            return sortedWords.slice(0, 10);
        }


        const title = section?.title;
        const description = section?.description
        const image = section?.image;
        const keywords = generateKeywords(title);

        return {
            title: title ? title : process.env.NEXT_PUBLIC_META_TITLE,
            description: description ? description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
            openGraph: {
                images: image ? [image] : [],
            },
            keywords: keywords
        };
    } catch (error) {
        console.error("Error fetching MetaData:", error);
        return null;
    }
};

export const fetchProductItems = async (slug) => {
    try {
        const res = await fetch(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item?page=1&featured_section_slug=${slug}`,
            { next: { revalidate: 86400 } } // Revalidate after 1 day
        );
        const data = await res.json();
        return data?.data?.data || [];
    } catch (error) {
        console.error('Error fetching Product Items Data:', error);
        return [];
    }
};



const SingleFeaturedSectionPage = async ({ params }) => {

    const ProductItems = await fetchProductItems(params?.slug)

    const jsonLd = {
        "@context": "https://schema.org",
        "@type": "ItemList",
        itemListElement: ProductItems.map((product, index) => ({
            "@type": "ListItem",
            position: index + 1, // Position starts at 1
            item: {
                "@type": "Product",
                productID: product?.id,
                name: product?.name,
                description: product?.description,
                image: product?.image,
                url: `${process.env.NEXT_PUBLIC_WEB_URL}/product-details/${product?.slug}`,
                category: {
                    "@type": "Thing",
                    name: product?.category?.name,
                },
                ...(product?.price && {
                    offers: {
                        "@type": "Offer",
                        price: product?.price,
                        priceCurrency: "USD",
                    },
                }),
                countryOfOrigin: product?.country,
            }
        }))
    };

    return (
        <>
            <JsonLd data={jsonLd} />
            <Layout>
                <FeaturedViewAll slug={params?.slug} />
            </Layout>
        </>
    )
}

export default SingleFeaturedSectionPage