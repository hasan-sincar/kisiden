import { useEffect, useRef } from "react";
import { useSearchParams } from "next/navigation";
import { useSelector } from "react-redux";
import { getIsPaidApi } from "@/redux/reducer/settingSlice";
import { getLocationApi } from "@/utils/api";

export const useTranslateLocationInUrl = () => {
    const searchParams = useSearchParams();
    const isFirstRender = useRef(true);
    const IsPaidApi = useSelector(getIsPaidApi);
    const langCode = searchParams.get("lang");


    useEffect(() => {
        // 1. Skip the first render
        if (isFirstRender.current) {
            isFirstRender.current = false;
            return;
        }

        const translateLocation = async () => {
            // 1. Extract all individual parts from the current URL
            const country = searchParams.get("country");
            const state = searchParams.get("state");
            const city = searchParams.get("city");
            const area = searchParams.get("area");
            const areaId = searchParams.get("areaId");
            const lat = searchParams.get("lat");
            const lng = searchParams.get("lng");
            // 2. Prerequisites check
            if (IsPaidApi || !lat || !lng) return;
            if (!country && !state && !city && !areaId) return;
            try {
                const response = await getLocationApi.getLocation({
                    lat: lat,
                    lng: lng,
                    lang: langCode,
                });
                if (response?.data?.error === false) {
                    const result = response.data.data;

                    // 3. Clone current params so we don't lose query, sort_by, etc.
                    const newParams = new URLSearchParams(searchParams);
                    // 4. Construct the translated string specifically for the UI Label
                    const parts = [];
                    // Use the translations returned by the API
                    if (area) parts.push(result?.area_translation);
                    if (city) parts.push(result?.city_translation);
                    if (state) parts.push(result?.state_translation);
                    if (country) parts.push(result?.country_translation);

                    const finalLocationLabel = parts.filter(Boolean).join(", ");
                    // 5. Update ONLY the 'location' parameter used for display
                    if (finalLocationLabel) {
                        newParams.set("location", finalLocationLabel);
                    }
                    // Optional: You can also update individual params if they exist, 
                    // but if you ONLY want to fix the Badge/Label, just setting 'location' is enough.
                    // 6. Update URL (history.pushState prevents a full page reload)
                    window.history.pushState(
                        null,
                        "",
                        `${window.location.pathname}?${newParams.toString()}`
                    );
                }
            } catch (error) {
                console.error("useTranslateLocationInUrl error:", error);
            }
        };

        translateLocation();
    }, [langCode]); // Only triggers when language changes
};
