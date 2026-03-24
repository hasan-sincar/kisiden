"use client";

import { useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { getAdsenseSettings } from "@/redux/reducer/settingSlice";

export default function AdSlot({ adSlotId, height = 250, className = "" }) {
    const adRef = useRef(null);
    const { adsense_client_id, adsense_enabled, adsense_mode } = useSelector(getAdsenseSettings)

    // 2. Add the centralized production check
    if (!adsense_enabled || adsense_mode !== 'manual' || !adsense_client_id) {
        return null;
    }

    useEffect(() => {
        if (!adsense_client_id) return;

        window.adsbygoogle = window.adsbygoogle || [];
        let timer;
        let attempts = 0;
        const maxAttempts = 20; // retry for ~2 seconds

        const tryPush = () => {
            attempts++;
            if (adRef.current && adRef.current.offsetWidth > 0) {
                try {
                    if (!adRef.current.hasAttribute("data-adsbygoogle-status")) {
                        window.adsbygoogle.push({});
                        console.log('Ad pushed successfully')
                    }
                } catch (err) {
                    console.error("AdSense error:", err);
                }
                return;
            }
            if (attempts < maxAttempts) {
                timer = setTimeout(tryPush, 100);
            }
        };
        tryPush();
        return () => {
            if (timer) clearTimeout(timer);
        };
    }, [adSlotId, adsense_client_id]);


    return (
        <div
            key={adSlotId}
            className={className}
            style={{ width: "100%", height }}
        >
            <ins
                ref={adRef}
                className="adsbygoogle"
                style={{ display: "block" }}
                data-ad-client={adsense_client_id}
                data-ad-slot={adSlotId}
                data-full-width-responsive="true"
            />
        </div>
    );
}
