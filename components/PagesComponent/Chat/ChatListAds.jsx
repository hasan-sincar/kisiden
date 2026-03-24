import { useMediaQuery } from "usehooks-ts";
import BlockedUsersMenu from "./BlockedUsersMenu";
import { formatTime, t } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import { useSearchParams } from "next/navigation";
import { cn } from "@/lib/utils";
import CustomImage from "@/components/Common/CustomImage";
import { useEffect, useState } from "react";
import { useInView } from "react-intersection-observer";
import { getChatAdListApi } from "@/utils/api";
import { toast } from "sonner";
import { Skeleton } from "@/components/ui/skeleton";
import { formatPriceAbbreviated } from "@/utils";
import EmptyMessage from "@/components/EmptyStates/EmptyMessage";
import ChatListCardSkeleton from "./ChatListCardSkeleton";
import ChatListCard from "./ChatListCard";


const ChatListAds = ({ buyingListData, fetchBuyingList, setBuyingListData, setSelectedChatDetails, selectedChat, handleChatTabClick }) => {
    const searchParams = useSearchParams();
    const activeTab = searchParams.get("activeTab") || "selling";
    const langCode = searchParams.get("lang")
    const chatId = Number(searchParams.get("chatid")) || "";

    const [chatAdList, setChatAdList] = useState({
        isLoading: false,
        isLoadMore: false,
        data: [],
        currentPage: 1,
        hasMore: true
    })

    const isLargeScreen = useMediaQuery("(min-width: 1200px)");
    const { ref, inView } = useInView();

    // Infinite scroll trigger
    useEffect(() => {
        if (activeTab === "selling" && inView && chatAdList.hasMore && !chatAdList.isLoading && !chatAdList.isLoadMore) {
            getChatAdList(chatAdList.currentPage + 1)
        }
    }, [inView, chatAdList.hasMore, chatAdList.isLoading, chatAdList.isLoadMore])

    // Infinite scroll trigger
    useEffect(() => {
        if (activeTab === "buying" && inView && buyingListData.hasMore && !buyingListData.isLoading) {
            fetchBuyingList(buyingListData.currentPage + 1);
        }
    }, [inView, activeTab, buyingListData.hasMore, buyingListData.isLoading]);


    // auto select selected chat from url chatId
    useEffect(() => {
        if (activeTab === "buying" && chatId && buyingListData?.list?.length > 0) {
            const selected = buyingListData.list.find((chat) => chat.id === chatId);
            if (selected) {
                setSelectedChatDetails(selected);
            }
        }
    }, [chatId, buyingListData?.list, activeTab, setSelectedChatDetails]);


    useEffect(() => {
        if (activeTab === "selling") {
            getChatAdList(1)
        }
    }, [activeTab, langCode])


    const getChatAdList = async (page = 1) => {
        try {
            if (page === 1) {
                setChatAdList((prev) => ({ ...prev, isLoading: true }))
            } else {
                setChatAdList((prev) => ({ ...prev, isLoadMore: true }))
            }
            const res = await getChatAdListApi.getChatAdList({
                type: activeTab === 'selling' ? 'seller' : 'buyer',
                page
            })
            if (res?.data?.error === false) {
                const data = res?.data?.data?.data;
                const currentPage = res?.data?.data?.current_page;
                const lastPage = res?.data?.data?.last_page;
                setChatAdList((prev) => ({
                    ...prev,
                    data: page === 1 ? (data || []) : [...prev.data, ...(data || [])],
                    currentPage: currentPage,
                    hasMore: currentPage < lastPage,
                }));
            } else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.log(error)
        } finally {
            setChatAdList((prev) => ({
                ...prev,
                isLoading: false,
                isLoadMore: false,
            }))
        }
    }

    return (
        <div className="h-[60vh] max-h-[800px] lg:h-full flex flex-col">
            {isLargeScreen && (
                <div className="p-4 flex items-center gap-1 justify-between border-b">
                    <h4 className="font-medium text-xl">{t("chat")}</h4>
                    {/* Blocked Users Menu Component */}
                    <BlockedUsersMenu
                        setSelectedChatDetails={setSelectedChatDetails}
                        setChatListData={setBuyingListData}
                    />
                </div>
            )}
            <div className="flex items-center">
                <CustomLink
                    href="/chat?activeTab=selling"
                    className={cn("py-4 flex-1 text-center border-b", activeTab === "selling" && "border-primary text-primary")}
                    scroll={false}
                >
                    {t("selling")}
                </CustomLink>
                <CustomLink
                    href="/chat?activeTab=buying"
                    className={cn("py-4 flex-1 text-center border-b", activeTab === "buying" && "border-primary text-primary")}
                    scroll={false}
                >
                    {t("buying")}
                </CustomLink>
            </div>

            <div className={cn("flex-1 overflow-y-auto flex flex-col",
                activeTab === "selling" && 'p-2 sm:p-4 gap-4'
            )}>
                {activeTab === "selling" ? (
                    /* --- SELLING TAB --- */
                    (chatAdList.isLoading && chatAdList.currentPage === 1) ? (
                        <ChatListAdsSkeleton />
                    ) : chatAdList.data.length > 0 ? (
                        <>
                            {chatAdList.data.map((chat) => (
                                <ChatAdCard key={chat.id} chat={chat} activeTab={activeTab} />
                            ))}
                            {chatAdList.hasMore && (
                                <div ref={ref} className="py-2">
                                    <ChatListAdsSkeleton count={1} />
                                </div>
                            )}
                        </>
                    ) : (
                        <EmptyMessage message={t("noChatFound")} />
                    )
                ) : (
                    /* --- BUYING TAB --- */
                    buyingListData.isLoading ? (
                        Array.from({ length: 8 }, (_, index) => (
                            <ChatListCardSkeleton key={index} />
                        ))
                    ) : buyingListData.list.length > 0 ? (
                        <>
                            {buyingListData.list.map((chat) => (
                                <ChatListCard
                                    key={chat.id}
                                    chat={chat}
                                    isSelling={false}
                                    isActive={chat?.id === chatId}
                                    chatAdId={chat?.item?.id}
                                    setChatListData={setBuyingListData}
                                    setSelectedChat={setSelectedChatDetails}
                                    totalChats={buyingListData.total}
                                    handleChatTabClick={handleChatTabClick}
                                />
                            ))}
                            {buyingListData.hasMore && (
                                <div ref={ref} className="py-2">
                                    <ChatListCardSkeleton />
                                </div>
                            )}
                        </>
                    ) : (
                        <EmptyMessage message={t("noChatFound")} />
                    )
                )}
            </div>
        </div>
    );
};

