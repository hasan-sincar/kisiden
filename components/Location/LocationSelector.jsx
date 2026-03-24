import { useEffect, useRef, useState } from "react";
import { t } from "@/utils";
import { MdArrowBack, MdOutlineKeyboardArrowRight } from "react-icons/md";
import { BiCurrentLocation } from "react-icons/bi";
import { DialogHeader, DialogTitle } from "../ui/dialog";
import { cn } from "@/lib/utils";
import { Skeleton } from "../ui/skeleton";
import NoData from "../EmptyStates/NoData";
import { Loader2, SearchIcon } from "lucide-react";
import { useInView } from "react-intersection-observer";
import {
  getAreasApi,
  getCitiesApi,
  getCoutriesApi,
  getStatesApi,
} from "@/utils/api";
import {
  getIsBrowserSupported,
  resetCityData,
  saveCity,
  setKilometerRange,
} from "@/redux/reducer/locationSlice";
import { useDispatch, useSelector } from "react-redux";
import { useDebounce } from "use-debounce";
import SearchAutocomplete from "./SearchAutocomplete";
import useGetLocation from "../Layout/useGetLocation";
import { useUpdateLocationInUrl } from "../Common/useUpdateLocationInUrl";
import { useNavigate } from "../Common/useNavigate";
import { getMinRange } from "@/redux/reducer/settingSlice";
import { usePathname, useSearchParams } from "next/navigation";

