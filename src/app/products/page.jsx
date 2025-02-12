import Layout from "@/components/Layout/Layout";
import Products from "@/components/PagesComponent/Products/Products"
import axios from "axios";


export const generateMetadata = async () => {
    try {
        const response = await axios.get(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=ad-listing`
        );
        const adListing = response?.data?.data[0]

        return {
            title: adListing?.title ? adListing?.title : process.env.NEXT_PUBLIC_META_TITLE,
            description: adListing?.description ? adListing?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
            openGraph: {
                images: adListing?.image ? [adListing?.image] : [],
            },
            keywords: adListing?.keywords ? adListing?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
        };
    } catch (error) {
        console.error("Error fetching MetaData:", error);
        return null;
    }
};

const getAllItems = async () => {
    try {
        const response = await axios.get(
            `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-item`,
            { params: { page: 1 } }
        );
        return response?.data?.data?.data || [];
    } catch (error) {
        console.error('Error fetching Product Items Data:', error);
        return [];
    }
}

const ProductsPage = async () => {

    const AllItems = await getAllItems()

    const jsonLd = {
        "@context": "https://schema.org",
        "@type": "ItemList",
        itemListElement: AllItems.map((product, index) => ({
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
                offers: {
                    "@type": "Offer",
                    price: product?.price,
                    priceCurrency: "USD",
                },
                countryOfOrigin: product?.country,
            }
        }))
    };

    return (
        <>
            <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
            <Layout>
                <Products />
            </Layout>
        </>
    )
}

export default ProductsPage