'use client'
import { Table, Skeleton } from 'antd';
import Image from 'next/image';
import { formatDateMonth, isLogin, placeholderImage, t } from '@/utils';
import { getNotificationList } from '@/utils/api';
import toast from 'react-hot-toast';
import { useEffect, useState, useRef } from 'react';
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice';
import { useSelector } from 'react-redux';

const NotificationTable = () => {

    const CurrentLanguage = useSelector(CurrentLanguageData)
    const [notifications, setNotifications] = useState([]);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalItems, setTotalItems] = useState(0);
    const [perPage, setPerPage] = useState(15);
    const [isLoading, setIsLoading] = useState(false);



    const fetchNotificationData = async (page) => {
        try {
            setIsLoading(true);
            const response = await getNotificationList.getNotification({ page });
            const { data } = response.data;
            if (data.error !== true) {
                setNotifications(data.data);
                setTotalItems(data.total);
                setPerPage(data.per_page);
            } else {
                toast.error(data.message);
            }
            setIsLoading(false);
        } catch (error) {
            console.error("Error:", error);
            setIsLoading(false);
        }
    };

    useEffect(() => {
        if (isLogin()) {
            fetchNotificationData(currentPage);
        }
    }, [currentPage]);

    const handleTableChange = (pagination) => {
        setCurrentPage(pagination.current);
    };

    const columns = [
        {
            title: t('notification'),
            dataIndex: 'notification',
            key: 'notification',
            width: '70%',
            render: (text, record) => (
                <NotificationContent
                    text={record.notification}
                    title={record.title}
                    image={record.image}
                />
            ),
        },
        {
            title: t('date'),
            dataIndex: 'date',
            key: 'date',
            width: '30%',
            align: 'center',
        }
    ];

    const skeletonColumns = [
        {
            title: t('notification'),
            dataIndex: 'notification',
            key: 'notification',
            width: '70%',
            render: () => (
                <div className='notif_content_wrp'>
                    <Skeleton.Avatar active size={48} shape="square" style={{ borderRadius: "4px" }} />
                    <div className='noti_title_desc'>
                        <Skeleton.Input active size="small" style={{ width: 100, marginBottom: 8 }} />
                        <Skeleton.Input active size="small" style={{ width: 150 }} />
                    </div>
                </div>
            ),
        },
        {
            title: t('date'),
            dataIndex: 'date',
            key: 'date',
            width: '30%',
            align: 'center',
            render: () => <Skeleton.Input active size="small" style={{ width: 80 }} />,
        }
    ];

    return (
        <>
            {isLoading ? (
                <Table
                    columns={skeletonColumns}
                    dataSource={Array.from({ length: 10 }, (_, index) => ({ key: index }))}
                    className="notif_table"
                    pagination={false}
                />
            ) : (
                <Table
                    columns={columns}
                    dataSource={notifications.map((notification, index) => ({
                        key: index + 1,
                        image: notification?.image,
                        title: notification.title,
                        notification: notification.message,
                        date: formatDateMonth(notification.created_at),
                    }))}
                    className="notif_table"
                    pagination={
                        notifications.length >= 15 || currentPage !== 1
                            ? {
                                current: currentPage,
                                pageSize: perPage,
                                total: totalItems,
                                showTotal: (total, range) => `Showing ${range[0]}-${range[1]} of ${total}`,
                                onChange: (page) => setCurrentPage(page),
                                showSizeChanger: false,
                            }
                            : false
                    }
                    onChange={handleTableChange}
                />
            )}
        </>
    );
};

export default NotificationTable;




const NotificationContent = ({ text, title, image }) => {
    const textRef = useRef(null);
    const [isTextOverflowing, setIsTextOverflowing] = useState(false);
    const [isExpanded, setIsExpanded] = useState(false);

    useEffect(() => {
        const checkTextOverflow = () => {
            if (textRef.current) {
                const element = textRef.current;
                const isOverflowing = element.scrollHeight > element.clientHeight;
                setIsTextOverflowing(isOverflowing);
            }
        };

        checkTextOverflow();
        window.addEventListener('resize', checkTextOverflow);

        return () => window.removeEventListener('resize', checkTextOverflow);
    }, []); // Add text as dependency to recheck when content changes

    return (
        <div className='notif_content_wrp'>
            <Image
                src={image || placeholderImage}
                alt="Notification"
                width={48}
                height={48}
                className='notificationImage'
                onErrorCapture={placeholderImage}
            />
            <div className='noti_title_desc'>
                <h6 className='m-0'>{title}</h6>

                <p ref={textRef} className={`${!isExpanded ? 'notficationDesc' : ''} m-0`}>{text}</p>
                {isTextOverflowing && (
                    <button className='seeMoreLessBtn notificationSeeMoreLessBtn' onClick={() => setIsExpanded(!isExpanded)}>
                        {isExpanded ? t('seeLess') : t('seeMore')}
                    </button>
                )}

            </div>
        </div>
    );
};
