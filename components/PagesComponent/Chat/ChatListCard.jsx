import { formatTime } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import CustomImage from "@/components/Common/CustomImage";

const ChatListCard = ({ chat, isSelling, isActive, handleChatTabClick }) => {
  const user = isSelling ? chat?.buyer : chat?.seller;
  const isUnread = chat?.unread_chat_count > 0;

  return (
    <CustomLink
      scroll={false}
      href={`/chat?activeTab=${isSelling ? "selling" : "buying"}&chatid=${
        chat?.id
      }`}
      onClick={() => handleChatTabClick(chat, isSelling)}
      className={`py-3 px-4 border-b flex items-center gap-4 cursor-pointer ${
        isActive ? "bg-primary text-white" : ""
      }`}
    >
      <div className="relative flex-shrink-0">
        <CustomImage
          src={user?.profile}
          alt="User avatar"
          width={56}
          height={56}
          className="w-[56px] h-auto aspect-square object-cover rounded-full"
        />

        <CustomImage
          src={chat?.item?.image}
          alt="Item image"
          width={24}
          height={24}
          className="w-[24px] h-auto aspect-square object-cover rounded-full absolute top-[32px] bottom-[-6px] right-[-6px]"
        />
      </div>
      <div className="flex flex-col gap-2 w-full min-w-0">
        <div className="w-full flex items-center gap-1 justify-between min-w-0">
          <h5 className="font-medium truncate" title={user?.name}>
            {user?.name}
          </h5>
          <span className="text-xs">{formatTime(chat?.last_message_time)}</span>
        </div>
        <div className="flex items-center gap-1 justify-between">
          <p
            className="truncate text-sm"
            title={chat?.item?.translated_name || chat?.item?.name}
          >
            {chat?.item?.translated_name || chat?.item?.name}
          </p>
          {isUnread && !isActive && (
            <span className="flex items-center justify-center bg-primary text-white rounded-full px-2 py-1 text-xs">
              {chat?.unread_chat_count}
            </span>
          )}
        </div>
      </div>
    </CustomLink>
  );
};

export default ChatListCard;
