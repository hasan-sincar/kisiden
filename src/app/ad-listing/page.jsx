import Layout from '@/components/Layout/Layout';
import AdListing from '@/components/PagesComponent/AdListing/AdListing';




export const metadata = {
    title: process.env.NEXT_PUBLIC_META_TITLE,
    description: process.env.NEXT_PUBLIC_META_DESCRIPTION,
    keywords: process.env.NEXT_PUBLIC_META_kEYWORDS,
    openGraph: {
        title: process.env.NEXT_PUBLIC_META_TITLE,
        description: process.env.NEXT_PUBLIC_META_DESCRIPTION,
        keywords: process.env.NEXT_PUBLIC_META_kEYWORDS,
    },
}


const AdListingPage = async () => {


    return (
        <>
            <Layout>
                <AdListing />
            </Layout>
        </>
    )
}

export default AdListingPage