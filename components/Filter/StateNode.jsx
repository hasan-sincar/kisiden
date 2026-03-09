import { Loader2, Minus, Plus } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import CityNode from "./CityNode";
import { cn } from "@/lib/utils";
import { getCitiesApi } from "@/utils/api";
import { t } from "@/utils";
import { useDispatch } from "react-redux";
import { setSelectedLocation } from "@/redux/reducer/globalStateSlice";

const StateNode = ({ state, country }) => {
  const dispatch = useDispatch();
  const searchParams = useSearchParams();
  const [cities, setCities] = useState({
    data: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: false,
    expanded: false,
  });

  const selectedCity = searchParams.get("city") || "";
  const selectedArea = searchParams.get("area") || "";
  const selectedState = searchParams.get("state") || "";
  const lat = searchParams.get("lat") || "";
  const lng = searchParams.get("lng") || "";

  const isSelected = useMemo(() => {
    return (
      state?.latitude === lat &&
      state?.longitude === lng &&
      !selectedCity &&
      !selectedArea
    );
  }, [lat, lng]);

  const shouldExpand = selectedState === state?.name && selectedCity;

  useEffect(() => {
    if (shouldExpand && !cities.expanded) {
      fetchCities();
    }
  }, []);

  useEffect(() => {
    if (isSelected) {
      dispatch(setSelectedLocation(state));
    }
  }, [isSelected, state]);

  const fetchCities = async (page = 1) => {
    try {
      page > 1
        ? setCities((prev) => ({ ...prev, isLoadMore: true }))
        : setCities((prev) => ({ ...prev, isLoading: true }));

      const response = await getCitiesApi.getCities({
        state_id: state.id,
        page,
      });
      const newData = response?.data?.data?.data ?? [];
      const currentPage = response?.data?.data?.current_page;
      const lastPage = response?.data?.data?.last_page;

      setCities((prev) => ({
        ...prev,
        data: page > 1 ? [...prev.data, ...newData] : newData,
        currentPage,
        hasMore: lastPage > currentPage,
        expanded: true,
      }));
    } catch (error) {
      console.log(error);
    } finally {
      setCities((prev) => ({
        ...prev,
        isLoading: false,
        isLoadMore: false,
      }));
    }
  };

  const handleToggleExpand = async () => {
    if (!cities.expanded && cities.data.length === 0) {
      await fetchCities();
    } else {
      setCities((prev) => ({ ...prev, expanded: !prev.expanded }));
    }
  };

  const handleClick = () => {
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("country", country?.name);
    newSearchParams.set("state", state?.name);
    newSearchParams.set("lat", state.latitude);
    newSearchParams.set("lng", state.longitude);
    newSearchParams.delete("city");
    newSearchParams.delete("area");
    newSearchParams.delete("areaId");
    newSearchParams.delete("km_range");
    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
  };

  const loadMore = async () => {
    await fetchCities(cities.currentPage + 1);
  };

  return (
    <li>
      <div className="flex items-center rounded">
        {cities?.isLoading ? (
          <Loader2 className="size-[14px] animate-spin text-muted-foreground" />
        ) : (
          state.cities_count > 0 && (
            <button
              className="text-sm p-1 hover:bg-muted rounded-sm"
              onClick={handleToggleExpand}
            >
              {cities.expanded ? <Minus size={14} /> : <Plus size={14} />}
            </button>
          )
        )}

        <button
          onClick={handleClick}
          className={cn(
            "flex-1 ltr:text-left rtl:text-right py-1 px-2 rounded-sm",
            isSelected && "border bg-muted"
          )}
        >
          {state?.translated_name || state?.name}
        </button>
      </div>

      {cities.expanded && (
        <ul className="ltr:ml-3 rtl:mr-3 ltr:border-l rtl:border-r ltr:pl-2 rtl:pr-2 space-y-1">
          {cities.data.map((city) => (
            <CityNode
              key={city.id}
              city={city}
              country={country}
              state={state}
            />
          ))}

          {cities.hasMore && (
            <button
              onClick={loadMore}
              className="text-primary text-center text-sm py-1 px-2"
              disabled={cities.isLoadMore}
            >
              {cities.isLoadMore ? t("loading") : t("loadMore")}
            </button>
          )}
        </ul>
      )}
    </li>
  );
};

export default StateNode;
