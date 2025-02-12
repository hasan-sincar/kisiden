import { createSelector, createSlice } from "@reduxjs/toolkit";

const initialState = {
    ads: {
        sortBy: 'new-to-old',
        Status: 'all'
    },
    sellerProfile:{
        sortBy:'new-to-old'
    },
    categoryProducts:{
        sortBy: 'new-to-old'
    }
};

export const filterSlice = createSlice({
    name: "Filter",
    initialState,
    reducers: {
        setAdsSortBy: (state, action) => {
            state.ads.sortBy = action.payload;
        },
        setAdsStatus: (state, action) => {
            state.ads.Status = action.payload;
        },
        setSellerSortBy: (state, action) => {
            state.sellerProfile.sortBy = action.payload;
        },
        setCategorySortBy: (state, action) => {
            state.categoryProducts.sortBy = action.payload;
        },
    },
});

export default filterSlice.reducer;
export const { setAdsSortBy, setAdsStatus, setSellerSortBy, setCategorySortBy } = filterSlice.actions;

export const selectSortBy = createSelector(
    (state) => state.Filter.ads.sortBy,
    (sortBy) => sortBy
);

export const selectStatus = createSelector(
    (state) => state.Filter.ads.Status,
    (Status) => Status
);

export const sellerSortBy = createSelector(
    (state) => state.Filter.sellerProfile.sortBy,
    (sortBy) => sortBy
);
export const categorySortBy = createSelector(
    (state) => state.Filter.categoryProducts.sortBy,
    (sortBy) => sortBy
);
