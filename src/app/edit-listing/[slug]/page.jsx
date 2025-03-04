import Layout from "@/components/Layout/Layout";
import EditListing from "@/components/PagesComponent/EditListing/EditListing";
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
const EditListingPage = ({ params }) => {
    return (
        <Layout>
            <EditListing id={params.slug} />
        </Layout>
    )
}

export default EditListingPage;