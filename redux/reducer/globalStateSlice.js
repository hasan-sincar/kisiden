import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";

const initialState = {
  IsLoginModalOpen: false,
  IsVisitedLandingPage: false,
  IsShowBankDetails: false,
  Notification: null,
  IsUnauthorized: false,
  selectedLocation: null,
  // Add blocked users state
  blockedUsersList: [],
  blockedUsersLoading: false,
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
    setSelectedLocation: (state, action) => {
      state.selectedLocation = action.payload;
    },
    // Add blocked users reducers
    setBlockedUsersList: (state, action) => {
      state.blockedUsersList = action.payload;
    },
    setBlockedUsersLoading: (state, action) => {
      state.blockedUsersLoading = action.payload;
    },
    addBlockedUser: (state, action) => {
      const userId = action.payload;
      if (!state.blockedUsersList.some(user => user.id === userId)) {
        state.blockedUsersList.push({ id: userId });
      }
    },
    removeBlockedUser: (state, action) => {
      const userId = action.payload;
      state.blockedUsersList = state.blockedUsersList.filter(user => user.id !== userId);
    },
  },
});

export default globalStateSlice.reducer;
export const {
  setIsLoginModalOpen,
  setIsVisitedLandingPage,
  setIsShowBankDetails,
  setNotification,
  setIsUnauthorized,
  setSelectedLocation,
  // Export blocked users actions
  setBlockedUsersList,
  setBlockedUsersLoading,
  addBlockedUser,
  removeBlockedUser,
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

export const getSelectedLocation = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState.selectedLocation
);

// Add blocked users selectors with fallbacks
export const getBlockedUsersList = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState?.blockedUsersList || []
);

export const getBlockedUsersLoading = createSelector(
  (state) => state.GlobalState,
  (GlobalState) => GlobalState?.blockedUsersLoading || false
);

export const getIsUserBlocked = createSelector(
  [getBlockedUsersList, (state, userId) => userId],
  (blockedUsersList, userId) => {
    if (!blockedUsersList || !Array.isArray(blockedUsersList)) {
      return false;
    }
    return blockedUsersList.some(user => user.id === userId);
  }
);
