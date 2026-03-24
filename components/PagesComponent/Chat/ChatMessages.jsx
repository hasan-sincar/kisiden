import { userSignUpData } from "@/redux/reducer/authSlice";
import {
  formatChatMessageTime,
  formatMessageDate,
  t,
} from "@/utils";
import { getMessagesApi, deleteChatMessagesApi } from "@/utils/api";
import { toast } from "sonner";
import { Fragment, useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";
import { Skeleton } from "@/components/ui/skeleton";
import { Loader2, ChevronUp, MoreVertical } from "lucide-react";
import dynamic from "next/dynamic";
const SendMessage = dynamic(() => import("./SendMessage"), { ssr: false });
import GiveReview from "./GiveReview";
import { getNotification } from "@/redux/reducer/globalStateSlice";
import CustomImage from "@/components/Common/CustomImage";
import { cn } from "@/lib/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Checkbox } from "@/components/ui/checkbox";
import { PhotoProvider, PhotoView } from "react-photo-view";
import "react-photo-view/dist/react-photo-view.css";
import { getIsRtl } from "@/redux/reducer/languageSlice";


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

const renderMessageContent = (message, isCurrentUser, onDelete, selectMode, selectedMessages, setSelectedMessages, setSelectMode, isRTL) => {
  const baseTextClass = isCurrentUser
    ? "text-white bg-primary p-2 rounded-md w-fit"
    : "text-black bg-border p-2 rounded-md w-fit";

  const audioStyles = isCurrentUser ? "border-primary" : "border-border";

  let content;
  switch (message.message_type) {
    case "audio":
      content = (
        <audio
          src={message.audio}
          controls
          className={`w-full sm:w-[80%] ${isCurrentUser ? "self-end" : "self-start"
            } rounded-md border-2 ${audioStyles}`}
          controlsList="nodownload"
          type="audio/mpeg"
          preload="metadata"
        />
      );
      break;

    case "file":
      content = (
        <div className={`${baseTextClass}`}>
          <PhotoView src={message.file}>
            <CustomImage
              src={message.file}
              alt="Chat Image"
              className="rounded-md w-auto h-auto max-h-[180px] max-w-[180px] sm:max-h-[250px] sm:max-w-[250px] object-contain cursor-pointer"
              width={200}
              height={200}
            />
          </PhotoView>
        </div>
      );
      break;

    case "file_and_text":
      content = (
        <div className={`${baseTextClass} flex flex-col gap-2`}>
          <PhotoView src={message.file}>
            <CustomImage
              src={message.file}
              alt="Chat Image"
              className="rounded-md w-auto h-auto max-h-[180px] max-w-[180px] sm:max-h-[250px] sm:max-w-[250px] object-contain cursor-pointer"
              width={200}
              height={200}
            />
          </PhotoView>
          <div className="border-white/20 break-all">{message.message}</div>
        </div>
      );
      break;
    default:
      content = (
        <p
          className={`${baseTextClass} whitespace-pre-wrap break-all ${isCurrentUser ? "self-end ltr:pr-8 rtl:pl-8" : "self-start"
            }`}
        >
          {message?.message}
        </p>
      );
  }

  const isSelected = selectedMessages.includes(message.id);

  const toggleSelection = () => {
    if (isSelected) {
      setSelectedMessages(prev => prev.filter(id => id !== message.id));
    } else {
      setSelectedMessages(prev => [...prev, message.id]);
    }
  };

  const handleSelectClick = () => {
    setSelectMode(true);
    setSelectedMessages([message.id]);
  };

  return (
    <div className={cn(
      "relative group w-fit flex items-center gap-3",
      isCurrentUser ? "self-end" : "self-start",
      selectMode && "cursor-pointer",
      message.message_type === "audio" && "w-full"
    )}
      onClick={selectMode ? toggleSelection : undefined}
    >
      <div className={cn("flex-1", message.message_type === "audio" && cn("w-full flex", isCurrentUser ? "justify-end" : "justify-start"))}>
        {content}
      </div>

      {selectMode && (
        <Checkbox
          checked={isSelected}
          onCheckedChange={toggleSelection}
          className="rounded-full"
        />
      )}

      {isCurrentUser && !selectMode && <div className="absolute bottom-1 ltr:right-1 rtl:left-1">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              className="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded-full hover:bg-black/10 text-white outline-none"
            >
              <MoreVertical className="w-4 h-4" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align={isRTL ? "start" : "end"}>
            <DropdownMenuItem
              className="cursor-pointer text-sm font-medium"
              onClick={handleSelectClick}
            >
              {t("select")}
            </DropdownMenuItem>
            <DropdownMenuItem
              className="cursor-pointer text-sm font-medium text-destructive"
              onClick={() => onDelete(message.id)}
            >
              {t("delete")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>}
    </div>
  );
};

const ChatMessages = ({
  selectedChatDetails,
  isSelling,
  setSelectedChatDetails,
  chatId,
  selectMode,
  setSelectMode,
  selectedMessages,
  setSelectedMessages,
  chatMessages,
  setChatMessages,
  setChatListData
}) => {
  const notification = useSelector(getNotification);
  const [currentMessagesPage, setCurrentMessagesPage] = useState(1);
  const [hasMoreChatMessages, setHasMoreChatMessages] = useState(false);
  const [isLoadPrevMesg, setIsLoadPrevMesg] = useState(false);
  const [IsLoading, setIsLoading] = useState(false);
  const [showReviewDialog, setShowReviewDialog] = useState(false);
  const isRTL = useSelector(getIsRtl);
  const scrollRef = useRef(null);
  const isAskForReview =
    !isSelling &&
    selectedChatDetails?.item?.status === "sold out" &&
    !selectedChatDetails?.item?.review &&
    Number(selectedChatDetails?.item?.sold_to) ===
    Number(selectedChatDetails?.buyer_id);

  const user = useSelector(userSignUpData);
  const userId = user?.id;

  useEffect(() => {
    if (chatId) {
      fetchChatMessgaes(1);
    }

    const handleRefresh = () => {
      if (chatId) fetchChatMessgaes(1);
    };

    window.addEventListener("refreshChatMessages", handleRefresh);
    return () => window.removeEventListener("refreshChatMessages", handleRefresh);
  }, [chatId]);

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
        item_offer_id: chatId,
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

  const handleDeleteMessage = async (messageId) => {
    try {
      const response = await deleteChatMessagesApi.deleteChatMessages({
        item_offer_id: chatId,
        message_ids: [messageId],
      });
      if (response?.data?.error === false) {
        setChatMessages((prev) => prev.filter((msg) => msg.id !== messageId));
        toast.success(response?.data?.message);
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
      toast.error(t("somthingWentWrong"));
    }
  };

  useEffect(() => {
    const lastMessage = chatMessages[chatMessages.length - 1];
    if (lastMessage && !IsLoading) {
      setTimeout(() => {
        if (scrollRef.current) {
          scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
        }
      }, 0);
    }
  }, [chatMessages[chatMessages.length - 1]?.id, IsLoading]);

  return (
    <>
      <PhotoProvider>
        <div
          ref={scrollRef}
          className="flex-1 overflow-y-auto bg-muted p-4 flex flex-col gap-2.5 relative"
        >
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
                  const containerClasses = `flex flex-col gap-1 rounded-md p-2 w-fit ${isSeller ? "bg-border" : "bg-primary text-white self-end"
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

              {(() => {
                let lastShownDate = null;
                return chatMessages &&
                  chatMessages.length > 0 &&
                  chatMessages.map((message) => {
                    const messageDate = formatMessageDate(message.created_at);
                    const showDateSeparator =
                      messageDate !== lastShownDate;
                    if (showDateSeparator) {
                      lastShownDate = messageDate;
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
                            {renderMessageContent(message, true, handleDeleteMessage, selectMode, selectedMessages, setSelectedMessages, setSelectMode, isRTL)}
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
                            {renderMessageContent(message, false, handleDeleteMessage, selectMode, selectedMessages, setSelectedMessages, setSelectMode, isRTL)}
                            <p className="text-xs text-muted-foreground ltr:text-left rtl:text-right">
                              {formatChatMessageTime(message?.created_at)}
                            </p>
                          </div>
                        )}
                      </Fragment>
                    );
                  })
              })()}
            </>
          )}
        </div>
      </PhotoProvider>
      {isAskForReview && (
        <GiveReview
          key={`review-${selectedChatDetails?.id}`}
          itemId={selectedChatDetails?.item_id}
          setSelectedChatDetails={setSelectedChatDetails}
          setChatListData={setChatListData}
        />
      )}
      <SendMessage
        key={`send-${selectedChatDetails?.id || ""}`}
        selectedChatDetails={selectedChatDetails}
        setChatMessages={setChatMessages}
      />
    </>
  );
};

export default ChatMessages;