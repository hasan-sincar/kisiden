"use client";
import SelectedChatHeader from "./SelectedChatHeader";
import ChatList from "./ChatList";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import NoChatFound from "./NoChatFound";
import ChatMessages from "./ChatMessages";
import { useSelector } from "react-redux";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import { useMediaQuery } from "usehooks-ts";
import { chatListApi } from "@/utils/api";
import { useNavigate } from "@/components/Common/useNavigate";

const Chat = () => {
  const searchParams = useSearchParams();
  const activeTab = searchParams.get("activeTab") || "selling";
  const chatId = Number(searchParams.get("chatid")) || "";
  const [selectedChatDetails, setSelectedChatDetails] = useState();
  const langCode = useSelector(getCurrentLangCode);
  const { navigate } = useNavigate();

  const [IsLoading, setIsLoading] = useState(true);

  const [buyer, setBuyer] = useState({
    BuyerChatList: [],
    CurrentBuyerPage: 1,
    HasMoreBuyer: false,
  });

  const [seller, setSeller] = useState({
    SellerChatList: [],
    CurrentSellerPage: 1,
    HasMoreSeller: false,
  });

  const isLargeScreen = useMediaQuery("(min-width: 1200px)");

  const fetchSellerChatList = async (page = 1) => {
    if (page === 1) {
      setIsLoading(true);
    }
    try {
      const res = await chatListApi.chatList({ type: "seller", page });
      if (res?.data?.error === false) {
        const data = res?.data?.data?.data;
        const currentPage = res?.data?.data?.current_page;
        const lastPage = res?.data?.data?.last_page;

        setSeller((prev) => ({
          ...prev,
          SellerChatList: page === 1 ? data : [...prev.SellerChatList, ...data],
          CurrentSellerPage: currentPage,
          HasMoreSeller: currentPage < lastPage,
        }));
      } else {
        console.error(res?.data?.message);
      }
    } catch (error) {
      console.error("Error fetching seller chat list:", error);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchBuyerChatList = async (page = 1) => {
    if (page === 1) {
      setIsLoading(true);
    }
    try {
      const res = await chatListApi.chatList({ type: "buyer", page });
      if (res?.data?.error === false) {
        const data = res?.data?.data?.data;
        const currentPage = res?.data?.data?.current_page;
        const lastPage = res?.data?.data?.last_page;

        setBuyer((prev) => ({
          ...prev,
          BuyerChatList: page === 1 ? data : [...prev.BuyerChatList, ...data],
          CurrentBuyerPage: currentPage,
          HasMoreBuyer: currentPage < lastPage,
        }));
      } else {
        console.log(res?.data?.message);
      }
    } catch (error) {
      console.log("Error fetching buyer chat list:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    activeTab === "selling" ? fetchSellerChatList() : fetchBuyerChatList();
  }, [activeTab, langCode]);

  useEffect(() => {
    if (chatId && activeTab === "selling" && seller.SellerChatList.length > 0) {
      setSelectedChatDetails(
        seller.SellerChatList.find((chat) => chat.id === chatId)
      );
    } else if (
      chatId &&
      activeTab === "buying" &&
      buyer.BuyerChatList.length > 0
    ) {
      setSelectedChatDetails(
        buyer.BuyerChatList.find((chat) => chat.id === chatId)
      );
    } else if (!chatId) {
      setSelectedChatDetails("");
    }
  }, [chatId, activeTab, seller.SellerChatList, buyer.BuyerChatList, langCode]);

  const handleBack = () => {
    const params = new URLSearchParams(searchParams.toString());
    params.delete("chatid");
    navigate(`?${params.toString()}`, { scroll: false });
  };

  return (
    <div className="grid grid-cols-1 xl:grid-cols-12">
      <div className="col-span-4">
        {(isLargeScreen || !chatId || IsLoading) && (
          <ChatList
            chatId={chatId}
            activeTab={activeTab}
            buyer={buyer}
            setBuyer={setBuyer}
            langCode={langCode}
            isLargeScreen={isLargeScreen}
            seller={seller}
            setSeller={setSeller}
            IsLoading={IsLoading}
            fetchSellerChatList={fetchSellerChatList}
            fetchBuyerChatList={fetchBuyerChatList}
            setSelectedChatDetails={setSelectedChatDetails}
          />
        )}
      </div>
      {(isLargeScreen || chatId) && (
        <div className="col-span-8">
          {selectedChatDetails?.id ? (
            <div className="ltr:xl:border-l rtl:lg:border-r h-[65vh] lg:h-[800px] flex flex-col">
              <SelectedChatHeader
                selectedChat={selectedChatDetails}
                isSelling={activeTab === "selling"}
                setSelectedChat={setSelectedChatDetails}
                handleBack={handleBack}
                isLargeScreen={isLargeScreen}
              />
              <ChatMessages
                selectedChatDetails={selectedChatDetails}
                setSelectedChatDetails={setSelectedChatDetails}
                isSelling={activeTab === "selling"}
                setBuyer={setBuyer}
                chatId={chatId}
              />
            </div>
          ) : (
            <div className="ltr:xl:border-l rtl:xl:border-r h-[60vh] lg:h-[800px] flex items-center justify-center">
              <NoChatFound
                isLargeScreen={isLargeScreen}
                handleBack={handleBack}
              />
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default Chat;
