import { useState, useEffect, useRef } from "react";
import { useDebounce } from "use-debounce";
import { getLocationApi } from "@/utils/api";
import { useSelector } from "react-redux";
import { getIsPaidApi } from "@/redux/reuducer/settingSlice";
import { getKilometerRange, saveCity } from "@/redux/reuducer/locationSlice";
import { useRouter } from "next/navigation";

export default function useSearchAutocomplete(saveOnSuggestionClick, onLocationSelect, OnHide) {

    const router = useRouter();
    const IsPaidApi = useSelector(getIsPaidApi);
    const KmRange = useSelector(getKilometerRange);

    const [search, setSearch] = useState("");
    const [debouncedSearch] = useDebounce(search, 500);
    const [autoState, setAutoState] = useState({
        suggestions: [],
        loading: false,
        show: false,
    });
    const [selectedLocation, setSelectedLocation] = useState(null);
    const isSuggestionClick = useRef(false);


    // Fetch suggestions
    useEffect(() => {
        const fetchSuggestions = async () => {
            if (isSuggestionClick.current) {
                isSuggestionClick.current = false;
                return;
            }

            if (debouncedSearch && debouncedSearch.length > 1) {
                setAutoState((prev) => ({ ...prev, loading: true, show: true }));
                try {
                    const response = await getLocationApi.getLocation({
                        search: debouncedSearch,
                        lang: "en",
                    });

                    if (IsPaidApi) {
                        const results = response?.data?.data?.predictions || [];
                        setAutoState({ suggestions: results, loading: false, show: true });
                    } else {
                        const results = response?.data?.data || [];
                        const formattedResults = results.map(result => ({
                            description: [result?.area, result?.city, result?.state, result?.country].filter(Boolean).join(", "),
                            original: result,
                        }));
                        setAutoState({ suggestions: formattedResults, loading: false, show: true });
                    }
                } catch(error) {
                    console.log("error", error);
                    setAutoState({ suggestions: [], loading: false, show: true });
                }
            } else {
                setAutoState({ suggestions: [], loading: false, show: false });
            }
        };

        fetchSuggestions();
    }, [debouncedSearch, IsPaidApi]);

    // Handlers
    const handleSearchChange = (e) => setSearch(e.target.value);

    const handleInputFocus = () => {
        if (autoState.suggestions.length > 0) {
            setAutoState((prev) => ({ ...prev, show: true }));
        }
    };

    const handleInputBlur = () => {
        setTimeout(() => {
            setAutoState((prev) => ({ ...prev, show: false }));
        }, 200);
    };

    const handleSuggestionClick = async (suggestion) => {
        isSuggestionClick.current = true;

        if (IsPaidApi) {
            const response = await getLocationApi.getLocation({
                place_id: suggestion.place_id,
                lang: "en",
            });

            const result = response?.data?.data?.results?.[0];
            const addressComponents = result.address_components || [];

            const getAddressComponent = (type) => {
                const component = addressComponents.find((comp) =>
                    comp.types.includes(type)
                );
                return component?.long_name || "";
            };

            const city = getAddressComponent("locality");
            const state = getAddressComponent("administrative_area_level_1");
            const country = getAddressComponent("country");

            const data = {
                lat: result?.geometry?.location?.lat,
                long: result?.geometry?.location?.lng,
                city,
                state,
                country,
                formattedAddress: result?.formatted_address,
            };

            setSearch(result?.formatted_address || "");
            setAutoState({ suggestions: [], loading: false, show: false });
            if (saveOnSuggestionClick) {
                saveCity(data);
                OnHide?.();
                router.push("/");
            } else {
                setSelectedLocation(data);
                onLocationSelect?.(data);
            }
        } else {
            const original = suggestion.original;

            const data = {
                lat: original?.latitude,
                long: original?.longitude,
                city: original?.city || "",
                state: original?.state || "",
                country: original?.country || "",
                formattedAddress: suggestion.description || "",
                area: original?.area || "",
                areaId: original?.area_id || "",
            };

            setSearch(suggestion?.description || "");
            setAutoState({ suggestions: [], loading: false, show: false });

            if (saveOnSuggestionClick) {
                saveCity(data);
                OnHide?.();
                router.push("/");
            } else {
                setSelectedLocation(data);
                onLocationSelect?.(data);
            }
        }
    };



    return {
        search,
        setSearch,
        autoState,
        setAutoState,
        handleSearchChange,
        handleInputFocus,
        handleInputBlur,
        handleSuggestionClick,
        KmRange,
        selectedLocation,
        isSuggestionClick,
    };
}
