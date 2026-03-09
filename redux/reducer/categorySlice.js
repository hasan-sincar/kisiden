import { createSelector, createSlice } from "@reduxjs/toolkit";

const initialState = {
  cateData: [],
  catLastPage: 1,
  catCurrentPage: 1,
  isCatLoading: false,
  isCatLoadMore: false,
};

export const categorySlice = createSlice({
  name: "Category",
  initialState,
  reducers: {
    setCateData: (state, action) => {
      state.cateData = action.payload;
    },
    setCatLastPage: (state, action) => {
      state.catLastPage = action.payload;
    },
    setCatCurrentPage: (state, action) => {
      state.catCurrentPage = action.payload;
    },
    setIsCatLoading: (state, action) => {
      state.isCatLoading = action.payload;
    },
    setIsCatLoadMore: (state, action) => {
      state.isCatLoadMore = action.payload;
    },
  },
});

export default categorySlice.reducer;
export const {
  setCateData,
  setCatLastPage,
  setCatCurrentPage,
  setIsCatLoading,
  setIsCatLoadMore,
} = categorySlice.actions;

export const CategoryData = createSelector(
  (state) => state.Category,
  (Category) => Category.cateData
);
export const getCatLastPage = createSelector(
  (state) => state.Category,
  (Category) => Category.catLastPage
);
export const getCatCurrentPage = createSelector(
  (state) => state.Category,
  (Category) => Category.catCurrentPage
);
export const getIsCatLoading = createSelector(
  (state) => state.Category,
  (Category) => Category.isCatLoading
);
export const getIsCatLoadMore = createSelector(
  (state) => state.Category,
  (Category) => Category.isCatLoadMore
);
