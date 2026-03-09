"use client";
import { useEffect, useRef, useState } from "react";
import "firebase/messaging";
import FirebaseData from "../../utils/Firebase";
import { useDispatch, useSelector } from "react-redux";
import { setNotification } from "@/redux/reducer/globalStateSlice";
import { useNavigate } from "../Common/useNavigate";
import { getIsLoggedIn } from "@/redux/reducer/authSlice";

const PushNotificationLayout = ({ children }) => {
  const dispatch = useDispatch();
  const [fcmToken, setFcmToken] = useState("");
  const { fetchToken, onMessageListener } = FirebaseData();
  const { navigate } = useNavigate();
  const isLoggedIn = useSelector(getIsLoggedIn);
  const unsubscribeRef = useRef(null);

  const handleFetchToken = async () => {
    await fetchToken(setFcmToken);
  };

  // Fetch token when user logs in
  useEffect(() => {
    handleFetchToken();
  }, []);

  // Set up message listener when logged in, clean up when logged out
  useEffect(() => {
    if (!isLoggedIn) {
      // Clean up listener when user logs out
      if (unsubscribeRef.current) {
        unsubscribeRef.current();
        unsubscribeRef.current = null;
      }
      return;
    }

    // Set up listener when user logs in
    const setupListener = async () => {
      try {
        unsubscribeRef.current = await onMessageListener((payload) => {
          if (payload && payload.data) {
            dispatch(setNotification(payload.data));
            if (Notification.permission === "granted") {
              const notif = new Notification(payload.notification.title, {
                body: payload.notification.body,
              });
              const tab =
                payload.data?.user_type === "Seller" ? "buying" : "selling";

              notif.onclick = () => {
                if (
                  payload.data.type === "chat" ||
                  payload.data.type === "offer"
                ) {
                  navigate(
                    `/chat?activeTab=${tab}&chatid=${payload.data?.item_offer_id}`
                  );
                }
              };
            }
          }
        });
      } catch (err) {
        console.error("Error handling foreground notification:", err);
      }
    };

    setupListener();

    // Cleanup on unmount or logout
    return () => {
      if (unsubscribeRef.current) {
        unsubscribeRef.current();
        unsubscribeRef.current = null;
      }
    };
  }, [isLoggedIn, dispatch, navigate, onMessageListener]);

  useEffect(() => {
    if (fcmToken) {
      if ("serviceWorker" in navigator) {
        navigator.serviceWorker
          .register("/firebase-messaging-sw.js")
          .then((registration) => {
            console.log(
              "Service Worker registration successful with scope: ",
              registration.scope
            );
          })
          .catch((err) => {
            console.log("Service Worker registration failed: ", err);
          });
      }
    }
  }, [fcmToken]);

  return children;
};

export default PushNotificationLayout;
