"use client";
import { useSelector } from "react-redux";
import AdSlot from "./AdSlot";
import { getAdsenseSettings } from "@/redux/reducer/settingSlice";

export default function AdSquare({ className }) {
    const { adsense_enabled, adsense_square_slot_id } = useSelector(getAdsenseSettings)
    // 🚫 Disabled
    if (!adsense_enabled) return null;

    if (!adsense_square_slot_id) return null;

    return (
        <AdSlot
            adSlotId={adsense_square_slot_id}
            height="auto"
            className={className}
        />
    );
}
