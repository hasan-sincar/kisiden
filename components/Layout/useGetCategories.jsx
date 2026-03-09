import { useDispatch, useSelector } from "react-redux";
import {
  CategoryData,
  getCatCurrentPage,
  getCatLastPage,
  getIsCatLoading,
  getIsCatLoadMore,
  setCatCurrentPage,
  setCateData,
  setCatLastPage,
  setIsCatLoading,
  setIsCatLoadMore,
} from "@/redux/reducer/categorySlice";
import { categoryApi } from "@/utils/api"; // assume you have this
import { useCallback } from "react";
import {
  getHasFetchedCategories,
  setHasFetchedCategories,
} from "@/utils/getFetcherStatus";

const useGetCategories = () => {
  const dispatch = useDispatch();
  const cateData = useSelector(CategoryData);
  const isCatLoading = useSelector(getIsCatLoading);
  const isCatLoadMore = useSelector(getIsCatLoadMore);
  const catLastPage = useSelector(getCatLastPage);
  const catCurrentPage = useSelector(getCatCurrentPage);

  const getCategories = useCallback(
    async (page = 1) => {
      if (page === 1 && getHasFetchedCategories()) {
        return;
      }
      if (page === 1) {
        dispatch(setIsCatLoading(true));
      } else {
        dispatch(setIsCatLoadMore(true));
      }
      try {
        const res = await categoryApi.getCategory({ page });
        if (res?.data?.error === false) {
          const data = res?.data?.data?.data;
          if (page === 1) {
            dispatch(setCateData(data));
          } else {
            dispatch(setCateData([...cateData, ...data]));
          }
          dispatch(setCatCurrentPage(res?.data?.data?.current_page));
          dispatch(setCatLastPage(res?.data?.data?.last_page));
          setHasFetchedCategories(true);
        }
      } catch (error) {
        console.log(error);
      } finally {
        dispatch(setIsCatLoading(false));
        dispatch(setIsCatLoadMore(false));
      }
    },
    [cateData, dispatch]
  );

  return {
    getCategories,
    isCatLoading,
    cateData,
    isCatLoadMore,
    catLastPage,
    catCurrentPage,
  };
};

export default useGetCategories;
