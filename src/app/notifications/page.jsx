import Layout from '@/components/Layout/Layout'
import Notifications from '@/components/PagesComponent/Notifications/Notifications'

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
const NotificationsPage = () => {
    return (
        <Layout>
            <Notifications />
        </Layout>

    )
}

export default NotificationsPage