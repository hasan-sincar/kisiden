import { useState } from "react";
import { Slider } from "../ui/slider";
import { useSelector } from "react-redux";
import { getMaxRange, getMinRange } from "@/redux/reducer/settingSlice";
import { t } from "@/utils";
import { Button } from "../ui/button";
import { useSearchParams } from "next/navigation";
import { getIsRtl } from "@/redux/reducer/languageSlice";

const RangeFilter = () => {
  const searchParams = useSearchParams();
  const isRTL = useSelector(getIsRtl);

  const kmRange = searchParams.get("km_range");
  const areaId = searchParams.get("areaId");
  const lat = searchParams.get("lat");
  const lng = searchParams.get("lng");

  const min = useSelector(getMinRange);
  const max = useSelector(getMaxRange);

  const [value, setValue] = useState([kmRange || min]);
  const [error, setError] = useState("");

  const handleRangeApply = () => {
    if (!areaId) {
      setError(t("pleaseSelectArea"));
      return;
    }

    const isInvalidCoord = (value) =>
      value === null ||
      value === undefined ||
      value === "" ||
      isNaN(Number(value));

    if (isInvalidCoord(lat) || isInvalidCoord(lng)) {
      setError(t("InvalidLatOrLng"));
      return;
    }
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("km_range", value);
    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
    setError("");
  };

  return (
    <>
      <div className="flex flex-col gap-4">
        <div className="flex items-center gap-2 justify-between">
          <span>{t("rangeLabel")}</span>
          <span>{value} KM</span>
        </div>
        <div className="flex flex-col gap-2">
          <Slider
            value={value}
            onValueChange={setValue}
            max={max}
            min={min}
            step={1}
            dir={isRTL ? "rtl" : "ltr"}
          />
          {error && <span className="text-sm text-destructive">{error}</span>}
        </div>
        <Button
          className="hover:bg-primary hover:text-white w-full"
          variant="outline"
          onClick={handleRangeApply}
          disabled={value[0] <= 0}
        >
          {t("apply")}
        </Button>
      </div>
    </>
  );
};

export default RangeFilter;
