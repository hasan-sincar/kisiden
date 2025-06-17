import { settingsData } from '@/redux/reuducer/settingSlice';
import { useSelector } from 'react-redux';
import { MapContainer, Marker, TileLayer, useMapEvents } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { useEffect, useRef } from 'react';

// Fix Leaflet default marker icon issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const MapClickHandler = ({ onMapClick }) => {
    useMapEvents({
        click: (e) => {
            onMapClick(e.latlng);
        },
    });
    return null;
};


const MapComponent = ({ getLocationWithMap, Location }) => {

    const systemSettingsData = useSelector(settingsData)
    const settings = systemSettingsData?.data
    const latitude = Number(settings?.default_latitude)
    const longitude = Number(settings?.default_longitude)
    const mapRef = useRef();
    const position = {
        lat: Number(Location?.lat) || latitude,
        lng: Number(Location?.long) || longitude
    };


    useEffect(() => {
        if (mapRef.current && position.lat && position.lng) {
            mapRef.current.flyTo([position.lat, position.lng], mapRef.current.getZoom());
        }
    }, [position?.lat, position?.lng]);


    const containerStyle = {
        marginTop: "30px",
        width: '100%',
        height: '400px'
    };

    const handleMapClick = (latlng) => {
        if (getLocationWithMap) {
            getLocationWithMap({
                lat: latlng.lat,
                lng: latlng.lng
            });
        }
    };

    return (
        <>
            <MapContainer
                style={containerStyle}
                center={[position?.lat, position?.lng]}
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
                {
                    position?.lat && position?.lng &&
                    <Marker position={[position?.lat, position?.lng]}></Marker>
                }
            </MapContainer>
        </>
    );
};

export default MapComponent;
