import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import { getIsPaidApi } from "@/redux/reducer/settingSlice";
import { getLocationApi } from "@/utils/api";
import { useSelector } from "react-redux";

const useGetLocation = () => {
  const IsPaidApi = useSelector(getIsPaidApi);
  const currentLangCode = useSelector(getCurrentLangCode);

  const fetchLocationData = async (pos) => {
    const { lat, lng } = pos;

    const response = await getLocationApi.getLocation({
      lat,
      lng,
      lang: IsPaidApi ? "en" : currentLangCode,
    });

    if (response?.data?.error !== false) {
      throw new Error("Location fetch failed");
    }

    /* ================= GOOGLE PLACES (PAID API) ================= */
    if (IsPaidApi) {
      let city = "";
      let state = "";
      let country = "";

      const results = response?.data?.data?.results || [];

      results.forEach((result) => {
        const getComponent = (type) =>
          result.address_components.find((c) => c.types.includes(type))
            ?.long_name || "";

        if (!city) city = getComponent("locality");
        if (!state) state = getComponent("administrative_area_level_1");
        if (!country) country = getComponent("country");
      });

      return {
        lat,
        long: lng,
        city,
        state,
        country,
        formattedAddress: [city, state, country].filter(Boolean).join(", "),
      };
    }

    /* ================= INTERNAL LOCATION API ================= */
    const r = response?.data?.data;

    const formattedAddress = [r?.area, r?.city, r?.state, r?.country]
      .filter(Boolean)
      .join(", ");

    const address_translated = [
      r?.area_translation,
      r?.city_translation,
      r?.state_translation,
      r?.country_translation,
    ]
      .filter(Boolean)
      .join(", ");

    return {
      lat: r?.latitude,
      long: r?.longitude,
      city: r?.city || "",
      state: r?.state || "",
      country: r?.country || "",
      area: r?.area || "",
      areaId: r?.area_id || "",

      // English (API / backend)
      formattedAddress,

      // Translated (UI)
      address_translated,
    };
  };

  return { fetchLocationData };
};

export default useGetLocation;
