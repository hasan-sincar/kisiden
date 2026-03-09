import { cn } from "@/lib/utils";
import { getCoutriesApi } from "@/utils/api";
import { Loader2, Minus, Plus } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import { t } from "@/utils";
import CountryNode from "./CountryNode";

const LocationTree = () => {
  const searchParams = useSearchParams();
  const langCode = searchParams.get("lang");

  const selectedCountry = searchParams.get("country") || "";
  const selectedState = searchParams.get("state") || "";
  const selectedCity = searchParams.get("city") || "";
  const selectedArea = searchParams.get("area") || "";
  const isAllSelected =
    !selectedCountry && !selectedState && !selectedCity && !selectedArea;

  const [countries, setCountries] = useState({
    data: [],
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    isLoadMore: false,
    expanded: false,
  });

  useEffect(() => {
    fetchCountries();
  }, [langCode]);

  const fetchCountries = async (page = 1) => {
    try {
      page > 1
        ? setCountries((prev) => ({ ...prev, isLoadMore: true }))
        : setCountries((prev) => ({ ...prev, isLoading: true }));

      const response = await getCoutriesApi.getCoutries({ page });
      const newData = response?.data?.data?.data ?? [];
      const currentPage = response?.data?.data?.current_page;
      const lastPage = response?.data?.data?.last_page;

      setCountries((prev) => ({
        ...prev,
        data: page > 1 ? [...prev.data, ...newData] : newData,
        currentPage,
        hasMore: lastPage > currentPage,
        expanded: true,
      }));


    } catch (error) {
      console.log(error);
    } finally {
      setCountries((prev) => ({
        ...prev,
        isLoading: false,
        isLoadMore: false,
      }));
    }
  };

  const handleToggleExpand = () => {
    setCountries((prev) => ({ ...prev, expanded: !prev.expanded }));
  };

  const handleAllLocationsClick = () => {
    // Clear all location parameters
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.delete("country");
    newSearchParams.delete("state");
    newSearchParams.delete("city");
    newSearchParams.delete("area");
    newSearchParams.delete("lat");
    newSearchParams.delete("lng");
    newSearchParams.delete("km_range");

    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);

  };

  return (
    <ul>
      <li>
        <div className="flex items-center rounded">
          {countries?.isLoading ? (
            <Loader2 className="size-[14px] animate-spin text-muted-foreground" />
          ) : (
            <button
              className="text-sm p-1 hover:bg-muted rounded-sm"
              onClick={handleToggleExpand}
            >
              {countries.expanded ? <Minus size={14} /> : <Plus size={14} />}
            </button>
          )}

          <button
            onClick={handleAllLocationsClick}
            className={cn(
              "flex-1 ltr:text-left rtl:text-right py-1 px-2 rounded-sm",
              isAllSelected && "border bg-muted"
            )}
          >
            {t("allCountries")}
          </button>
        </div>
        {countries.expanded && countries.data.length > 0 && (
          <ul className="ltr:ml-3 rtl:mr-3 ltr:border-l rtl:border-r ltr:pl-2 rtl:pr-2 space-y-1">
            {countries.data.map((country) => (
              <CountryNode key={country.id + langCode} country={country} />
            ))}

            {countries.hasMore && (
              <button
                onClick={() => fetchCountries(countries.currentPage + 1)}
                className="text-primary text-center text-sm py-1 px-2"
                disabled={countries.isLoadMore}
              >
                {countries.isLoadMore ? t("loading") : t("loadMore")}
              </button>
            )}
          </ul>
        )}
      </li>
    </ul>
  );
};

export default LocationTree;
