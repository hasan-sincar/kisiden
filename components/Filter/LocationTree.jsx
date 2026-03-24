"use client";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import LocationModal from "../Location/LocationModal";
import { t } from "@/utils";
import { GrLocation } from "react-icons/gr";

const LocationTree = () => {
  const searchParams = useSearchParams();
  const [isLocationModalOpen, setIsLocationModalOpen] = useState(false);

  const country = searchParams.get("country");
  const state = searchParams.get("state");
  const city = searchParams.get("city");
  const area = searchParams.get("area");
  const location = searchParams.get("location");

  const locationText = location || [area, city, state, country].filter(Boolean).join(", ") || t("addLocation");

  return (
    <div className="flex flex-col gap-3">
      <div
        className="flex items-center gap-2 p-3 border rounded-md bg-muted/30 cursor-pointer hover:bg-muted transition-colors"
        onClick={() => setIsLocationModalOpen(true)}
      >
        <GrLocation className="text-primary shrink-0" size={18} />
        <span className="text-sm font-medium truncate" title={locationText}>
          {locationText}
        </span>
      </div>

      <LocationModal
        IsLocationModalOpen={isLocationModalOpen}
        setIsLocationModalOpen={setIsLocationModalOpen}
        shouldSaveToRedux={false}
        key={`${isLocationModalOpen}-filter-location-modal`}
      />
    </div>
  );
};

export default LocationTree;
