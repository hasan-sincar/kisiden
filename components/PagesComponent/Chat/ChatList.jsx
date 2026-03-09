import { t } from "@/utils";
import ChatListCard from "./ChatListCard";
import ChatListCardSkeleton from "./ChatListCardSkeleton";
import BlockedUsersMenu from "./BlockedUsersMenu";
import NoChatListFound from "./NoChatListFound";
import InfiniteScroll from "react-infinite-scroll-component";
import CustomLink from "@/components/Common/CustomLink";

const ChatList = ({
  chatId,
  activeTab,
  buyer,
  setBuyer,
  isLargeScreen,
  seller,
  setSeller,
  IsLoading,
  fetchSellerChatList,
  fetchBuyerChatList,
  setSelectedChatDetails
}) => {
  const handleChatTabClick = (chat, isSelling) => {
    if (isSelling) {
      setSeller((prev) => ({
        ...prev,
        SellerChatList: prev.SellerChatList.map((item) =>
          item.id === chat.id ? { ...item, unread_chat_count: 0 } : item
        ),
      }));
    } else {
      setBuyer((prev) => ({
        ...prev,
        BuyerChatList: prev.BuyerChatList.map((item) =>
          item.id === chat.id ? { ...item, unread_chat_count: 0 } : item
        ),
      }));
    }
  };

  return (
    <div className="h-[60vh] max-h-[800px] flex flex-col lg:h-full">
      {isLargeScreen && (
        <div className="p-4 flex items-center gap-1 justify-between border-b">
          <h4 className="font-medium text-xl">{t("chat")}</h4>
          {/* Blocked Users Menu Component */}
          <BlockedUsersMenu setSelectedChatDetails={setSelectedChatDetails} />
        </div>
      )}

      <div className="flex items-center">
        <CustomLink
          href={`/chat?activeTab=selling`}
          className={`py-4 flex-1 text-center border-b ${activeTab === "selling" ? "border-primary" : ""
            }`}
          scroll={false}
        >
          {t("selling")}
        </CustomLink>
        <CustomLink
          href={`/chat?activeTab=buying`}
          className={`py-4 flex-1 text-center border-b ${activeTab === "buying" ? "border-primary" : ""
            }`}
          scroll={false}
        >
          {t("buying")}
        </CustomLink>
      </div>
      <div className="flex-1 overflow-y-auto" id="chatList">
        <InfiniteScroll
          dataLength={
            activeTab === "buying"
              ? buyer.BuyerChatList?.length
              : seller.SellerChatList?.length
          }
          next={() => {
            activeTab === "buying"
              ? fetchBuyerChatList(buyer.CurrentBuyerPage + 1)
              : fetchSellerChatList(seller.CurrentSellerPage + 1);
          }}
          hasMore={
            activeTab === "buying" ? buyer.HasMoreBuyer : seller.HasMoreSeller
          }
          loader={Array.from({ length: 3 }, (_, index) => (
            <ChatListCardSkeleton key={index} />
          ))}
          scrollableTarget="chatList"
        >
          {IsLoading
            ? Array.from({ length: 8 }, (_, index) => (
              <ChatListCardSkeleton key={index} />
            ))
            : (() => {
              const chatList =
                activeTab === "selling"
                  ? seller.SellerChatList
                  : buyer.BuyerChatList;
              return chatList.length > 0 ? (
                chatList.map((chat, index) => (
                  <ChatListCard
                    key={Number(chat.id) || index}
                    chat={chat}
                    isActive={chat?.id === chatId}
                    isSelling={activeTab === "selling"}
                    handleChatTabClick={handleChatTabClick}
                  />
                ))
              ) : (
                <div className="h-full flex items-center justify-center p-4">
                  <NoChatListFound />
                </div>
              );
            })()}
        </InfiniteScroll>
      </div>
    </div>
  );
};

export default ChatList;
