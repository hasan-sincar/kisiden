import { t } from "@/utils";
import ChatListCard from "./ChatListCard";
import ChatListCardSkeleton from "./ChatListCardSkeleton";
import NoChatListFound from "./NoChatListFound";
import { useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { useInView } from "react-intersection-observer";
import { MdArrowBack } from "react-icons/md";
import { Skeleton } from "@/components/ui/skeleton";
import CustomImage from "@/components/Common/CustomImage";
import { useNavigate } from "@/components/Common/useNavigate";



const ChatList = ({ selectedChatDetails, setSelectedChatDetails, chatListData, setChatListData, fetchChatList, handleChatTabClick }) => {
  const searchParams = useSearchParams();
  const activeTab = searchParams.get("activeTab") || "selling";
  const chatAdId = Number(searchParams.get("chat_ad_id")) || "";
  const chatId = Number(searchParams.get("chatid")) || "";
  const { navigate } = useNavigate();

  const adDetail = chatListData?.list[0]?.item;
  const totalUnreadCount =
    chatListData?.list?.filter((chat) => (Number(chat?.unread_chat_count) || 0) > 0)
      .length || 0;

  const { ref, inView } = useInView();

  useEffect(() => {
    if (inView && chatListData.hasMore && !chatListData.isLoading && !chatListData.isLoadMore) {
      fetchChatList(chatListData.currentPage + 1);
    }
  }, [inView, chatListData.hasMore, chatListData.isLoading, chatListData.isLoadMore]);

  // Update selected chat details when list changes or chat ID changes
  useEffect(() => {
    if (chatId && chatListData.list.length > 0) {
      const selected = chatListData.list.find((chat) => chat.id === chatId);
      if (selected) {
        setSelectedChatDetails(selected);
      }
    }
  }, [chatId, chatListData.list, setSelectedChatDetails]);


  const handleHeaderBack = () => {
    const params = new URLSearchParams(searchParams.toString());
    params.delete("chat_ad_id");
    params.delete("chatid");
    params.delete("lang");
    navigate(`?${params.toString()}`, { scroll: false });
    setSelectedChatDetails({})
  };

  return (
    <div className="h-[60vh] max-h-[800px] flex flex-col lg:h-full">
      <div className="p-4 flex items-center gap-2 border-b">
        {chatListData.isLoading ? (
          <HeaderSkeleton />
        ) : (
          <>
            <button
              onClick={handleHeaderBack}
              className="shrink-0"
              aria-label="Back"
            >
              <MdArrowBack size={24} className="rtl:rotate-180" />
            </button>

            <div className="flex-1 flex items-center gap-2 min-w-0">
              <CustomImage
                src={adDetail?.image}
                alt={adDetail?.name}
                width={44}
                height={44}
                className="object-cover aspect-square rounded-md"
              />
              <div className="flex-1 min-w-0">
                <h4 className="font-medium truncate leading-tight" title={adDetail?.translated_name}>
                  {adDetail?.translated_name}
                </h4>
                <p className="text-xs text-muted-foreground flex flex-wrap items-center gap-1.5 mt-0.5">
                  <span>{chatListData.total} {t("buyer")}</span>
                  <span className="size-1 rounded-full bg-muted-foreground/30" />
                  <span>{totalUnreadCount} {t("unread")}</span>
                </p>
              </div>
            </div>

            <div className="text-primary font-bold whitespace-nowrap">
              {adDetail?.formatted_price || adDetail?.price}
            </div>
          </>
        )}
      </div>

      <div className="flex-1 overflow-y-auto" id="chatList">
        {chatListData.isLoading ? (
          Array.from({ length: 8 }, (_, index) => (
            <ChatListCardSkeleton key={index} />
          ))
        ) : chatListData.list.length > 0 ? (
          <>
            {chatListData.list.map((chat, index) => (
              <ChatListCard
                key={chat.id || index}
                chat={chat}
                chatAdId={chatAdId}
                isActive={chat?.id === chatId}
                isSelling={activeTab === "selling"}
                handleChatTabClick={handleChatTabClick}
                setSelectedChat={setSelectedChatDetails}
                totalChats={chatListData.total} // Pass the count
                setChatListData={setChatListData}
              />
            ))}
            {chatListData.hasMore && (
              <div ref={ref} className="py-2">
                {Array.from({ length: 3 }, (_, index) => (
                  <ChatListCardSkeleton key={index} />
                ))}
              </div>
            )}
          </>
        ) : (
          <div className="h-full flex items-center justify-center p-4">
            <NoChatListFound />
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatList;


const HeaderSkeleton = () => (
  <div className="flex items-center gap-3 w-full">
    <Skeleton className="size-8 rounded-full" />
    <div className="flex-1 flex items-center gap-2">
      <Skeleton className="size-10 rounded-lg" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-4 w-3/4" />
        <Skeleton className="h-3 w-1/2" />
      </div>
    </div>
    <Skeleton className="h-6 w-16" />
  </div>
);