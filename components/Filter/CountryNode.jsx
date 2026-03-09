import { cn } from "@/lib/utils";
import { getStatesApi } from "@/utils/api";
import { Loader2, Minus, Plus } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import StateNode from "./StateNode";
import { t } from "@/utils";
import { setSelectedLocation } from "@/redux/reducer/globalStateSlice";
import { useDispatch } from "react-redux";

const CountryNode = ({ country }) => {
  const dispatch = useDispatch();
  const searchParams = useSearchParams();
  const [states, setStates] = useState({
    data: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: false,
    expanded: false,
  });

  const lat = searchParams.get("lat") || "";
  const lng = searchParams.get("lng") || "";

  const selectedState = searchParams.get("state") || "";
  const selectedCity = searchParams.get("city") || "";
  const selectedArea = searchParams.get("area") || "";
  const selectedCountry = searchParams.get("country") || "";

  const isSelected = useMemo(() => {
    return (
      country?.latitude === lat &&
      country?.longitude === lng &&
      !selectedState &&
      !selectedCity &&
      !selectedArea
    );
  }, [lat, lng]);

  const shouldExpand = selectedCountry === country?.name && selectedState;

  useEffect(() => {
    if (shouldExpand && !states.expanded) {
      fetchStates();
    }
  }, []);

  useEffect(() => {
    if (isSelected) {
      dispatch(setSelectedLocation(country));
    }
  }, [isSelected, country]);

  const fetchStates = async (page = 1) => {
    try {
      page > 1
        ? setStates((prev) => ({ ...prev, isLoadMore: true }))
        : setStates((prev) => ({ ...prev, isLoading: true }));

      const response = await getStatesApi.getStates({
        country_id: country.id,
        page,
      });
      const newData = response?.data?.data?.data ?? [];
      const currentPage = response?.data?.data?.current_page;
      const lastPage = response?.data?.data?.last_page;

      setStates((prev) => ({
        ...prev,
        data: page > 1 ? [...prev.data, ...newData] : newData,
        currentPage,
        hasMore: lastPage > currentPage,
        expanded: true,
      }));
    } catch (error) {
      console.log(error);
    } finally {
      setStates((prev) => ({
        ...prev,
        isLoading: false,
        isLoadMore: false,
      }));
    }
  };

  const handleToggleExpand = async () => {
    if (!states.expanded && states.data.length === 0) {
      await fetchStates();
    } else {
      setStates((prev) => ({ ...prev, expanded: !prev.expanded }));
    }
  };

  const handleClick = () => {
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("country", country?.name);
    newSearchParams.set("lat", country.latitude);
    newSearchParams.set("lng", country.longitude);
    newSearchParams.delete("state");
    newSearchParams.delete("city");
    newSearchParams.delete("area");
    newSearchParams.delete("areaId");
    newSearchParams.delete("km_range");
    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
  };

  const loadMore = async () => {
    await fetchStates(states.currentPage + 1);
  };

  return (
    <li>
      <div className="flex items-center rounded">
        {states?.isLoading ? (
          <Loader2 className="size-[14px] animate-spin text-muted-foreground" />
        ) : (
          country.states_count > 0 && (
            <button
              className="text-sm p-1 hover:bg-muted rounded-sm"
              onClick={handleToggleExpand}
            >
              {states.expanded ? <Minus size={14} /> : <Plus size={14} />}
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
          {country?.translated_name || country?.name}
        </button>
      </div>

      {states.expanded && (
        <ul className="ltr:ml-3 rtl:mr-3 ltr:border-l rtl:border-r ltr:pl-2 rtl:pr-2 space-y-1">
          {states.data.map((state) => (
            <StateNode key={state.id} state={state} country={country} />
          ))}

          {states.hasMore && (
            <button
              onClick={loadMore}
              className="text-primary text-center text-sm py-1 px-2"
              disabled={states.isLoadMore}
            >
              {states.isLoadMore ? t("loading") : t("loadMore")}
            </button>
          )}
        </ul>
      )}
    </li>
  );
};

export default CountryNode;
