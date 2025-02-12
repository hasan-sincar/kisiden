import LandingPage from "@/components/LandingPage"
import Layout from "@/components/Layout/Layout"

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
const HomePage = () => {
    return (
        <Layout>
            <LandingPage />
        </Layout>
    )
}

export default HomePage