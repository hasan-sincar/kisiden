"use client";
import { t } from "@/utils";
import { useState } from "react";
import { BiCurrentLocation } from "react-icons/bi";
import {
  getKilometerRange,
  resetCityData,
  saveCity,
  setKilometerRange,
} from "@/redux/reuducer/locationSlice";
import { useSelector, useDispatch } from "react-redux";
import { Slider } from "antd";
import { getIsPaidApi, getMaxRange, getMinRange } from "@/redux/reuducer/settingSlice";
import { getLocationApi } from "@/utils/api";
import toast from "react-hot-toast";
import dynamic from "next/dynamic";
const LocationWithRadius = dynamic(() =>
  import("../Layout/LocationWithRadius.jsx")
);
import { MdArrowBack } from "react-icons/md";
import { useRouter } from "next/navigation";
import useSearchAutocomplete from "./useSearchAutocomplete.jsx";
import SearchAutocomplete from "./SearchAutocomplete.jsx";
import axios from "axios";
const MapLocation = ({
  OnHide,
  selectedCity,
  setSelectedCity,
  setIsMapLocation,
}) => {
  const dispatch = useDispatch();
  const router = useRouter();
  const radius = useSelector(getKilometerRange);
  const [KmRange, setKmRange] = useState(radius || 0);
  const [IsFetchingLocation, setIsFetchingLocation] = useState(false);
  const min_range = useSelector(getMinRange);
  const max_range = useSelector(getMaxRange);
  const formatter = (value) => `${value}KM`;
  const IsPaidApi = useSelector(getIsPaidApi);
  const saveOnSuggestionClick = false;
  const {
    search: autoSearch,
    setSearch,
    autoState,
    setAutoState,
    handleSearchChange,
    handleInputFocus,
    handleInputBlur,
    handleSuggestionClick,
    isSuggestionClick
  } = useSearchAutocomplete(saveOnSuggestionClick, setSelectedCity, OnHide);


  const handleRange = (range) => {
    setKmRange(range);
  };

  const handleSave = () => {
    const isInvalidLocation =
      KmRange > 0
        ? !selectedCity?.lat || !selectedCity?.long
        : !selectedCity?.areaId && !selectedCity?.city && !selectedCity?.state && !selectedCity?.country;

    if (isInvalidLocation) {
      toast.error(t("pleaseSelectLocation"));
      return;
    }
    dispatch(setKilometerRange(KmRange));
    saveCity(selectedCity);
    toast.success(t("locationSaved"));
    OnHide();
    router.push("/");
  };

  const handleReset = () => {
    resetCityData();
    min_range > 0
      ? dispatch(setKilometerRange(min_range))
      : dispatch(setKilometerRange(0));
    router.push("/");
    OnHide();
  };

  const getCurrentLocation = async () => {
    if (navigator.geolocation) {
      setIsFetchingLocation(true);
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          try {
            const { latitude, longitude } = position.coords;
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
                isSuggestionClick.current = true;
                setSearch(address || [city, state, country].filter(Boolean).join(", "));
                setSelectedCity(cityData);
                setAutoState(prev => ({ ...prev, suggestions: [], show: false }));
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
              isSuggestionClick.current = true;
              setSearch(formattedAddress);
              setSelectedCity(cityData);
              setAutoState(prev => ({ ...prev, suggestions: [], show: false }));
            }
          } catch (error) {
            console.error("Error fetching location data:", error);
            toast.error(t("errorOccurred"));
          } finally {
            setIsFetchingLocation(false);
          }
        },
        (error) => {
          console.log(error);
          toast.error(t("locationNotGranted"));
          setIsFetchingLocation(false);
        }
      );
    } else {
      toast.error(t("geoLocationNotSupported"));
    }
  };

  const getLocationWithMap = async (pos) => {
    try {
      const { lat, lng } = pos;

      const response = await getLocationApi.getLocation({
        lat,
        lng,
        lang: "en",
      });

      if (response?.data.error === false) {
        if (IsPaidApi) {
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
            lat,
            long: lng,
            city,
            state,
            country,
            formattedAddress: address,
          };
          isSuggestionClick.current = true;
          setSearch(address || [city, state, country].filter(Boolean).join(", "));
          setSelectedCity(cityData);
          setAutoState(prev => ({ ...prev, suggestions: [], show: false }));
        } else {
          const results = response?.data?.data;
          const formattedAddress = [results?.area, results?.city, results?.state, results?.country].filter(Boolean).join(", ");
          const cityData = {
            lat: results?.latitude,
            long: results?.longitude,
            city: results?.city || "",
            state: results?.state || "",
            country: results?.country || "",
            area: results?.area || "",
            areaId: results?.area_id || "",
            formattedAddress
          };
          isSuggestionClick.current = true;
          setSearch(formattedAddress);
          setSelectedCity(cityData);
          setAutoState(prev => ({ ...prev, suggestions: [], show: false }));
        }
      } else {
        toast.error(t("errorOccurred"));
      }
    } catch (error) {
      console.error("Error fetching location data:", error);
    }
  };


  return (
    <>
      <div className="location_header_wrapper">
        <button className="back_button" onClick={() => setIsMapLocation(false)}>
          <MdArrowBack size={20} />
        </button>
        <h5 className="head_loc">{t("location")}</h5>
      </div>
      <div className="card">
        <div className="card-body">
          <div className="location_city">
            <div className="row loc_input gx-0">
              <div className="col-8">
                <div style={{ position: "relative" }}>
                  <SearchAutocomplete
                    search={autoSearch}
                    handleSearchChange={handleSearchChange}
                    handleInputFocus={handleInputFocus}
                    handleInputBlur={handleInputBlur}
                    autoState={autoState}
                    handleSuggestionClick={handleSuggestionClick}
                  />
                </div>
              </div>
              <div className="col-4">
                <button
                  className="useCurrentLocation"
                  onClick={getCurrentLocation}
                  disabled={IsFetchingLocation}
                >
                  <BiCurrentLocation size={22} />
                  <span className="curr_loc">
                    {IsFetchingLocation
                      ? t("gettingLocation")
                      : t("currentLocation")}
                  </span>
                </button>
              </div>
            </div>
            <div className="row">
              <div className="col-12">
                <LocationWithRadius
                  KmRange={KmRange}
                  position={{ lat: selectedCity?.lat, lng: selectedCity?.long }}
                  getLocationWithMap={getLocationWithMap}
                />
              </div>
            </div>

            <div className="row">
              <div className="col-12">
                <label htmlFor="range" className="auth_pers_label">
                  {t("range")}
                </label>
                <Slider
                  className="kmRange_slider"
                  value={KmRange}
                  tooltip={{
                    formatter,
                  }}
                  onChange={handleRange}
                  min={min_range}
                  max={max_range}
                />
              </div>
            </div>
          </div>
        </div>
        <div className="card-footer">
          <button className="clear_btn" onClick={handleReset}>
            {t("reset")}
          </button>
          <button className="loc_save_btn" onClick={handleSave}>
            {t("save")}
          </button>
        </div>
      </div>
    </>
  );
};

export default MapLocation;
