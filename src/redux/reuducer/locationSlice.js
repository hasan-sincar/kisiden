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
        long: ""
    },
    KilometerRange: 0,
    minLength: "",
    maxLength: "",
    IsBrowserSupported: true,
}
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
        setMinLength: (location, action) => {
            location.minLength = action.payload;
        },
        setMaxLength: (location, action) => {
            location.maxLength = action.payload;
        },
    },
});

export default locationSlice.reducer;
export const { setCityData, setIsBrowserSupported, setKilometerRange, setMinLength, setMaxLength } = locationSlice.actions;



// Action to store location 
export const saveCity = (data) => {
    store.dispatch(setCityData({ data }));
}

// Action to reset cityData to initial state
export const resetCityData = () => {
    const initialCityData = {
        city: "",
        state: "",
        country: "",
        lat: "",
        long: ""
    };
    store.dispatch(setCityData({ data: initialCityData }));
}

export const getCityData = createSelector(
    (state) => state.Location,
    (Location) => Location.cityData
)
export const getKilometerRange = createSelector(
    (state) => state.Location,
    (Location) => Location.KilometerRange
)
export const getIsBrowserSupported = createSelector(
    (state) => state.Location,
    (Location) => Location.IsBrowserSupported
)



