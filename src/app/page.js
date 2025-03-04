import HomePage from '@/components/Home';
import Layout from '@/components/Layout/Layout';
import axios from 'axios';

export const generateMetadata = async () => {
  try {
    const response = await axios.get(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=home`
    );
    const home = response?.data
    return {
      title: home?.title ? home?.title : process.env.NEXT_PUBLIC_META_TITLE,
      description: home?.description ? home?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: home?.image ? [home?.image] : [],
      },
      keywords: home?.keywords ? home?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const fetchCategories = async () => {
  try {
    const response = await axios.get(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-categories`,
      { params: { page: 1 } }
    );
    return response?.data?.data?.data || [];
  } catch (error) {
    console.error("Error fetching Categories Data:", error);
    return [];
  }
};
const fetchProductItems = async () => {
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
};
const fetchFeaturedSections = async () => {
  try {
    const response = await axios.get(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-featured-section`
    );
    return response?.data?.data || [];
  } catch (error) {
    console.error('Error fetching Featured sections Data:', error);
    return [];
  }
};

const index = async () => {

  const categoriesData = await fetchCategories();
  const productItemsData = await fetchProductItems();
  const featuredSectionsData = await fetchFeaturedSections();

  const existingSlugs = new Set(productItemsData.map(product => product.slug));

  let featuredItems = [];
  featuredSectionsData.forEach((section) => {
    section.section_data.slice(0, 4).forEach(item => {
      if (!existingSlugs.has(item.slug)) {
        featuredItems.push(item);
        existingSlugs.add(item.slug);  // Mark this item as included
      }
    });
  });

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    itemListElement: [
      ...categoriesData.map((category, index) => ({
        "@type": "ListItem",
        position: index + 1,
        item: {
          "@type": "Thing", // No "Category" type in Schema.org
          name: category?.name,
          url: `${process.env.NEXT_PUBLIC_WEB_URL}/category/${category?.slug}`
        }
      })),
      ...productItemsData.map((product, index) => ({
        "@type": "ListItem",
        position: categoriesData?.length + index + 1, // Ensure unique positions
        item: {
          "@type": "Product",
          name: product?.name,
          productID: product?.id,
          description: product?.description,
          image: product?.image,
          url: `${process.env.NEXT_PUBLIC_WEB_URL}/product-details/${product?.slug}`,
          category: product?.category?.name,
          "offers": {
            "@type": "Offer",
            price: product?.price,
            priceCurrency: "USD",
          },
          countryOfOrigin: product?.country
        }
      })),
      ...featuredItems.map((item, index) => ({
        "@type": "ListItem",
        position: categoriesData.length + productItemsData.length + index + 1, // Ensure unique positions
        item: {
          "@type": "Product", // Assuming items from featured sections are products
          name: item?.name,
          productID: item?.id,
          description: item?.description,
          image: item?.image,
          url: `${process.env.NEXT_PUBLIC_WEB_URL}/product-details/${item?.slug}`,
          category: item?.category?.name,
          "offers": {
            "@type": "Offer",
            price: item?.price,
            priceCurrency: "USD",
          },
          countryOfOrigin: item?.country
        }
      }))
    ]
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <Layout>
        <HomePage />
      </Layout>
    </>
  )
}

export default index

