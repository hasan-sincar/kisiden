import { DialogTitle } from "@radix-ui/react-dialog";
import { DialogFooter, DialogHeader } from "../ui/dialog";
import { t } from "@/utils";
import { MdArrowBack } from "react-icons/md";
import SearchAutocomplete from "./SearchAutocomplete";
import { BiCurrentLocation } from "react-icons/bi";
import { useState } from "react";
import { getMaxRange, getMinRange } from "@/redux/reducer/settingSlice";
import { useDispatch, useSelector } from "react-redux";
import {
  getIsBrowserSupported,
  getKilometerRange,
  resetCityData,
  saveCity,
  setKilometerRange,
} from "@/redux/reducer/locationSlice";
import { Slider } from "../ui/slider";
import dynamic from "next/dynamic";
import { Button } from "../ui/button";
import { toast } from "sonner";
import { usePathname } from "next/navigation";
import { CurrentLanguageData, getIsRtl } from "@/redux/reducer/languageSlice";
import { useNavigate } from "../Common/useNavigate";
import useGetLocation from "../Layout/useGetLocation";

const GetLocationWithMap = dynamic(() => import("./GetLocationWithMap"), {
  ssr: false,
  loading: () => <div className="w-full h-[300px] bg-gray-100 rounded-lg" />,
});

const MapLocation = ({
  OnHide,
  selectedCity,
  setSelectedCity,
  setIsMapLocation,
  IsPaidApi,
}) => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const dispatch = useDispatch();
  const { navigate } = useNavigate();
  const pathname = usePathname();
  const radius = useSelector(getKilometerRange);
  const [KmRange, setKmRange] = useState(radius || 0);
  const [IsFetchingLocation, setIsFetchingLocation] = useState(false);
  const min_range = useSelector(getMinRange);
  const max_range = useSelector(getMaxRange);
  const IsBrowserSupported = useSelector(getIsBrowserSupported);
  const isRTL = useSelector(getIsRtl);
  const { fetchLocationData } = useGetLocation();

  const getCurrentLocation = async () => {
    if (navigator.geolocation) {
      setIsFetchingLocation(true);
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          try {
            const { latitude, longitude } = position.coords;
            const data = await fetchLocationData({ lat: latitude, lng: longitude });
            setSelectedCity(data);
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
      const data = await fetchLocationData(pos);
      setSelectedCity(data);
    } catch (error) {
      console.error("Error fetching location data:", error);
    }
  };

  const handleSave = () => {
    const isInvalidLocation = !selectedCity?.lat || !selectedCity?.long;
    if (isInvalidLocation) {
      toast.error(t("pleaseSelectLocation"));
      return;
    }
    dispatch(setKilometerRange(KmRange));
    saveCity(selectedCity);
    toast.success(t("locationSaved"));
    OnHide();
    // avoid redirect if already on home page otherwise router.push triggering server side api calls
    if (pathname !== "/") {
      navigate("/");
    }
  };

  const handleReset = () => {
    resetCityData();
    min_range > 0
      ? dispatch(setKilometerRange(min_range))
      : dispatch(setKilometerRange(0));
    OnHide();
    // avoid redirect if already on home page otherwise router.push triggering server side api calls
    if (pathname !== "/") {
      navigate("/");
    }
  };

  return (
    <>
      <DialogHeader>
        <DialogTitle className="flex items-center gap-2 font-semibold text-xl">
          {!IsPaidApi && (
            <button onClick={() => setIsMapLocation(false)}>
              <MdArrowBack size={20} className="rtl:scale-x-[-1]" />
            </button>
          )}

          {selectedCity?.address_translated ||
          selectedCity?.formattedAddress ? (
            <p>
              {selectedCity?.address_translated ||
                selectedCity?.formattedAddress}
            </p>
          ) : (
            t("addYourAddress")
          )}
        </DialogTitle>
      </DialogHeader>
      <div className="flex items-center border rounded-md">
        <div className="flex-[3] sm:flex-[2]">
          <SearchAutocomplete
            saveOnSuggestionClick={false}
            OnHide={OnHide}
            setSelectedLocation={setSelectedCity}
          />
        </div>

        {IsBrowserSupported && (
          <>
            <div className="border-r h-full" />
            <button
              className="flex-1 flex items-center justify-center"
              onClick={getCurrentLocation}
            >
              <div className="flex items-center gap-2 py-2 px-4">
                <BiCurrentLocation className="size-5 shrink-0" />
                <span className="text-sm text-balance hidden sm:inline">
                  {IsFetchingLocation
                    ? t("gettingLocation")
                    : t("currentLocation")}
                </span>
              </div>
            </button>
          </>
        )}
      </div>
      <GetLocationWithMap
        KmRange={KmRange}
        position={{ lat: selectedCity?.lat, lng: selectedCity?.long }}
        getLocationWithMap={getLocationWithMap}
      />
      <div className="flex flex-col gap-4">
        <div className="flex items-center gap-2 justify-between">
          <span>{t("rangeLabel")}</span>
          <span>{KmRange} KM</span>
        </div>
        <Slider
          value={[KmRange]}
          onValueChange={(value) => setKmRange(value[0])}
          max={max_range}
          min={min_range}
          step={1}
          dir={isRTL ? "rtl" : "ltr"}
        />
      </div>
      <DialogFooter>
        <Button variant="outline" onClick={handleReset}>
          {t("reset")}
        </Button>
        <Button onClick={handleSave}>{t("save")}</Button>
      </DialogFooter>
    </>
  );
};

export default MapLocation;
