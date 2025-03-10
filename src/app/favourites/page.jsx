import Layout from "@/components/Layout/Layout"
import Favourites from "@/components/PagesComponent/Favourites/Favourites"

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

const FavouritesPage = () => {
    return (
        <Layout>
            <Favourites />
        </Layout>

    )
}

export default FavouritesPage