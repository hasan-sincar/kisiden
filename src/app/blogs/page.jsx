import Layout from '@/components/Layout/Layout';
import Blogs from '@/components/PagesComponent/Blogs/Blogs'
import JsonLd from '@/components/SEO/JsonLd';

export const generateMetadata = async () => {
  try {

    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=blogs`,
      { next: { revalidate: 3600 } } // Optional: Add ISR if using in generateMetadata
    );

    const data = await res.json();
    const blogs = data?.data?.[0];

    return {
      title: blogs?.title ? blogs?.title : process.env.NEXT_PUBLIC_META_TITLE,
      description: blogs?.description ? blogs?.description : process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: blogs?.image ? [blogs?.image] : [],
      },
      keywords: blogs?.keywords ? blogs?.keywords : process.env.NEXT_PUBLIC_META_kEYWORDS
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
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

const fetchBlogItems = async () => {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}blogs`,
      { next: { revalidate: 86400 } } // 1 day in seconds
    );
    const data = await res.json();
    return data?.data?.data || [];
  } catch (error) {
    console.error('Error fetching Blog Items Data:', error);
    return [];
  }
};


const BlogsPage = async () => {

  const blogItems = await fetchBlogItems()
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    itemListElement: blogItems.map((blog, index) => ({
      "@type": "ListItem",
      position: index + 1, // Position starts at 1
      item: {
        "@type": "BlogPosting",
        headline: blog?.title,
        description: blog?.description ? stripHtml(blog.description) : "No description available", // Strip HTML from description
        url: `${process.env.NEXT_PUBLIC_WEB_URL}/blogs/${blog?.slug}`,
        image: blog?.image,
        datePublished: blog?.created_at ? formatDate(blog.created_at) : "", // Format date to ISO 8601
        keywords: blog?.tags ? blog.tags.join(', ') : "", // Adding tags as keywords
      },
    })),
  };

  return (
    <>
      <JsonLd data={jsonLd} />
      <Layout>
        <Blogs />
      </Layout>
    </>
  )
}

export default BlogsPage
