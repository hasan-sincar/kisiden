import Layout from "@/components/Layout/Layout"
import Messages from "@/components/PagesComponent/Chat/Messages"


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
const ChatPage = () => {
    return (
        <Layout>
            <Messages />
        </Layout>
    )
}

export default ChatPage