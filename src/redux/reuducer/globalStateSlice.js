import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";

const initialState = {
    chatState: {
        chatAudio: {}
    },
    notifications: {}
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
    },
});

export default globalStateSlice.reducer;
export const { setChatAudio, setNotifications } = globalStateSlice.actions;

export const loadChatAudio = (data) => {
    store.dispatch(setChatAudio({ data }));
}

// create selector
export const getGlobalStateData = createSelector(
    (state) => state.GlobalState,
    (GlobalState) => GlobalState
);

export const getGlobalNotifications = createSelector(
    (state) => state.GlobalState,
    (GlobalState) => GlobalState.notifications
);
