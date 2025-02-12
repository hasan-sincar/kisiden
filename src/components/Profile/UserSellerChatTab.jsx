'use client'
import Image from 'next/image'
import { formatTime, placeholderImage } from '@/utils'

const UserSellerChatTab = ({ isActive, chat, handleChatTabClick }) => {

    const isUnread = chat?.unread_chat_count > 0

    return (
        // Pass the chat ID to the handler
        <div className="chat_user_tab_wrapper" onClick={() => handleChatTabClick(chat)}>
            <div className={`chat_user_tab ${isActive && 'chat_user_tab_active'}`}>
                <div className="user_name_img">
                    <div className="user_chat_tab_img_cont">
                        <Image src={chat?.buyer?.profile ? chat?.buyer?.profile : placeholderImage} alt="User" width={56} height={56} className="user_chat_tab_img" onErrorCapture={placeholderImage} />
                        <Image src={chat?.item?.image ? chat?.item?.image : placeholderImage} alt="User" width={24} height={24} className="user_chat_small_img" onErrorCapture={placeholderImage} />
                    </div>
                    <div className="user_det">
                        <div className='chat_content_separator'>
                            <h6 title={chat?.buyer?.name}>{chat?.buyer?.name}</h6>
                            <span className="user_chat_tab_time">{formatTime(chat?.created_at)}</span>
                        </div>
                        <div className='chat_content_separator'>
                            <span title={chat?.item?.name} className='reviewItemName'>{chat?.item?.name}</span>
                            {
                                isUnread && !isActive && <span className='chat_count'>{chat?.unread_chat_count}</span>
                            }
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default UserSellerChatTab