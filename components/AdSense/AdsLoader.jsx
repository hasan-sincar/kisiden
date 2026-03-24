"use client";
import { getAdsenseSettings } from "@/redux/reducer/settingSlice";
import { useEffect } from "react";
import { useSelector } from "react-redux";

export default function AdsLoader() {

    const { adsense_enabled, adsense_client_id } = useSelector(getAdsenseSettings)

    useEffect(() => {
        // 1. Exit if AdSense is disabled or Client ID is not yet fetched
        if (!adsense_enabled || !adsense_client_id) return;
        // 2. Safety check: avoid adding the script multiple times
        if (document.getElementById("adsense-script")) return;
        const script = document.createElement("script");
        script.id = "adsense-script";
        script.async = true;
        script.src =
            "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=" +
            adsense_client_id;
        script.crossOrigin = "anonymous";
        document.head.appendChild(script);
    }, [adsense_enabled, adsense_client_id]);
    return null;
}
