"use client";

import { useSearchParams } from "next/navigation";
import { useSelector } from "react-redux";
import { getCityData, getKilometerRange } from "@/redux/reducer/locationSlice";

export const useUpdateLocationInUrl = () => {
    const searchParams = useSearchParams()
    const cityData = useSelector(getCityData);
    const KmRange = useSelector(getKilometerRange);


    // 3. New function specifically for Search & Featured Sections
    const generateAdsUrl = (additionalParams = {}, useHeaderLocation = true) => {
        const params = new URLSearchParams();

        // A. Handle Location
        if (useHeaderLocation) {
            // Take location from Redux (Header)
            if (cityData.country) params.set("country", cityData.country);
            if (cityData.state) params.set("state", cityData.state);
            if (cityData.city) params.set("city", cityData.city);
            if (cityData.area) params.set("area", cityData.area);
            if (cityData.areaId) params.set("areaId", cityData.areaId);
            const locationLabel = cityData.address_translated || cityData.formattedAddress;
            if (locationLabel) params.set("location", locationLabel);
            if (cityData.lat) params.set("lat", cityData.lat);
            if (cityData.long) params.set("lng", cityData.long);
            if (Number(KmRange) > 0 && (cityData.city || cityData.areaId)) {
                params.set("km_range", KmRange.toString());
            }
        } else {
            // Take location from current URL (to keep existing filter on Ads page)
            const currentParams = getParamsFromUrl();
            Object.entries(currentParams).forEach(([key, value]) => {
                if (value) params.set(key, value);
            });
        }
        // B. Handle Additional Params (query, category, etc.)
        Object.entries(additionalParams).forEach(([key, value]) => {
            if (value && value !== "all-categories") {
                params.set(key, value);
            } else {
                params.delete(key);
            }
        });
        return `/ads?${params.toString()}`;
    };


    const updateLocationInUrl = (data) => {
        const params = new URLSearchParams(searchParams);
        // Clear old location and range params
        ["country", "state", "city", "area", "areaId", "lat", "lng", "km_range", "location"].forEach((key) =>
            params.delete(key)
        );
        // Set new ones
        if (data.country) params.set("country", data.country);
        if (data.state) params.set("state", data.state);
        if (data.city) params.set("city", data.city);
        if (data.area) params.set("area", data.area);
        if (data.areaId) params.set("areaId", data.areaId);
        const locationLabel = data.address_translated || data.formattedAddress;
        if (locationLabel) params.set("location", locationLabel);
        // Add lat/long only if city or areaId exists
        if (data.lat) params.set("lat", data.lat);
        if (data.long) params.set("lng", data.long);

        if (Number(data?.km_range) > 0) {
            params.set("km_range", data.km_range.toString());
        }
        const queryString = params.toString();
        const newUrl = queryString ? `/ads?${queryString}` : "/ads";
        window.history.pushState(null, "", newUrl);
    };

    const getParamsFromUrl = () => {
        const locationSearchParams = {
            country: searchParams.get("country"),
            state: searchParams.get("state"),
            city: searchParams.get("city"),
            area: searchParams.get("area"),
            areaId: searchParams.get("areaId"),
            lat: searchParams.get("lat"),
            lng: searchParams.get("lng"),
            km_range: searchParams.get("km_range"),
            location: searchParams.get("location"),
        }
        return locationSearchParams;
    }

    return { updateLocationInUrl, getParamsFromUrl, generateAdsUrl };
};
