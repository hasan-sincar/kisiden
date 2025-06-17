import { Modal } from "antd";
import { MdClose } from "react-icons/md";
import LocationSelector from "./LocationSelector";
import MapLocation from "./MapLocation";
import { useState } from "react";
import { useSelector } from "react-redux";
import { getCityData } from "@/redux/reuducer/locationSlice";

const LocationModal = ({ IsLocationModalOpen, OnHide }) => {

  const [IsMapLocation, setIsMapLocation] = useState(false)
  const cityData = useSelector(getCityData)
  const [selectedCity, setSelectedCity] = useState(cityData || '');

  const CloseIcon = (
    <div className="close_icon_cont">
      <MdClose size={24} color="black" />
    </div>
  );

  return (
    <Modal
      centered
      visible={IsLocationModalOpen}
      closeIcon={CloseIcon}
      className="ant_register_modal loc_modal"
      onCancel={OnHide}
      footer={null}
      maskClosable={false}
    >
      <div className="location_modal">
        {
          IsMapLocation ?
            <MapLocation
              OnHide={OnHide}
              selectedCity={selectedCity}
              setSelectedCity={setSelectedCity}
              setIsMapLocation={setIsMapLocation}
            />
            :
            <LocationSelector
              OnHide={OnHide}
              setSelectedCity={setSelectedCity}
              setIsMapLocation={setIsMapLocation}
              IsMapLocation={IsMapLocation}
            />
        }
      </div>
    </Modal>
  );
};

export default LocationModal;
