import { Loader2, Minus, Plus } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import AreaNode from "./AreaNode";
import { cn } from "@/lib/utils";
import { getAreasApi } from "@/utils/api";
import { t } from "@/utils";
import { useDispatch } from "react-redux";
import { setSelectedLocation } from "@/redux/reducer/globalStateSlice";

const CityNode = ({ city, country, state }) => {
  const dispatch = useDispatch();
  const searchParams = useSearchParams();
  const [areas, setAreas] = useState({
    data: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: false,
    expanded: false,
  });

  const lat = searchParams.get("lat") || "";
  const lng = searchParams.get("lng") || "";
  const selectedCity = searchParams.get("city") || "";
  const selectedArea = searchParams.get("area") || "";

  const isSelected = useMemo(() => {
    return city?.latitude === lat && city?.longitude === lng && !selectedArea;
  }, [lat, lng]);

  const shouldExpand = selectedCity === city?.name && selectedArea;

  useEffect(() => {
    if (isSelected) {
      dispatch(setSelectedLocation(city));
    }
  }, [isSelected, city]);

  useEffect(() => {
    if (shouldExpand && !areas.expanded) {
      fetchAreas();
    }
  }, []);

  const fetchAreas = async (page = 1) => {
    try {
      page > 1
        ? setAreas((prev) => ({ ...prev, isLoadMore: true }))
        : setAreas((prev) => ({ ...prev, isLoading: true }));

      const response = await getAreasApi.getAreas({
        city_id: city.id,
        page,
      });
      const newData = response?.data?.data?.data ?? [];
      const currentPage = response?.data?.data?.current_page;
      const lastPage = response?.data?.data?.last_page;

      setAreas((prev) => ({
        ...prev,
        data: page > 1 ? [...prev.data, ...newData] : newData,
        currentPage,
        hasMore: lastPage > currentPage,
        expanded: true,
      }));
    } catch (error) {
      console.log(error);
    } finally {
      setAreas((prev) => ({
        ...prev,
        isLoading: false,
        isLoadMore: false,
      }));
    }
  };

  const handleToggleExpand = async () => {
    if (!areas.expanded && areas.data.length === 0) {
      await fetchAreas();
    } else {
      setAreas((prev) => ({ ...prev, expanded: !prev.expanded }));
    }
  };

  const handleClick = () => {
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("country", country?.name);
    newSearchParams.set("state", state?.name);
    newSearchParams.set("city", city?.name);
    newSearchParams.set("lat", city.latitude);
    newSearchParams.set("lng", city.longitude);
    // Always remove unrelated location filters to avoid redundancy
    newSearchParams.delete("area");
    newSearchParams.delete("areaId");
    newSearchParams.delete("km_range");
    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
  };

  const loadMore = async () => {
    await fetchAreas(areas.currentPage + 1);
  };

  return (
    <li>
      <div className="flex items-center rounded">
        {areas?.isLoading ? (
          <Loader2 className="size-[14px] animate-spin text-muted-foreground" />
        ) : (
          city.areas_count > 0 && (
            <button
              className="text-sm p-1 hover:bg-muted rounded-sm"
              onClick={handleToggleExpand}
            >
              {areas.expanded ? <Minus size={14} /> : <Plus size={14} />}
            </button>
          )
        )}

        <button
          onClick={handleClick}
          className={cn(
            "flex-1 ltr:text-left rtl:text-right py-1 px-2 rounded-sm break-all",
            isSelected && "border bg-muted"
          )}
        >
          {city.translated_name || city?.name}
        </button>
      </div>

      {areas.expanded && (
        <ul className="ltr:ml-3 rtl:mr-3 ltr:border-l rtl:border-r ltr:pl-2 rtl:pr-2 space-y-1">
          {areas.data.map((area) => (
            <AreaNode
              key={area.id}
              area={area}
              city={city}
              state={state}
              country={country}
            />
          ))}

          {areas.hasMore && (
            <button
              onClick={loadMore}
              className="text-primary text-center text-sm py-1 px-2"
              disabled={areas.isLoadMore}
            >
              {areas.isLoadMore ? t("loading") : t("loadMore")}
            </button>
          )}
        </ul>
      )}
    </li>
  );
};

export default CityNode;
