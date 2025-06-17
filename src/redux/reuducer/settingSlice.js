import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";

const initialState = {
    data: null,
    lastFetch: null,
    loading: false,
    fcmToken: null,
};

export const settingsSlice = createSlice({
    name: "Settings",
    initialState,
    reducers: {
        settingsRequested: (settings) => {
            settings.loading = true;
        },
        settingsSucess: (settings, action) => {
            let { data } = action.payload;
            settings.data = data;
            settings.loading = false;
            settings.lastFetch = Date.now();
        },
        settingsFailure: (settings) => {
            settings.loading = false;
        },
        getToken: (settings, action) => {
            settings.fcmToken = action.payload.data;
        },

    },
});

export const { settingsRequested, settingsSucess, settingsFailure, getToken } = settingsSlice.actions;
export default settingsSlice.reducer;

// Action to store token 
export const getFcmToken = (data) => {
    store.dispatch(getToken({ data }));
}


// Selectors
export const settingsData = createSelector(
    (state) => state.Settings,
    (settings) => settings.data
);
export const isFreeAdListing = createSelector(
    (state) => state.Settings,
    (settings) => settings?.data?.data?.free_ad_listing
);
export const getMinRange = createSelector(
    (state) => state.Settings,
    (settings) => Number(settings?.data?.data?.min_length)
);
export const getMaxRange = createSelector(
    (state) => state.Settings,
    (settings) => Number(settings?.data?.data?.max_length)
);
export const getIsLandingPage = createSelector(
    (state) => state.Settings,
    (settings) => Number(settings?.data?.data?.show_landing_page)
);

export const Fcmtoken = createSelector(
    state => state.Settings,
    settings => settings?.fcmToken
);

export const getIsPaidApi = createSelector(
    state => state.Settings,
    settings => settings?.data?.data?.map_provider === 'google_places'
);





