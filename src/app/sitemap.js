export default async function sitemap() {
    const baseUrl = process.env.NEXT_PUBLIC_WEB_URL;

    const staticRoutes = [
        'about-us', 'ad-listing', 'ads', 'blogs', 'chat', 'contact-us', 'faqs',
        'favourites', 'home', 'notifications', 'privacy-policy', 'products',
        'profile/edit-profile', 'reviews', 'subscription', 'terms-and-condition',
        'transactions', 'user-subscription', 'user-verification'
    ];

    const staticSitemapEntries = staticRoutes.map(route => ({
        url: `${baseUrl}/${route}`,
        lastModified: new Date(),
        changeFrequency: 'monthly',
        priority: 1,
    }));

    // Add the base URL entry
    const baseEntry = {
        url: `${baseUrl}`,
        lastModified: new Date(),
        changeFrequency: 'monthly',
        priority: 1,
    };

    return [baseEntry, ...staticSitemapEntries];
}