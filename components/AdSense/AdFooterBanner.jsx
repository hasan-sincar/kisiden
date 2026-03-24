"use client";
import { useSelector } from "react-redux";
import AdSlot from "./AdSlot";
import { getAdsenseSettings } from "@/redux/reducer/settingSlice";

export default function AdFooterBanner({ className }) {
    const { adsense_enabled, adsense_banner_slot_id } = useSelector(getAdsenseSettings)


    // 🚫 Disabled
    if (!adsense_enabled) return null;

    if (!adsense_banner_slot_id) return null;

    return (
        <AdSlot
            adSlotId={adsense_banner_slot_id}
            height={90}
            className={className}
        />
    );
}
