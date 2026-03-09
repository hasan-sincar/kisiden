import { SITEMAP_REVALIDATE_SECONDS } from "@/lib/constants";

export default async function sitemap() {
  // Check if SEO is enabled via environment variable
  // If SEO is disabled, return empty array to prevent sitemap generation
  const seoEnabled = process.env.NEXT_PUBLIC_SEO === "true";
  if (!seoEnabled) {
    // Return empty sitemap when SEO is disabled
    return [];
  }

  const baseUrl = process.env.NEXT_PUBLIC_WEB_URL;
  const apiUrl = process.env.NEXT_PUBLIC_API_URL;

  let defaultLanguageCode = "en";
  let languages = [];

  try {
    const res = await fetch(
      `${apiUrl}${process.env.NEXT_PUBLIC_END_POINT}get-system-settings`,
      { next: { revalidate: SITEMAP_REVALIDATE_SECONDS } } // Revalidate weekly
    );

    if (res.ok) {
      const data = await res.json();
      defaultLanguageCode = data?.data?.default_language || "en";
      languages = data?.data?.languages || [];
    }
  } catch (error) {
    console.error("Error fetching languages for sitemap:", error);
    return [];
  }

  const publicRoutes = [
    "about-us",
    "ads",
    "blogs",
    "contact-us",
    "faqs",
    "landing",
    "privacy-policy",
    "refund-policy",
    "subscription",
    "terms-and-condition",
  ];

  // ✅ Escape XML entities
  const escapeXml = (unsafe) =>
    unsafe.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  const buildHreflangLinks = (url) => {
    const links = {};
    const separator = url.includes("?") ? "&" : "?";
    languages.forEach((lang) => {
      links[lang.code] = escapeXml(`${url}${separator}lang=${lang.code}`);
    });
    // Add x-default
    links["x-default"] = escapeXml(
      `${url}${separator}lang=${defaultLanguageCode}`
    );
    return { languages: links };
  };
  // ✅ Add default lang param to main <loc> URLs
  const withDefaultLang = (url) => {
    const separator = url.includes("?") ? "&" : "?";
    return escapeXml(`${url}${separator}lang=${defaultLanguageCode}`);
  };

  const staticSitemapEntries = publicRoutes.map((route) => {
    const url = `${baseUrl}/${route}`;
    return {
      url: withDefaultLang(url),
      lastModified: new Date(),
      changeFrequency: "weekly",
      priority: 0.9,
      alternates: buildHreflangLinks(url),
    };
  });

  // Add the base URL entry
  const baseEntry = {
    url: withDefaultLang(baseUrl),
    lastModified: new Date(),
    changeFrequency: "weekly",
    priority: 1,
    alternates: buildHreflangLinks(baseUrl),
  };

  let adEntries = [];
  try {
    const res = await fetch(
      `${apiUrl}${process.env.NEXT_PUBLIC_END_POINT}get-item-slug`,
      { next: { revalidate: SITEMAP_REVALIDATE_SECONDS } } // Revalidate weekly
    );

    if (res.ok) {
      const json = await res.json();
      const products = json?.data || [];
      adEntries = products.map((product) => {
        const url = `${baseUrl}/ad-details/${product?.slug}`;
        return {
          url: withDefaultLang(url),
          lastModified: new Date(product?.updated_at),
          changeFrequency: "weekly",
          priority: 0.8,
          alternates: buildHreflangLinks(url),
        };
      });
    }
  } catch (error) {
    console.error("Error fetching products for sitemap:", error);
  }

  let categoryEntries = [];
  try {
    const res = await fetch(
      `${apiUrl}${process.env.NEXT_PUBLIC_END_POINT}get-categories-slug`,
      { next: { revalidate: SITEMAP_REVALIDATE_SECONDS } } // Revalidate weekly
    );

    if (res.ok) {
      const json = await res.json();
      const categories = json?.data || [];
      categoryEntries = categories.map((category) => {
        const url = `${baseUrl}/ads?category=${category?.slug}`;
        return {
          url: withDefaultLang(url),
          lastModified: new Date(category?.updated_at),
          changeFrequency: "weekly",
          priority: 0.7,
          alternates: buildHreflangLinks(url),
        };
      });
    }
  } catch (error) {
    console.error("Error fetching categories for sitemap:", error);
  }

  let blogEntries = [];
  try {
    const res = await fetch(
      `${apiUrl}${process.env.NEXT_PUBLIC_END_POINT}get-blogs-slug`,
      { next: { revalidate: SITEMAP_REVALIDATE_SECONDS } } // Revalidate weekly
    );

    if (res.ok) {
      const json = await res.json();
      const blogs = json?.data || [];
      blogEntries = blogs.map((blog) => {
        const url = `${baseUrl}/blogs/${blog?.slug}`;
        return {
          url: withDefaultLang(url),
          lastModified: new Date(blog?.updated_at),
          changeFrequency: "weekly",
          priority: 0.7,
          alternates: buildHreflangLinks(url),
        };
      });
    }
  } catch (error) {
    console.error("Error fetching blogs for sitemap:", error);
  }

  let featuredSectionEntries = [];
  try {
    const res = await fetch(
      `${apiUrl}${process.env.NEXT_PUBLIC_END_POINT}get-featured-section-slug`,
      { next: { revalidate: SITEMAP_REVALIDATE_SECONDS } } // Revalidate weekly
    );

    if (res.ok) {
      const json = await res.json();
      const featuredSections = json?.data || [];
      featuredSectionEntries = featuredSections.map((featuredSection) => {
        const url = `${baseUrl}/ads?featured_section=${featuredSection?.slug}`;
        return {
          url: withDefaultLang(url),
          lastModified: new Date(featuredSection?.updated_at),
          changeFrequency: "weekly",
          priority: 0.7,
          alternates: buildHreflangLinks(url),
        };
      });
    }
  } catch (error) {
    console.error("Error fetching featured sections for sitemap:", error);
  }

  let sellerProfileEntries = [];
  try {
    const res = await fetch(
      `${apiUrl}${process.env.NEXT_PUBLIC_END_POINT}get-seller-slug`,
      { next: { revalidate: SITEMAP_REVALIDATE_SECONDS } } // Revalidate weekly
    );

    if (res.ok) {
      const json = await res.json();
      const sellers = json?.data || [];
      sellerProfileEntries = sellers.map((seller) => {
        const url = `${baseUrl}/seller/${seller?.id}`;
        return {
          url: withDefaultLang(url),
          lastModified: new Date(seller?.updated_at),
          changeFrequency: "weekly",
          priority: 0.7,
          alternates: buildHreflangLinks(url),
        };
      });
    }
  } catch (error) {
    console.error("Error fetching featured sections for sitemap:", error);
  }

  return [
    baseEntry,
    ...staticSitemapEntries,
    ...adEntries,
    ...categoryEntries,
    ...blogEntries,
    ...featuredSectionEntries,
    ...sellerProfileEntries,
  ];
}
