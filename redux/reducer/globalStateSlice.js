import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";

const initialState = {
  IsLoginModalOpen: false,
  IsVisitedLandingPage: false,
  IsShowBankDetails: false,
  Notification: null,
  IsUnauthorized: false,
  IsFetchingLanguage: false
};

export const globalStateSlice = createSlice({
  name: "GlobalState",
  initialState,
  reducers: {
    setIsLoginModalOpen: (state, action) => {
      state.IsLoginModalOpen = action.payload;
    },
    setIsVisitedLandingPage: (state, action) => {
      state.IsVisitedLandingPage = action.payload;
    },
    setIsShowBankDetails: (state, action) => {
      state.IsShowBankDetails = action.payload;
    },
    setNotification: (state, action) => {
      state.Notification = action.payload;
    },
    setIsUnauthorized: (state, action) => {
      state.IsUnauthorized = action.payload;
    },
    setIsFetchingLanguage: (state, action) => {
      state.IsFetchingLanguage = action.payload;
    }
  },
});

export default globalStateSlice.reducer;
export const {
  setIsLoginModalOpen,
  setIsVisitedLandingPage,
  setIsShowBankDetails,
  setNotification,
  setIsUnauthorized,
  setIsFetchingLanguage
} = globalStateSlice.actions;

export const getIsVisitedLandingPage = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.IsVisitedLandingPage
);

export const getIsLoginModalOpen = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.IsLoginModalOpen
);

export const getIsShowBankDetails = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.IsShowBankDetails
);

export const setIsLoginOpen = (value) => {
  store.dispatch(setIsLoginModalOpen(value));
};

export const showBankDetails = () => {
  store.dispatch(setIsShowBankDetails(true));
};

export const hideBankDetails = () => {
  store.dispatch(setIsShowBankDetails(false));
};

export const getNotification = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.Notification
);

export const getIsUnauthorized = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.IsUnauthorized
);

export const getIsFetchingLanguage = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.IsFetchingLanguage
);


