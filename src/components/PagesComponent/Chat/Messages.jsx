"use client"
import PushNotificationLayout from '@/components/firebaseNotification/PushNotificationLayout';
import React, { useState } from 'react';
import Chat from './Chat';
import { useSelector } from 'react-redux';
import withRedirect from '@/components/Layout/withRedirect';

const Messages = () => {

    const [activeTab, setActiveTab] = useState('selling')
    const [chatMessages, setChatMessages] = useState([]);
    const [notificationData, setNotificationData] = useState([]);
    const ChatOfferData = useSelector((state) => state?.OfferData)
    const defaultSelected = ChatOfferData?.data ? ChatOfferData?.data : "";
    const [selectedTabData, setSelectedTabData] = useState(defaultSelected ? defaultSelected : null);

    const handleNotificationReceived = (data) => {
        setNotificationData(data);
    };

    return (
        <PushNotificationLayout onNotificationReceived={handleNotificationReceived} setActiveTab={setActiveTab} setChatMessages={setChatMessages} selectedTabData={selectedTabData} setSelectedTabData={setSelectedTabData} defaultSelected={defaultSelected}>
            <Chat activeTab={activeTab} setActiveTab={setActiveTab} chatMessages={chatMessages} setChatMessages={setChatMessages} selectedTabData={selectedTabData} setSelectedTabData={setSelectedTabData} defaultSelected={defaultSelected} />
        </PushNotificationLayout>
    );
}

export default withRedirect(Messages);