export default ChatListAds;


const ChatAdCard = ({ chat, activeTab }) => {
    const unreadCount = chat.unread_chat_count;
    const time = formatTime(chat.last_offer_updated);
    const users = chat.other_users || [];
    const displayUsers = users.slice(0, 3);
    const extraUsers = Math.max(0, users.length - 3);

    const getHref = () => {
        let url = `/chat?activeTab=${activeTab}&chat_ad_id=${chat.id}`;
        if (activeTab === "buying" && users.length > 0 && users[0].offer_id) {
            url += `&chatid=${users[0].offer_id}`;
        }
        return url;
    };

    return (
        <CustomLink
            href={getHref()}
            scroll={false}
            className="p-2 sm:p-4 border rounded-xl flex items-center gap-4"
        >
            <CustomImage
                src={chat.image}
                alt={chat.name}
                width={44}
                height={44}
                className="object-cover aspect-square rounded-full"
            />
            {/* Content */}
            <div className="flex-1 min-w-0 ltr:text-left rtl:text-right">
                <h5 className="font-medium line-clamp-2 mb-1 text-gray-900">
                    {chat.name}
                </h5>
                <div className={cn("flex items-center flex-wrap  gap-y-1", chat.price && "gap-x-2")}>
                    <span className="font-bold whitespace-nowrap text-gray-900">
                        {formatPriceAbbreviated(chat.price)}
                    </span>

                    {displayUsers.length > 0 &&
                        <>
                            {chat.price && <span className="w-1 h-1 bg-muted-foreground rounded-full hidden sm:block" />}
                            {/* User Avatars Stack & Extra Count */}
                            <div className="flex items-center gap-1.5 min-w-0">
                                <div className="flex -space-x-2 overflow-hidden py-0.5 shrink-0">
                                    {displayUsers.map((user, idx) => (
                                        <div key={idx} className="relative size-5 rounded-full overflow-hidden border border-white shadow-sm shrink-0">
                                            <CustomImage
                                                src={user.profile || ""}
                                                alt={user.name || "Chat Ad"}
                                                fill
                                                className="object-cover"
                                            />
                                        </div>
                                    ))}
                                </div>
                                {extraUsers > 0 && (
                                    <span className="text-xs text-muted-foreground whitespace-nowrap">
                                        +{extraUsers}
                                    </span>
                                )}
                            </div>
                        </>
                    }
                </div>
            </div>

            {/* Status */}
            <div className="flex flex-col items-end justify-between h-full py-0.5 shrink-0">
                <span className={cn("text-xs mb-2", unreadCount > 0 ? "font-bold" : "font-medium text-muted-foreground")}>
                    {time}
                </span>
                {unreadCount > 0 ? (
                    <div className="flex items-center justify-center min-w-[20px] h-[20px] bg-primary text-white text-xs font-bold rounded-full px-1.5 shadow-sm">
                        {unreadCount}
                    </div>
                ) : (
                    <div className="h-[20px]" />
                )}
            </div>
        </CustomLink>
    );
};


const ChatListAdsSkeleton = ({ count = 6 }) => {
    return (
        <>
            {Array.from({ length: count }).map((_, item) => (
                <div key={item} className="p-2 sm:p-4 border rounded-xl flex items-center gap-4">
                    {/* Image Skeleton */}
                    <Skeleton className="w-11 h-11 rounded-full shrink-0" />

                    {/* Content Skeleton */}
                    <div className="flex-1 min-w-0">
                        <Skeleton className="h-4 w-3/4 mb-2" />
                        <div className="flex items-center gap-2">
                            <Skeleton className="h-4 w-16" />
                            <Skeleton className="h-1 w-1 rounded-full hidden sm:block" />
                            <div className="flex -space-x-2">
                                <Skeleton className="w-5 h-5 rounded-full border-2 border-white" />
                                <Skeleton className="w-5 h-5 rounded-full border-2 border-white" />
                            </div>
                            <Skeleton className="h-3 w-8" />
                        </div>
                    </div>

                    {/* Status Skeleton */}
                    <div className="flex flex-col items-end justify-between h-full py-0.5 shrink-0 min-h-[44px]">
                        <Skeleton className="h-3 w-12" />
                        <Skeleton className="h-5 w-5 rounded-full" />
                    </div>
                </div>
            ))}
        </>
    );
};