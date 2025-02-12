import Layout from "@/components/Layout/Layout"
import ProfileSubscription from "@/components/PagesComponent/Subscription/ProfileSubscription"

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
const SubscriptionPage = () => {
    return (
        <Layout>
              <ProfileSubscription />
        </Layout>
    )
}

export default SubscriptionPage