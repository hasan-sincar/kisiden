import StructuredData from "@/components/Layout/StructuredData";
import Blogs from "@/components/PagesComponent/Blogs/Blogs";
import { SEO_REVALIDATE_SECONDS } from "@/lib/constants";

export const dynamic = "force-dynamic";

export const generateMetadata = async ({ searchParams }) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    const params = await searchParams;
    const langCode = params?.lang || "en";
    const response = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}seo-settings?page=blogs`,
      {
        headers: {
          "Content-Language": langCode || "en",
        },
        next: {
          revalidate: SEO_REVALIDATE_SECONDS,
        },
      }
    );

    if (!response.ok) {
      throw new Error("Failed to fetch blogs metadata");
    }
    const data = await response.json();
    const blogs = data?.data[0];
    return {
      title: blogs?.translated_title || process.env.NEXT_PUBLIC_META_TITLE,
      description:
        blogs?.translated_description ||
        process.env.NEXT_PUBLIC_META_DESCRIPTION,
      openGraph: {
        images: blogs?.image ? [blogs?.image] : [],
      },
      keywords:
        blogs?.translated_keywords || process.env.NEXT_PUBLIC_META_kEYWORDS,
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};

const stripHtml = (html) => {
  return html.replace(/<[^>]*>/g, ""); // Regular expression to remove HTML tags
};

// Function to format the date correctly (ISO 8601)
const formatDate = (dateString) => {
  // Remove microseconds and ensure it follows ISO 8601 format
  const validDateString = dateString.slice(0, 19) + "Z"; // Remove microseconds and add 'Z' for UTC
  return validDateString;
};

const fetchBlogItems = async (langCode, tag) => {
  try {
    if (process.env.NEXT_PUBLIC_SEO === "false") return;
    let url = `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}blogs`;

    if (tag) {
      url += `?tag=${encodeURIComponent(tag)}`;
    }

    const response = await fetch(url, {
      headers: {
        "Content-Language": langCode || "en",
      },
      next: {
        revalidate: SEO_REVALIDATE_SECONDS,
      },
    });

    if (!response.ok) {
      throw new Error("Failed to fetch blogs json-ld data");
    }
    const data = await response.json();
    return data?.data?.data || [];
  } catch (error) {
    console.error("Error fetching Blog Items Data:", error);
    return [];
  }
};

const BlogsPage = async ({ searchParams }) => {
  const params = await searchParams;
  const langCode = params?.lang || "en";
  const tag = params?.tag || null;
  const blogItems = await fetchBlogItems(langCode, tag);

  const jsonLd = blogItems
    ? {
        "@context": "https://schema.org",
        "@type": "ItemList",
        itemListElement: blogItems.map((blog, index) => ({
          "@type": "ListItem",
          position: index + 1,
          item: {
            "@type": "BlogPosting",
            headline: blog?.translated_title,
            description: blog?.translated_description
              ? stripHtml(blog.translated_description)
              : "No description available", // Strip HTML from description
            url: `${process.env.NEXT_PUBLIC_WEB_URL}/blogs/${blog?.slug}`,
            image: blog?.image,
            datePublished: blog?.created_at ? formatDate(blog.created_at) : "", // Format date to ISO 8601
            keywords: blog?.translated_tags
              ? blog.translated_tags.join(", ")
              : "", // Adding tags as keywords
          },
        })),
      }
    : null;
  return (
    <>
      <StructuredData data={jsonLd} />
      <Blogs />
    </>
  );
};

export default BlogsPage;
