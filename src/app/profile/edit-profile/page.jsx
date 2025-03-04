import Layout from '@/components/Layout/Layout'
import EditProfile from '@/components/PagesComponent/EditProfile/EditProfile'



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
const EditProfilePage = () => {
    return (
        <Layout>
            <EditProfile />
        </Layout>
    )
}

export default EditProfilePage