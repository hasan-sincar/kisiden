import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";

const initialState = {
  cityData: {
    area: "",
    areaId: "",
    city: "",
    state: "",
    country: "",
    lat: "",
    long: "",
    formattedAddress: "",
  },
  KilometerRange: 0,
  IsBrowserSupported: true,
};
export const locationSlice = createSlice({
  name: "Location",
  initialState,
  reducers: {
    setCityData: (location, action) => {
      location.cityData = action.payload.data;
    },
    setIsBrowserSupported: (location, action) => {
      location.IsBrowserSupported = action.payload;
    },
    setKilometerRange: (location, action) => {
      location.KilometerRange = action.payload;
    },
  },
});

export default locationSlice.reducer;
export const { setCityData, setIsBrowserSupported, setKilometerRange } =
  locationSlice.actions;

export const resetCityData = () => {
  const initialCityData = {
    area: "",
    areaId: "",
    city: "",
    state: "",
    country: "",
    lat: "",
    long: "",
    formattedAddress: "",
  };
  store.dispatch(setCityData({ data: initialCityData }));
};

// Action to store location
export const saveCity = (data) => {
  store.dispatch(setCityData({ data }));
};

export const getCityData = createSelector(
  (state) => state.Location,
  (Location) => Location.cityData
);
export const getKilometerRange = createSelector(
  (state) => state.Location,
  (Location) => Number(Location.KilometerRange)
);
export const getIsBrowserSupported = createSelector(
  (state) => state.Location,
  (Location) => Location.IsBrowserSupported
);


export const getCurrentCountry = createSelector(
  (state) => state.Location,
  (Location) => Location.cityData.country
);
