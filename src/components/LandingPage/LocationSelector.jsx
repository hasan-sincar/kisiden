"use client";
import { useEffect, useRef, useState } from "react";
import { MdOutlineKeyboardArrowRight, MdArrowBack } from "react-icons/md";
import PlacesSkeleton from "../Skeleton/PlacesSkeleton";
import { useInView } from "react-intersection-observer";
import NoData from "../NoDataFound/NoDataFound";
import { t } from "@/utils";
import {
  getCoutriesApi,
  getStatesApi,
  getCitiesApi,
  getAreasApi,
  getLocationApi,
} from "@/utils/api";
import { BiCurrentLocation } from "react-icons/bi";
import { IoSearch } from "react-icons/io5";
import { useDebounce } from "use-debounce";
import {
  resetCityData,
  saveCity,
  setKilometerRange,
} from "@/redux/reuducer/locationSlice";
import { useRouter } from "next/navigation";
import { useDispatch, useSelector } from "react-redux";
import { getIsPaidApi, getMinRange } from "@/redux/reuducer/settingSlice";
import useSearchAutocomplete from "./useSearchAutocomplete";
import SearchAutocomplete from "./SearchAutocomplete";
import axios from "axios";

const LocationSelector = ({
  OnHide,
  setSelectedCity,
  setIsMapLocation,
}) => {
  const [selectedLocation, setSelectedLocation] = useState({
    country: null,
    state: null,
    city: null,
    area: null,
  });
  const [search, setSearch] = useState("");
  const [debouncedSearch] = useDebounce(search, 500);
  const [currentView, setCurrentView] = useState("countries");
  const [locationData, setLocationData] = useState({
    items: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: false,
  });

  const skipNextSearchEffect = useRef(false);
  const viewHistory = useRef([]);
  const [locationStatus, setLocationStatus] = useState(null);
  const { ref, inView } = useInView();
  const minLength = useSelector(getMinRange);
  const dispatch = useDispatch();
  const router = useRouter();
  const IsPaidApi = useSelector(getIsPaidApi);
  const saveOnSuggestionClick = true;


  const {
    search: autoSearch,
    setSearch: setAutoSearch,
    handleSearchChange,
    handleInputFocus,
    handleInputBlur,
    handleSuggestionClick,
    autoState,
  } = useSearchAutocomplete(saveOnSuggestionClick, null, OnHide);



  useEffect(() => {
    if (skipNextSearchEffect.current) {
      skipNextSearchEffect.current = false;
      return;
    }
    fetchData(debouncedSearch);
  }, [debouncedSearch]);

  useEffect(() => {
    if (inView && locationData?.hasMore && !locationData?.isLoading) {
      fetchData(debouncedSearch, locationData?.currentPage + 1);
    }
  }, [inView]);

  const handleSubmitLocation = () => {
    minLength > 0
      ? dispatch(setKilometerRange(minLength))
      : dispatch(setKilometerRange(0));
    router.push("/");
  };

  const fetchData = async (
    search = "",
    page = 1,
    view = currentView,
    location = selectedLocation
  ) => {
    try {
      setLocationData((prev) => ({
        ...prev,
        isLoading: page === 1,
        isLoadMore: page > 1,
      }));

      let response;

      const params = { page };
      if (search) {
        params.search = search;
      }

      switch (view) {
        case "countries":
          response = await getCoutriesApi.getCoutries(params);
          break;
        case "states":
          response = await getStatesApi.getStates({
            ...params,
            country_id: location.country.id,
          });
          break;
        case "cities":
          response = await getCitiesApi.getCities({
            ...params,
            state_id: location.state.id,
          });
          break;
        case "areas":
          response = await getAreasApi.getAreas({
            ...params,
            city_id: location.city.id,
          });
          break;
      }

      if (response.data.error === false) {
        const items = response.data.data.data;

        // MOD: if no results and not on countries, auto-save & close
        if (items.length === 0 && view !== "countries" && !search) {
          switch (view) {
            case "states":
              saveCity({
                city: "",
                state: "",
                country: location.country.name,
                lat: location.country.latitude,
                long: location.country.longitude,
              });
              break;
            case "cities":
              saveCity({
                city: "",
                state: location.state.name,
                country: location.country.name,
                lat: location.state.latitude,
                long: location.state.longitude,
              });
              break;
            case "areas":
              saveCity({
                city: location.city.name,
                state: location.state.name,
                country: location.country.name,
                lat: location.city.latitude,
                long: location.city.longitude,
              });
              break;
          }
          handleSubmitLocation();
          OnHide();
          return; // stop further processing
        }
        setLocationData((prev) => ({
          ...prev,
          items:
            page > 1
              ? [...prev.items, ...response.data.data.data]
              : response.data.data.data,
          hasMore:
            response.data.data.current_page < response.data.data.last_page,
          currentPage: response.data.data.current_page,
        }));
      }
    } catch (error) {
      console.log(error);
    } finally {
      setLocationData((prev) => ({
        ...prev,
        isLoading: false,
        isLoadMore: false,
      }));
    }
  };

  const getFormattedLocation = () => {
    if (!selectedLocation) return t("location");
    const parts = [];
    if (selectedLocation.area?.name) parts.push(selectedLocation.area.name);
    if (selectedLocation.city?.name) parts.push(selectedLocation.city.name);
    if (selectedLocation.state?.name) parts.push(selectedLocation.state.name);
    if (selectedLocation.country?.name)
      parts.push(selectedLocation.country.name);

    return parts.length > 0 ? parts.join(", ") : t("location");
  };

  const handleItemSelect = async (item) => {
    // MOD: push current state onto history
    viewHistory.current.push({
      view: currentView,
      location: selectedLocation,
      dataState: locationData,
      search: search,
    });

    let nextView = "";
    let newLocation = {};

    switch (currentView) {
      case "countries":
        newLocation = {
          ...selectedLocation,
          country: item,
          state: null,
          city: null,
          area: null,
        };
        nextView = "states";
        break;
      case "states":
        newLocation = {
          ...selectedLocation,
          state: item,
          city: null,
          area: null,
        };
        nextView = "cities";
        break;
      case "cities":
        newLocation = {
          ...selectedLocation,
          city: item,
          area: null,
        };
        nextView = "areas";
        break;
      case "areas":
        saveCity({
          country: selectedLocation?.country?.name,
          state: selectedLocation?.state?.name,
          city: selectedLocation?.city?.name,
          area: item?.name,
          areaId: item?.id,
        });
        handleSubmitLocation();
        OnHide();
        return;
    }
    setSelectedLocation(newLocation);
    setCurrentView(nextView);
    await fetchData("", 1, nextView, newLocation);
    if (search) {
      skipNextSearchEffect.current = true;
      setSearch("");
    }
  };

  const handleBack = async () => {
    const prev = viewHistory.current.pop();
    if (!prev) return;

    setCurrentView(prev.view);
    setSelectedLocation(prev.location);

    if (search !== prev.search) {
      skipNextSearchEffect.current = true;
      setSearch(prev.search);
    }
    if (prev.dataState) {
      setLocationData(prev.dataState);
    } else {
      await fetchData(prev.search ?? "", 1, prev.view, prev.location);
    }
  };

  const handleAllSelect = () => {
    switch (currentView) {
      case "countries":
        resetCityData();
        handleSubmitLocation();
        OnHide();
        break;
      case "states":
        saveCity({
          city: "",
          state: "",
          country: selectedLocation?.country?.name,
          lat: selectedLocation?.country?.latitude,
          long: selectedLocation?.country?.longitude,
        });
        handleSubmitLocation();
        OnHide();
        break;
      case "cities":
        saveCity({
          city: "",
          state: selectedLocation?.state?.name,
          country: selectedLocation?.country?.name,
          lat: selectedLocation?.state?.latitude,
          long: selectedLocation?.state?.longitude,
        });
        handleSubmitLocation();
        OnHide();
        break;
      case "areas":
        saveCity({
          city: selectedLocation?.city?.name,
          state: selectedLocation?.state?.name,
          country: selectedLocation?.country?.name,
          lat: selectedLocation?.city?.latitude,
          long: selectedLocation?.city?.longitude,
        });
        handleSubmitLocation();
        OnHide();
        break;
    }
  };

  const getTitle = () => {
    switch (currentView) {
      case "countries":
        return t("country");
      case "states":
        return t("state");
      case "cities":
        return t("city");
      case "areas":
        return t("area");
    }
  };

  const getAllButtonTitle = () => {
    switch (currentView) {
      case "countries":
        return t("allCountries");
      case "states":
        return `All in ${selectedLocation.country?.name}`;
      case "cities":
        return `All in ${selectedLocation.state?.name}`;
      case "areas":
        return `All in ${selectedLocation.city?.name}`;
    }
  };

  const getPlaceholderText = () => {
    switch (currentView) {
      case "countries":
        return `${t("search")} ${t("country")}`;
      case "states":
        return `${t("search")} ${t("state")}`;
      case "cities":
        return `${t("search")} ${t("city")}`;
      case "areas":
        return `${t("search")} ${t("area")}`;
      default:
        return `${t("search")} Location`;
    }
  };

  const getCurrentLocation = () => {
    if (navigator.geolocation) {
      setLocationStatus("fetching");
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          const { latitude, longitude } = position.coords;
          try {
            if (IsPaidApi) {
              const response = await getLocationApi.getLocation({
                lat: latitude,
                lng: longitude,
                lang: "en",
              });
              if (response?.data.error === false) {
                let city = "";
                let state = "";
                let country = "";
                let address = "";
                const results = response?.data?.data?.results;
                results?.forEach((result) => {
                  const addressComponents = result.address_components;
                  const getAddressComponent = (type) => {
                    const component = addressComponents.find((comp) =>
                      comp.types.includes(type)
                    );
                    return component ? component.long_name : "";
                  };
                  if (!city) city = getAddressComponent("locality");
                  if (!state)
                    state = getAddressComponent("administrative_area_level_1");
                  if (!country) country = getAddressComponent("country");
                  if (!address) address = result?.formatted_address;
                });

                const cityData = {
                  lat: latitude,
                  long: longitude,
                  city,
                  state,
                  country,
                  formattedAddress: address,
                };
                setSelectedCity(cityData);
              } else {
                setLocationStatus("error");
                return;
              }
            } else {
              const nominatimResponse = await axios.get(
                "https://nominatim.openstreetmap.org/reverse",
                {
                  params: {
                    format: "json",
                    lat: latitude,
                    lon: longitude,
                    "accept-language": "en",
                    zoom: 10,
                  },
                }
              );
              const data = nominatimResponse.data.address;
              const formattedAddress = [data?.city, data?.state, data?.country].filter(Boolean).join(", ");
              const cityData = {
                lat: latitude,
                long: longitude,
                city: data.city || "",
                state: data.state || "",
                country: data.country || "",
                formattedAddress
              };
              setSelectedCity(cityData);
            }

            setIsMapLocation(true);
            setLocationStatus(null);
          } catch (err) {
            console.error("Error fetching location details:", err);
            setLocationStatus("error");
          }
        },
        (error) => {
          console.error("Geolocation error:", error);
          if (error.code === error.PERMISSION_DENIED) {
            setLocationStatus("denied");
          } else {
            setLocationStatus("error");
          }
        }
      );
    } else {
      toast.error(t("geoLocationNotSupported"));
    }
  };

  return (
    <>
      <div className="location_header_wrapper">
        {currentView !== "countries" && (
          <button className="back_button" onClick={handleBack}>
            <MdArrowBack size={20} />
          </button>
        )}
        <h5 className="head_loc">{getFormattedLocation()}</h5>
      </div>
      <div className="location_search_wrapper">
        <IoSearch className="location_search_icon" />
        {
          currentView === "countries" ?
            <SearchAutocomplete
              search={autoSearch}
              handleSearchChange={handleSearchChange}
              handleInputFocus={handleInputFocus}
              handleInputBlur={handleInputBlur}
              autoState={autoState}
              handleSuggestionClick={handleSuggestionClick}
            />
            :
            <input
              className="location_search_input"
              type="text"
              placeholder={getPlaceholderText()}
              onChange={(e) => setSearch(e.target.value)}
              value={search}
            />
        }
      </div>
      <div className="location_manual_wrapper">
        {currentView === "countries" && (
          <div className="current_location_wrapper">
            <BiCurrentLocation size={22} className="location_search_icon" />
            <button
              className="current_location_text"
              disabled={false}
              onClick={getCurrentLocation}
            >
              <p className="current_location_text_title">
                {t("useCurrentLocation")}
              </p>
              <p className="current_location_text_desc">
                {locationStatus === "fetching"
                  ? t("gettingLocation")
                  : locationStatus === "denied"
                    ? t("locationPermissionDenied")
                    : locationStatus === "error"
                      ? t("error")
                      : t("automaticallyDetectLocation")}
              </p>
            </button>
          </div>
        )}
        <div className="location_places_wrapper">
          <button className="location_places" onClick={handleAllSelect}>
            <p className="places_title">{getAllButtonTitle()}</p>
            <div className="places_arrow">
              <MdOutlineKeyboardArrowRight size={20} />
            </div>
          </button>

          <div className="location_places_list">
            {locationData.isLoading ? (
              <PlacesSkeleton />
            ) : (
              <>
                {locationData.items.length > 0 ? (
                  locationData.items.map((item, index) => (
                    <button
                      className="location_places"
                      key={item?.id}
                      onClick={() => handleItemSelect(item)}
                      ref={
                        index === locationData.items.length - 1 &&
                          locationData.hasMore
                          ? ref
                          : null
                      }
                    >
                      <p className="places_title">{item?.name}</p>
                      <div className="places_arrow">
                        <MdOutlineKeyboardArrowRight size={20} />
                      </div>
                    </button>
                  ))
                ) : (
                  <NoData name={getTitle()} />
                )}
                {locationData.isLoadMore && (
                  <div className="loader-container-otp">
                    <div className="loader-otp"></div>
                  </div>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </>
  );
};

export default LocationSelector;
