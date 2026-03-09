import { userSignUpData } from "@/redux/reducer/authSlice";
import {
  formatChatMessageTime,
  formatMessageDate,
  formatPriceAbbreviated,
  t,
} from "@/utils";
import { getMessagesApi } from "@/utils/api";
import { Fragment, useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";
import { Skeleton } from "@/components/ui/skeleton";
import { Loader2, ChevronUp } from "lucide-react";
import dynamic from "next/dynamic";
const SendMessage = dynamic(() => import("./SendMessage"), { ssr: false });
import GiveReview from "./GiveReview";
import { getNotification } from "@/redux/reducer/globalStateSlice";
import CustomImage from "@/components/Common/CustomImage";
import { cn } from "@/lib/utils";

// Skeleton component for chat messages
const ChatMessagesSkeleton = () => {
  return (
    <div className="flex flex-col gap-4 w-full">
      {/* Skeleton for date separator */}

      {/* Received message skeletons */}
      <div className="flex flex-col gap-1 w-[65%] max-w-[80%]">
        <Skeleton className="h-16 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] rounded-md" />
      </div>

      {/* Sent message skeletons */}
      <div className="flex flex-col gap-1 w-[70%] max-w-[80%] self-end">
        <Skeleton className="h-10 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] self-end rounded-md" />
      </div>

      {/* Image message skeleton */}
      <div className="flex flex-col gap-1 w-[50%] max-w-[80%]">
        <Skeleton className="h-32 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] rounded-md" />
      </div>

      {/* Audio message skeleton */}
      <div className="flex flex-col gap-1 w-[60%] max-w-[80%] self-end">
        <Skeleton className="h-12 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] self-end rounded-md" />
      </div>

      {/* Another message skeleton */}
      <div className="flex flex-col gap-1 w-[45%] max-w-[80%]">
        <Skeleton className="h-14 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] rounded-md" />
      </div>
      <div className="flex flex-col gap-1 w-[60%] max-w-[80%] self-end">
        <Skeleton className="h-12 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] self-end rounded-md" />
      </div>

      {/* Another message skeleton */}
      <div className="flex flex-col gap-1 w-[45%] max-w-[80%]">
        <Skeleton className="h-14 w-full rounded-md" />
        <Skeleton className="h-3 w-[30%] rounded-md" />
      </div>
    </div>
  );
};

const renderMessageContent = (message, isCurrentUser) => {
  const baseTextClass = isCurrentUser
    ? "text-white bg-primary p-2 rounded-md w-fit"
    : "text-black bg-border p-2 rounded-md w-fit";

  const audioStyles = isCurrentUser ? "border-primary" : "border-border";

  switch (message.message_type) {
    case "audio":
      return (
        <audio
          src={message.audio}
          controls
          className={`w-full sm:w-[70%] ${
            isCurrentUser ? "self-end" : "self-start"
          } rounded-md border-2 ${audioStyles}`}
          controlsList="nodownload"
          type="audio/mpeg"
          preload="metadata"
        />
      );

    case "file":
      return (
        <div className={`${baseTextClass}`}>
          <CustomImage
            src={message.file}
            alt="Chat Image"
            className="rounded-md w-auto h-auto max-h-[250px] max-w-[250px] object-contain"
            width={200}
            height={200}
          />
        </div>
      );

    case "file_and_text":
      return (
        <div className={`${baseTextClass} flex flex-col gap-2`}>
          <CustomImage
            src={message.file}
            alt="Chat Image"
            className="rounded-md w-auto h-auto max-h-[250px] max-w-[250px] object-contain"
            width={200}
            height={200}
          />
          <div className="border-white/20">{message.message}</div>
        </div>
      );

    default:
      return (
        <p
          className={`${baseTextClass} whitespace-pre-wrap ${
            isCurrentUser ? "self-end" : "self-start"
          }`}
        >
          {message?.message}
        </p>
      );
  }
};

const ChatMessages = ({
  selectedChatDetails,
  isSelling,
  setSelectedChatDetails,
  setBuyer,
  chatId,
}) => {
  const notification = useSelector(getNotification);
  const [chatMessages, setChatMessages] = useState([]);
  const [currentMessagesPage, setCurrentMessagesPage] = useState(1);
  const [hasMoreChatMessages, setHasMoreChatMessages] = useState(false);
  const [isLoadPrevMesg, setIsLoadPrevMesg] = useState(false);
  const [IsLoading, setIsLoading] = useState(false);
  const [showReviewDialog, setShowReviewDialog] = useState(false);
  const lastMessageDate = useRef(null);
  const isAskForReview =
    !isSelling &&
    selectedChatDetails?.item?.status === "sold out" &&
    !selectedChatDetails?.item?.review &&
    Number(selectedChatDetails?.item?.sold_to) ===
      Number(selectedChatDetails?.buyer_id);

  const user = useSelector(userSignUpData);
  const userId = user?.id;

  useEffect(() => {
    if (selectedChatDetails?.id) {
      fetchChatMessgaes(1);
    }
  }, [selectedChatDetails?.id]);

  useEffect(() => {
    if (
      notification?.type === "chat" &&
      Number(notification?.item_offer_id) === Number(chatId) &&
      (notification?.user_type === "Seller" ? !isSelling : isSelling)
    ) {
      const newMessage = {
        message_type: notification?.message_type_temp,
        message: notification?.message,
        sender_id: Number(notification?.sender_id),
        created_at: notification?.created_at,
        audio: notification?.audio,
        file: notification?.file,
        id: Number(notification?.id),
        item_offer_id: Number(notification?.item_offer_id),
        updated_at: notification?.updated_at,
      };

      setChatMessages((prev) => [...prev, newMessage]);
    }
  }, [notification]);

  const fetchChatMessgaes = async (page) => {
    try {
      page > 1 ? setIsLoadPrevMesg(true) : setIsLoading(true);
      const response = await getMessagesApi.chatMessages({
        item_offer_id: selectedChatDetails?.id,
        page,
      });
      if (response?.data?.error === false) {
        const currentPage = Number(response?.data?.data?.current_page);
        const lastPage = Number(response?.data?.data?.last_page);
        const hasMoreChatMessages = currentPage < lastPage;
        const chatMessages = (response?.data?.data?.data).reverse();
        setCurrentMessagesPage(currentPage);
        setHasMoreChatMessages(hasMoreChatMessages);
        page > 1
          ? setChatMessages((prev) => [...chatMessages, ...prev])
          : setChatMessages(chatMessages);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoadPrevMesg(false);
      setIsLoading(false);
    }
  };

  return (
    <>
      <div className="flex-1 overflow-y-auto bg-muted p-4 flex flex-col gap-2.5 relative">
        {IsLoading ? (
          <ChatMessagesSkeleton />
        ) : (
          <>
            {/* Show review dialog if open */}
            {showReviewDialog && (
              <div className="absolute inset-0 z-20 flex items-center justify-center bg-black/20 p-4">
                <div className="w-full max-w-md">
                  <GiveReview
                    itemId={selectedChatDetails?.item_id}
                    sellerId={selectedChatDetails?.seller_id}
                    onClose={() => setShowReviewDialog(false)}
                    onSuccess={handleReviewSuccess}
                  />
                </div>
              </div>
            )}

            {/* button to load previous messages */}
            {hasMoreChatMessages && !IsLoading && (
              <div className="absolute top-3 left-0 right-0 z-10 flex justify-center pb-2">
                <button
                  onClick={() => fetchChatMessgaes(currentMessagesPage + 1)}
                  disabled={isLoadPrevMesg}
                  className="text-primary text-sm font-medium px-3 py-1.5 bg-white/90 rounded-full shadow-md hover:bg-white flex items-center gap-1.5"
                >
                  {isLoadPrevMesg ? (
                    <>
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      {t("loading")}
                    </>
                  ) : (
                    <>
                      <ChevronUp className="w-4 h-4" />
                      {t("loadPreviousMessages")}
                    </>
                  )}
                </button>
              </div>
            )}

            {/* offer price */}
            {!hasMoreChatMessages &&
              selectedChatDetails?.amount > 0 &&
              (() => {
                const isSeller = isSelling;
                const containerClasses = `flex flex-col gap-1 rounded-md p-2 w-fit ${
                  isSeller ? "bg-border" : "bg-primary text-white self-end"
                }`;
                const label = isSeller ? t("offer") : t("yourOffer");

                return (
                  <div className={containerClasses}>
                    <p className="text-sm">{label}</p>
                    <span className="text-xl font-medium">
                      {selectedChatDetails.formatted_amount}
                    </span>
                  </div>
                );
              })()}

            {/* chat messages */}
            {chatMessages &&
              chatMessages.length > 0 &&
              chatMessages.map((message) => {
                const messageDate = formatMessageDate(message.created_at);
                const showDateSeparator =
                  messageDate !== lastMessageDate.current;
                if (showDateSeparator) {
                  lastMessageDate.current = messageDate;
                }

                return (
                  <Fragment key={message?.id}>
                    {showDateSeparator && (
                      <p className="text-xs bg-[#f1f1f1] py-1 px-2 rounded-lg text-muted-foreground my-5 mx-auto">
                        {messageDate}
                      </p>
                    )}

                    {message.sender_id === userId ? (
                      <div
                        className={cn(
                          "flex flex-col gap-1 max-w-[80%] self-end",
                          message.message_type === "audio" && "w-full"
                        )}
                        key={message?.id}
                      >
                        {renderMessageContent(message, true)}
                        <p className="text-xs text-muted-foreground ltr:text-right rtl:text-left">
                          {formatChatMessageTime(message?.created_at)}
                        </p>
                      </div>
                    ) : (
                      <div
                        className={cn(
                          "flex flex-col gap-1 max-w-[80%]",
                          message.message_type === "audio" && "w-full"
                        )}
                        key={message?.id}
                      >
                        {renderMessageContent(message, false)}
                        <p className="text-xs text-muted-foreground ltr:text-left rtl:text-right">
                          {formatChatMessageTime(message?.created_at)}
                        </p>
                      </div>
                    )}
                  </Fragment>
                );
              })}
          </>
        )}
      </div>
      {isAskForReview && (
        <GiveReview
          key={`review-${selectedChatDetails?.id}`}
          itemId={selectedChatDetails?.item_id}
          setSelectedChatDetails={setSelectedChatDetails}
          setBuyer={setBuyer}
        />
      )}
      <SendMessage
        key={`send-${selectedChatDetails?.id}`}
        selectedChatDetails={selectedChatDetails}
        setChatMessages={setChatMessages}
      />
    </>
  );
};

export default ChatMessages;
