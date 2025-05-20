import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";

const initialState = {
    chatState: {
        chatAudio: {}
    },
    notifications: {},
    IsShowBankDetails: false,
    IsLoginModalOpen: false
};

export const globalStateSlice = createSlice({
    name: "GlobalState",
    initialState,
    reducers: {
        setChatAudio: (state, action) => {
            state.chatState.chatAudio = action.payload?.data;
        },
        setNotifications: (state, action) => {
            state.notifications = action.payload;
        },
        setIsShowBankDetails: (state, action) => {
            state.IsShowBankDetails = action.payload;
        },
        setIsLoginModalOpen: (state, action) => {
            state.IsLoginModalOpen = action.payload;
        },
    },
});

export default globalStateSlice.reducer;
export const { setChatAudio, setNotifications, setIsShowBankDetails, setIsLoginModalOpen } = globalStateSlice.actions;

export const loadChatAudio = (data) => {
    store.dispatch(setChatAudio({ data }));
}

export const showBankDetails = () => {
    store.dispatch(setIsShowBankDetails(true));
};

// Function to set IsShowBankDetails to false
export const hideBankDetails = () => {
    store.dispatch(setIsShowBankDetails(false));
};


// Function to set login modal state with any boolean value
export const toggleLoginModal = (isOpen) => {
    store.dispatch(setIsLoginModalOpen(isOpen));
};

// create selector
export const getGlobalStateData = createSelector(
    (state) => state.GlobalState,
    (GlobalState) => GlobalState
);
export const getIsLoginModalOpen = createSelector(
    (state) => state.GlobalState,
    (GlobalState) => GlobalState.IsLoginModalOpen
);

export const getGlobalNotifications = createSelector(
    (state) => state.GlobalState,
    (GlobalState) => GlobalState.notifications
);

export const getIsShowBankDetails = createSelector(
    (state) => state.GlobalState,
    (GlobalState) => GlobalState.IsShowBankDetails
);