const LocationSelector = ({ OnHide, selectedCity, setSelectedCity, setIsMapLocation, shouldSaveToRedux = true }) => {

  const searchParams = useSearchParams();
  const pathname = usePathname();
  const dispatch = useDispatch();
  const { navigate } = useNavigate();
  const { ref, inView } = useInView();
  const IsBrowserSupported = useSelector(getIsBrowserSupported);
  const { updateLocationInUrl } = useUpdateLocationInUrl();
  const minLength = useSelector(getMinRange);

  const viewHistory = useRef([]);
  const skipNextSearchEffect = useRef(false);

  const [search, setSearch] = useState("");
  const [debouncedSearch] = useDebounce(search, 500);
  const [locationStatus, setLocationStatus] = useState(null);
  const [currentView, setCurrentView] = useState("countries");
  const [selectedLocation, setSelectedLocation] = useState({
    country: null,
    state: null,
    city: null,
    area: null,
  });
  const [locationData, setLocationData] = useState({
    items: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: true,
  });

  const { fetchLocationData } = useGetLocation();

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
    // avoid redirect if already on home page otherwise router.push triggering server side api calls
    if (pathname !== "/") {
      navigate("/");
    }
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

          let locationDataToSave = {};

          switch (view) {
            case "states":
              locationDataToSave = {
                city: "",
                state: "",
                country: location.country.name,
                lat: location.country.latitude,
                long: location.country.longitude,
                formattedAddress: location.country.translated_name,
              };
              break;
            case "cities":
              locationDataToSave = {
                city: "",
                state: location.state.name,
                country: location.country.name,
                lat: location.state.latitude,
                long: location.state.longitude,
                formattedAddress: [
                  location?.state.translated_name,
                  location?.country.translated_name,
                ]
                  .filter(Boolean)
                  .join(", "),
              };
              break;
            case "areas":
              locationDataToSave = {
                city: location.city.name,
                state: location.state.name,
                country: location.country.name,
                areaId: location.area?.id || "", // if needed
                lat: location.city.latitude,
                long: location.city.longitude,
                formattedAddress: [
                  location?.city.translated_name,
                  location?.state.translated_name,
                  location?.country.translated_name,
                ]
                  .filter(Boolean)
                  .join(", "),
              };
              break;
          }

          // ✅ Save formattedAddress in redux
          if (shouldSaveToRedux) {
            saveCity(locationDataToSave);
            handleSubmitLocation();
          } else {
            updateLocationInUrl(locationDataToSave);
          }

          // ✅ Update URL (client side, no SSR trigger)
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
        const locationDataToSave = {
          country: selectedLocation.country?.name,
          state: selectedLocation.state?.name,
          city: selectedLocation.city?.name,
          areaId: item?.id,
          area: item?.translated_name,
          lat: item?.latitude,
          long: item?.longitude,
          formattedAddress: [
            item?.translated_name,
            selectedLocation?.city?.translated_name,
            selectedLocation?.state?.translated_name,
            selectedLocation?.country?.translated_name,
          ]
            .filter(Boolean)
            .join(", "),
        };
        if (shouldSaveToRedux) {
          saveCity(locationDataToSave);
          handleSubmitLocation();
        } else {
          updateLocationInUrl(locationDataToSave);
        }
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
        return `${t("search")} ${t("location")}`;
    }
  };

  const getFormattedLocation = () => {

    if (shouldSaveToRedux) {
      if (!selectedLocation) return t("location");
      const parts = [];
      if (selectedLocation.area?.translated_name)
        parts.push(selectedLocation.area.translated_name);
      if (selectedLocation.city?.translated_name)
        parts.push(selectedLocation.city.translated_name);
      if (selectedLocation.state?.translated_name)
        parts.push(selectedLocation.state.translated_name);
      if (selectedLocation.country?.translated_name)
        parts.push(selectedLocation.country.translated_name);

      if (parts.length > 0) return parts.join(", ");

      return selectedCity?.address_translated || selectedCity?.formattedAddress || t("location");
    }
    const location = searchParams.get("location");
    if (location) return location;
    return t("location");
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

  const handleAllSelect = () => {
    let locationDataToSave = null;
    switch (currentView) {
      case "countries":
        // Reset everything
        if (shouldSaveToRedux) {
          resetCityData();
          handleSubmitLocation();
        } else {
          updateLocationInUrl({});
        }
        // Clear location from URL
        OnHide();
        return;
      case "states":
        locationDataToSave = {
          country: selectedLocation?.country?.name,
          formattedAddress: selectedLocation?.country?.translated_name || "",
          lat: selectedLocation?.country?.latitude,
          long: selectedLocation?.country?.longitude,
          // no state, city, areaId
        };
        break;
      case "cities":
        locationDataToSave = {
          country: selectedLocation?.country?.name,
          state: selectedLocation?.state?.name,
          lat: selectedLocation?.state?.latitude,
          long: selectedLocation?.state?.longitude,
          formattedAddress: [
            selectedLocation?.state?.translated_name,
            selectedLocation?.country?.translated_name,
          ]
            .filter(Boolean)
            .join(", ")
          // no city, no areaId
        };
        break;
      case "areas":
        locationDataToSave = {
          country: selectedLocation?.country?.name,
          state: selectedLocation?.state?.name,
          city: selectedLocation?.city?.name,
          // no areaId (because "All Areas")
          lat: selectedLocation?.city?.latitude,
          long: selectedLocation?.city?.longitude,
          formattedAddress: [
            selectedLocation?.city?.translated_name,
            selectedLocation?.state?.translated_name,
            selectedLocation?.country?.translated_name,
          ]
            .filter(Boolean)
            .join(", ")
        };
        break;
    }
    // ✅ Update URL centrally
    // ✅ Save only label in redux
    if (shouldSaveToRedux) {
      saveCity(locationDataToSave);
      handleSubmitLocation();
    } else {
      updateLocationInUrl(locationDataToSave);
    }
    OnHide();
  };

  const getAllButtonTitle = () => {
    switch (currentView) {
      case "countries":
        return t("allCountries");
      case "states":
        return `${t("allIn")} ${selectedLocation.country?.translated_name}`;
      case "cities":
        return `${t("allIn")} ${selectedLocation.state?.translated_name}`;
      case "areas":
        return `${t("allIn")} ${selectedLocation.city?.translated_name}`;
    }
  };

  const getCurrentLocationUsingFreeApi = async (latitude, longitude) => {
    try {
      const data = await fetchLocationData({ lat: latitude, lng: longitude });
      setSelectedCity(data);
      setIsMapLocation(true);
      setLocationStatus(null);
    } catch (error) {
      console.log(error);
      setLocationStatus("error");
    }
  };

  const getCurrentLocation = () => {
    if (navigator.geolocation) {
      setLocationStatus("fetching");
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          const { latitude, longitude } = position.coords;
          await getCurrentLocationUsingFreeApi(latitude, longitude);
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
      <DialogHeader>
        <DialogTitle className="flex items-center gap-2 text-xl ltr:text-left rtl:text-right">
          {currentView !== "countries" && (
            <button onClick={handleBack}>
              <MdArrowBack size={20} className="rtl:scale-x-[-1]" />
            </button>
          )}
          {getFormattedLocation()}
        </DialogTitle>
      </DialogHeader>


      {currentView === "countries" ? (
        <div className="flex items-center gap-2 border rounded-sm relative">
          <SearchAutocomplete saveOnSuggestionClick={true} OnHide={OnHide} shouldSaveToRedux={shouldSaveToRedux} />
        </div>
      ) : (
        <div className="flex items-center gap-2 border rounded-sm relative p-3 ltr:pl-9 rtl:pr-9">
          <SearchIcon className="size-4 shrink-0 absolute left-3 text-muted-foreground" />
          <input
            type="text"
            className="w-full outline-none text-sm"
            placeholder={getPlaceholderText()}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div >
      )}

      {/* Current Location Wrapper */}

      {
        IsBrowserSupported && (
          <div className="flex items-center gap-2 border rounded p-2 px-4">
            <BiCurrentLocation className="text-primary size-5 shrink-0" />
            <button
              className="flex flex-col items-start ltr:text-left rtl:text-right"
              disabled={false}
              onClick={getCurrentLocation}
            >
              <p className="text-sm font-medium text-primary">
                {t("useCurrentLocation")}
              </p>
              <p className="text-xs font-normal m-0 text-gray-500">
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
        )
      }
      <div className="border border-sm rounded-sm">
        <button
          className="flex items-center gap-1 p-3 text-sm font-medium justify-between w-full border-b ltr:text-left rtl:text-right"
          onClick={handleAllSelect}
        >
          <span>{getAllButtonTitle()}</span>
          <div className="bg-muted rounded-sm">
            <MdOutlineKeyboardArrowRight
              size={20}
              className="rtl:scale-x-[-1]"
            />
          </div>
        </button>
        <div className="overflow-y-auto h-[300px]">
          {locationData.isLoading ? (
            <PlacesSkeleton />
          ) : (
            <>
              {locationData.items.length > 0 ? (
                locationData.items.map((item, index) => (
                  <button
                    className={cn(
                      "flex items-center ltr:text-left rtl:text-right gap-1 p-3 text-sm font-medium justify-between w-full",
                      index !== locationData.length - 1 && "border-b"
                    )}
                    onClick={() => handleItemSelect(item)}
                    key={item?.id}
                    ref={
                      index === locationData.items.length - 1 &&
                        locationData.hasMore
                        ? ref
                        : null
                    }
                  >
                    <span>{item?.translated_name || item?.name}</span>
                    <div className="bg-muted rounded-sm">
                      <MdOutlineKeyboardArrowRight
                        size={20}
                        className="rtl:scale-x-[-1]"
                      />
                    </div>
                  </button>
                ))
              ) : (
                <NoData name={getTitle()} />
              )}
              {locationData.isLoadMore && (
                <div className="p-4 flex justify-center">
                  <Loader2 className="size-4 animate-spin" />
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </>
  );
};

export default LocationSelector;

const PlacesSkeleton = () => {
  return (
    <div className="space-y-2">
      {Array.from({ length: 8 }).map((_, index) => (
        <div key={index} className="flex items-center gap-3 p-3">
          <Skeleton className="h-4 w-4 rounded-full" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-[85%]" />
            <Skeleton className="h-3 w-[60%]" />
          </div>
          <Skeleton className="h-5 w-5 rounded-sm" />
        </div>
      ))}
    </div>
  );
};
