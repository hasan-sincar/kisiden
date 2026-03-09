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
    settingsSucess: (settings, action) => {
      const { data } = action.payload;
      settings.data = data;
    },
    getToken: (settings, action) => {
      settings.fcmToken = action.payload.data;
    },
  },
});

export const { settingsSucess, getToken } = settingsSlice.actions;
export default settingsSlice.reducer;

// Action to store token
export const getFcmToken = (data) => {
  store.dispatch(getToken({ data }));
};

// Selectors
export const settingsData = createSelector(
  (state) => state.Settings,
  (settings) => settings.data?.data
);

export const Fcmtoken = createSelector(
  (state) => state.Settings,
  (settings) => settings?.fcmToken
);

export const getIsLandingPage = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.show_landing_page)
);

export const getPlaceholderImage = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.placeholder_image
);

export const getCompanyName = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.company_name
);

export const getIsMaintenanceMode = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.maintenance_mode) === 1
);

export const getIsFreAdListing = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.free_ad_listing) === 1
);

export const getMinRange = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.min_length)
);

export const getMaxRange = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.max_length)
);

export const getIsDemoMode = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.demo_mode
);

export const getOtpServiceProvider = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.otp_service_provider
);

export const getDefaultLatitude = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.default_latitude)
);
export const getDefaultLongitude = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.default_longitude)
);
export const getIsPaidApi = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.map_provider === "google_places"
);

export const getLanguages = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.languages
);

export const getDefaultLanguageCode = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.default_language
);

export const getShowLandingPage = createSelector(
  (state) => state.Settings,
  (settings) => Number(settings?.data?.data?.show_landing_page) === 1
);

export const getCurrencyPosition = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.currency_symbol_position
);

export const getCurrencySymbol = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.currency_symbol
);


export const getCurrencyIsoCode = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.currency_iso_code
);

export const getAboutUs = createSelector(
  (state) => state.Settings,
  (settings) => settings?.data?.data?.about_us
);

