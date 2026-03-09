import { cn } from "@/lib/utils";
import { setSelectedLocation } from "@/redux/reducer/globalStateSlice";
import { useSearchParams } from "next/navigation";
import { useEffect } from "react";
import { useDispatch } from "react-redux";

const AreaNode = ({ area, city, state, country }) => {
  const dispatch = useDispatch();
  const searchParams = useSearchParams();

  const selectedAreaId = searchParams.get("areaId") || "";

  const isSelected = Number(selectedAreaId) === Number(area.id);

  useEffect(() => {
    if (isSelected) {
      dispatch(setSelectedLocation(area));
    }
  }, [isSelected, area]);

  const handleClick = () => {
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("areaId", area?.id?.toString());
    newSearchParams.set("area", area?.name);
    newSearchParams.set("lat", area?.latitude?.toString());
    newSearchParams.set("lng", area?.longitude?.toString());
    newSearchParams.set("country", country?.name);
    newSearchParams.set("state", state?.name);
    newSearchParams.set("city", city?.name);

    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
  };

  return (
    <li>
      <div className="rounded">
        <button
          onClick={handleClick}
          className={cn(
            "flex-1 ltr:text-left rtl:text-right py-1 px-2 rounded-sm",
            isSelected && "border bg-muted"
          )}
        >
          {area.translated_name || area?.name}
        </button>
      </div>
    </li>
  );
};

export default AreaNode;
