import { createSelector, createSlice } from "@reduxjs/toolkit";
import { store } from "../store";  // Ensure this import path is correct

const initialState = {
    data: null,
};

export const authSlice = createSlice({
    name: "UserSignup",
    initialState,
    reducers: {

        updateDataSuccess: (usersignup, action) => {
            usersignup.data = action.payload;
        },
        userUpdateData: (usersignup, action) => {
            usersignup.data.data = action.payload.data;
        },
        userLogout: (usersignup) => {
            usersignup.data = null; // Clear data when user logs out
        },
        decreaseFollowingCount: (state) => {
            if (
                state?.data?.data &&
                typeof state.data.data.following_count === "number" &&
                state.data.data.following_count > 0
            ) {
                state.data.data.following_count -= 1;
            }
        }
    },
});

export const { updateDataSuccess, userUpdateData, userLogout, decreaseFollowingCount } = authSlice.actions;
export default authSlice.reducer;

export const loadUpdateData = (data) => {
    store.dispatch(updateDataSuccess(data));
};
export const loadUpdateUserData = (data) => {
    store.dispatch(userUpdateData({ data }));
};
export const logoutSuccess = () => {
    store.dispatch(userLogout());
};

export const decreaseFollowing = () => {
    store.dispatch(decreaseFollowingCount());
};

export const userSignUpData = createSelector(
    (state) => state.UserSignup,
    (UserSignup) => UserSignup?.data?.data
);

export const getIsLoggedIn = createSelector(
    (state) => state.UserSignup,
    (UserSignup) => UserSignup?.data?.token
);






