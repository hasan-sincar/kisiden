"use client";
import { getAdsenseSettings } from "@/redux/reducer/settingSlice";
import AdSlot from "./AdSlot";
import { useSelector } from "react-redux";

export default function AdBanner({ className }) {

    const { adsense_enabled, adsense_banner_slot_id } = useSelector(getAdsenseSettings)


    // 🚫 Disabled
    if (!adsense_enabled) return null;

    if (!adsense_banner_slot_id) return null;

    return (
        <AdSlot
            adSlotId={adsense_banner_slot_id}
            height={200}
            className={className}
        />
    );
}
