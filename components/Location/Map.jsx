"use client";
import { useEffect } from "react";
import L from "leaflet";
import { MapContainer, Marker, TileLayer } from "react-leaflet";
import "leaflet/dist/leaflet.css";

// Fix Leaflet default marker icon issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png",
  iconUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png",
  shadowUrl:
    "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
});

const Map = ({ latitude, longitude }) => {
  const containerStyle = {
    width: "100%",
    height: "200px",
    zIndex: 0,
  };

  // Validate latitude and longitude
  const lat = parseFloat(latitude);
  const lng = parseFloat(longitude);

  // Check if coordinates are valid numbers and within valid ranges
  const isValidLat = !isNaN(lat) && lat >= -90 && lat <= 90;
  const isValidLng = !isNaN(lng) && lng >= -180 && lng <= 180;

  // Use default coordinates if invalid (you can change these to your preferred default location)
  const center = [isValidLat ? lat : 0, isValidLng ? lng : 0];

  // Don't render marker if coordinates are invalid
  const shouldShowMarker = isValidLat && isValidLng;

  useEffect(() => {}, [shouldShowMarker]);

  return (
    shouldShowMarker && (
      <MapContainer
        style={containerStyle}
        center={center}
        zoom={10}
        scrollWheelZoom={false}
        zoomControl={false}
        attributionControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <Marker position={center} />
      </MapContainer>
    )
  );
};

export default Map;
