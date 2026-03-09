import { useSelector } from "react-redux";
import {
  getDefaultLatitude,
  getDefaultLongitude,
} from "@/redux/reducer/settingSlice";
import { getCityData } from "@/redux/reducer/locationSlice";
import { useEffect, useRef } from "react";
import {
  Circle,
  MapContainer,
  Marker,
  TileLayer,
  useMapEvents,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

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

const MapClickHandler = ({ onMapClick }) => {
  useMapEvents({
    click: (e) => {
      onMapClick(e.latlng);
    },
  });
  return null;
};

const GetLocationWithMap = ({ position, getLocationWithMap, KmRange }) => {
  const latitude = useSelector(getDefaultLatitude);
  const longitude = useSelector(getDefaultLongitude);
  const globalPos = useSelector(getCityData);
  const mapRef = useRef();

  const placeHolderPos = {
    lat: globalPos?.lat,
    lng: globalPos?.long,
  };

  const markerLatLong =
    position?.lat && position?.lng ? position : placeHolderPos;

  useEffect(() => {
    if (mapRef.current && markerLatLong.lat && markerLatLong.lng) {
      mapRef.current.flyTo(
        [markerLatLong.lat, markerLatLong.lng],
        mapRef.current.getZoom()
      );
    }
  }, [markerLatLong?.lat, markerLatLong?.lng]);

  const containerStyle = {
    width: "100%",
    height: "300px",
    borderRadius: "4px",
  };

  const handleMapClick = (latlng) => {
    if (getLocationWithMap) {
      getLocationWithMap({
        lat: latlng.lat,
        lng: latlng.lng,
      });
    }
  };

  return (
    <MapContainer
      style={containerStyle}
      center={[markerLatLong?.lat || latitude, markerLatLong?.lng || longitude]}
      zoom={6}
      ref={mapRef}
      whenCreated={(mapInstance) => {
        mapRef.current = mapInstance;
      }}
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <MapClickHandler onMapClick={handleMapClick} />
      <Marker
        position={[
          markerLatLong?.lat || latitude,
          markerLatLong?.lng || longitude,
        ]}
      ></Marker>
      <Circle
        center={[
          markerLatLong?.lat || latitude,
          markerLatLong?.lng || longitude,
        ]}
        radius={KmRange * 1000} // radius in meters
        pathOptions={{
          color: getComputedStyle(document.documentElement)
            .getPropertyValue("--primary-color")
            .trim(),
          fillColor: getComputedStyle(document.documentElement)
            .getPropertyValue("--primary-color")
            .trim(),
          fillOpacity: 0.2,
        }}
      />
    </MapContainer>
  );
};

export default GetLocationWithMap;
