"use client";
import SelectedChatHeader from "./SelectedChatHeader";
import ChatList from "./ChatList";
import { useSearchParams } from "next/navigation";
import { useState, useEffect } from "react";
import NoChatFound from "./NoChatFound";
import ChatMessages from "./ChatMessages";
import { useNavigate } from "@/components/Common/useNavigate";
import ChatListAds from "./ChatListAds";
import { cn } from "@/lib/utils";
import { chatListApi } from "@/utils/api";

const Chat = () => {
  const searchParams = useSearchParams();
  const activeTab = searchParams.get("activeTab") || "selling";
  const chatAdId = Number(searchParams.get("chat_ad_id")) || "";
  const chatId = Number(searchParams.get("chatid")) || "";
  const [selectedChatDetails, setSelectedChatDetails] = useState();
  const [selectMode, setSelectMode] = useState(false);
  const [selectedMessages, setSelectedMessages] = useState([]);
  const { navigate } = useNavigate();
  const [chatMessages, setChatMessages] = useState([]);

  const [chatListData, setChatListData] = useState({
    list: [],
    currentPage: 1,
    hasMore: false,
    isLoading: true,
    isLoadMore: false,
    total: 0,
  });


  const fetchChatList = async (page = 1) => {
    try {
      if (page === 1) setChatListData((prev) => ({ ...prev, isLoading: true }));
      else setChatListData((prev) => ({ ...prev, isLoadMore: true }));
      const res = await chatListApi.chatList({
        type: activeTab === "selling" ? "seller" : "buyer",
        ...(chatAdId && activeTab === "selling" && { item_id: chatAdId }),
        page,
      });
      if (res?.data?.error === false) {
        const newList = res?.data?.data?.data || [];
        const currentPage = res?.data?.data?.current_page;
        const lastPage = res?.data?.data?.last_page;
        const total = res?.data?.data?.total || 0;
        setChatListData((prev) => ({
          ...prev,
          list: page === 1 ? newList : [...prev.list, ...newList],
          currentPage: currentPage,
          hasMore: currentPage < lastPage,
          total: total,
        }));
      }
    } catch (error) {
      console.error(error);
    } finally {
      setChatListData((prev) => ({ ...prev, isLoading: false, isLoadMore: false }));
    }
  };

  // Listener 1: ONLY runs when you switch tabs
  useEffect(() => {
    if (activeTab === 'buying') {
      fetchChatList(1);
    }
  }, [activeTab]);


  // Listener 2: ONLY runs in Selling mode when picking a Chat Ad
  useEffect(() => {
    if (activeTab === 'selling' && chatAdId) {
      fetchChatList(1);
    }
  }, [activeTab, chatAdId]);

  const handleBack = () => {
    const params = new URLSearchParams(searchParams.toString());
    if (activeTab === "buying") {
      params.delete("chat_ad_id");
      params.delete("chatid");
    } else {
      params.delete("chatid");
    }
    navigate(`?${params.toString()}`, { scroll: false });
  };
  const handleChatTabClick = (chat) => {
    setChatListData((prev) => ({
      ...prev,
      list: prev.list.map((item) =>
        item.id === chat.id ? { ...item, unread_chat_count: 0 } : item
      ),
    }));
  };

  // Determine if we need to show the full 2-column interface (or any sidebar sub-interface)
  // We show it if an Ad is selected (Selling) OR if a specific Chat is selected (Buying)
  // Otherwise, we just show the un-split generic ChatListAds menu
  const isSellingAdSelected = activeTab === "selling" && chatAdId;
  const isBuyingChatSelected = activeTab === "buying" && chatId;
  const showChatInterface = isSellingAdSelected || isBuyingChatSelected;

  if (!showChatInterface) {
    // This happens when NO specific chat or ad is clicked yet, regardless of tab
    return (
      <ChatListAds
        buyingListData={chatListData}     // User-wise list (Buying)
        fetchBuyingList={fetchChatList}   // User-wise fetcher
        setBuyingListData={setChatListData}
        setSelectedChatDetails={setSelectedChatDetails}
        selectedChat={selectedChatDetails}
        handleChatTabClick={handleChatTabClick}
      />
    );
  }

  return (
    <div className="grid grid-cols-1 xl:grid-cols-12">
      {/* LEFT SIDEBAR (Shows ChatList for Selling, ChatListAds for Buying) */}
      <div
        className={cn(
          "col-span-5 ltr:lg:border-r rtl:lg:border-l",
          chatId ? "hidden xl:block" : "block" // Hide on mobile IF chatId exists, show on xl always
        )}
      >
        {activeTab === 'buying' ? (
          <ChatListAds
            buyingListData={chatListData}     // User-wise list (Buying)
            fetchBuyingList={fetchChatList}   // User-wise fetcher
            setBuyingListData={setChatListData}
            setSelectedChatDetails={setSelectedChatDetails}
            selectedChat={selectedChatDetails}
            handleChatTabClick={handleChatTabClick}
          />
        ) : (
          <ChatList
            setSelectedChatDetails={setSelectedChatDetails}
            selectedChatDetails={selectedChatDetails}
            chatListData={chatListData} // Pass this
            setChatListData={setChatListData} // Pass this for unread count updates
            fetchChatList={fetchChatList}
            handleChatTabClick={handleChatTabClick}
          />
        )}
      </div>

      {/* RIGHT CHAT MESSAGES PANEL */}
      <div
        className={cn(
          "col-span-12 xl:col-span-7",
          chatId ? "block shadow-none" : "hidden xl:block"
        )}
      >
        {chatId ? (
          <div className="h-[65vh] lg:h-[800px] flex flex-col">
            <SelectedChatHeader
              selectedChat={selectedChatDetails}
              isSelling={activeTab === "selling"}
              setSelectedChat={setSelectedChatDetails}
              handleBack={handleBack}
              chatAdId={chatAdId}
              selectMode={selectMode}
              setSelectMode={setSelectMode}
              selectedMessages={selectedMessages}
              setSelectedMessages={setSelectedMessages}
              chatId={chatId}
              totalChats={chatListData.total} // Pass this
              setChatListData={setChatListData}
              setChatMessages={setChatMessages}
            />
            <ChatMessages
              selectedChatDetails={selectedChatDetails}
              setSelectedChatDetails={setSelectedChatDetails}
              isSelling={activeTab === "selling"}
              chatId={chatId}
              selectMode={selectMode}
              setSelectMode={setSelectMode}
              selectedMessages={selectedMessages}
              setSelectedMessages={setSelectedMessages}
              chatMessages={chatMessages}       // 4. Pass state to messages list
              setChatMessages={setChatMessages}
              setChatListData={setChatListData}
            />
          </div>
        ) : (
          <div className="h-[60vh] lg:h-[800px] flex items-center justify-center">
            <NoChatFound handleBack={handleBack} />
          </div>
        )}
      </div>
    </div>
  );
};

export default Chat;
