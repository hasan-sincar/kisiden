import { createSlice } from "@reduxjs/toolkit";


const initialState = {
    BreadcrumbPath: [],
};

export const breadCrumbSlice = createSlice({
    name: "BreadcrumbPath",
    initialState,
    reducers: {
        setBreadcrumbPath: (state, action) => {
            state.BreadcrumbPath = action.payload;
        },
        resetBreadcrumb: () => {
            return initialState
        }
    },
});

export default breadCrumbSlice.reducer;
export const { setBreadcrumbPath, resetBreadcrumb } = breadCrumbSlice.actions;


export const BreadcrumbPathData = (state) => state.BreadcrumbPath.BreadcrumbPath;





