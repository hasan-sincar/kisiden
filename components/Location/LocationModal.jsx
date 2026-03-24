"use client";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { getCityData } from "@/redux/reducer/locationSlice";
import { useState } from "react";
import { useSelector } from "react-redux";
import LocationSelector from "./LocationSelector";
import MapLocation from "./MapLocation";
import { getIsPaidApi } from "@/redux/reducer/settingSlice";
import { useUpdateLocationInUrl } from "../Common/useUpdateLocationInUrl";
import { useMemo } from "react";

const LocationModal = ({ IsLocationModalOpen, setIsLocationModalOpen, shouldSaveToRedux = true }) => {
  const { getParamsFromUrl } = useUpdateLocationInUrl();
  const IsPaidApi = useSelector(getIsPaidApi);
  const [IsMapLocation, setIsMapLocation] = useState(IsPaidApi);
  const cityData = useSelector(getCityData);

  const initialCity = useMemo(() => {
    if (!shouldSaveToRedux) {
      const params = getParamsFromUrl();
      if (params.country || params.state || params.city || params.areaId) {
        return {
          lat: params.lat,
          long: params.lng,
          city: params.city,
          state: params.state,
          country: params.country,
          area: params.area,
          areaId: params.areaId,
          formattedAddress: params.location
        };
      }
    }
    return cityData;
  }, [shouldSaveToRedux, cityData]);

  const [selectedCity, setSelectedCity] = useState(initialCity || "");

  return (
    <Dialog open={IsLocationModalOpen} onOpenChange={setIsLocationModalOpen}>
      <DialogContent
        onInteractOutside={(e) => e.preventDefault()}
        className="!gap-6"
      >
        {IsMapLocation ? (
          <MapLocation
            OnHide={() => setIsLocationModalOpen(false)}
            selectedCity={selectedCity}
            setSelectedCity={setSelectedCity}
            setIsMapLocation={setIsMapLocation}
            IsPaidApi={IsPaidApi}
            shouldSaveToRedux={shouldSaveToRedux}
          />
        ) : (
          <LocationSelector
            OnHide={() => setIsLocationModalOpen(false)}
            selectedCity={selectedCity}
            setSelectedCity={setSelectedCity}
            IsMapLocation={IsMapLocation}
            setIsMapLocation={setIsMapLocation}
            shouldSaveToRedux={shouldSaveToRedux}
          />
        )}
      </DialogContent>
    </Dialog>
  );
};

export default LocationModal;
