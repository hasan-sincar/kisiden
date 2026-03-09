import { Fragment } from "react";
import { Checkbox } from "../ui/checkbox";
import { Label } from "../ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "../ui/select";
import { t } from "@/utils";
import { Button } from "../ui/button";

const ExtraDetailsFilter = ({
  customFields,
  extraDetails,
  setExtraDetails,
  newSearchParams,
}) => {

  const isApplyDisabled = () => {
    return !Object.values(extraDetails).some(
      (val) => (Array.isArray(val) && val.length > 0) || (!!val && val !== "")
    );
  };

  const handleCheckboxChange = (id, value, checked) => {
    setExtraDetails((prev) => {
      const existing = prev[id] || [];
      const updated = checked
        ? [...existing, value]
        : existing.filter((v) => v !== value);
      return { ...prev, [id]: updated.length ? updated : "" };
    });
  };

  const handleInputChange = (fieldId, value) => {
    setExtraDetails((prev) => ({
      ...prev,
      [fieldId]: value,
    }));
  };

  const handleApply = () => {
    Object.entries(extraDetails).forEach(([key, val]) => {
      if (Array.isArray(val) && val.length) {
        newSearchParams.set(key, val.join(","));
      } else if (val) {
        newSearchParams.set(key, val);
      } else {
        newSearchParams.delete(key);
      }
    });
    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
  };

  return (
    <div className="flex gap-4 flex-col">
      {customFields.map((field) => (
        <Fragment key={field.id}>
          {/* Checkbox */}
          {field.type === "checkbox" && (
            <div className="flex flex-col gap-2">
              <Label className="font-semibold" htmlFor={field.id}>
                {field.translated_name || field.name}
              </Label>
              {field.values.map((option, index) => (
                <div key={option} className="flex items-center gap-2">
                  <Checkbox
                    id={`${field.id}-${option}`}
                    checked={(extraDetails[field.id] || []).includes(option)}
                    onCheckedChange={(checked) =>
                      handleCheckboxChange(field.id, option, checked)
                    }
                  />
                  <label
                    htmlFor={`${field.id}-${option}`}
                    className="text-sm cursor-pointer"
                  >
                    {field?.translated_value[index] || option}
                  </label>
                </div>
              ))}
            </div>
          )}

          {/* Radio */}
          {field.type === "radio" && (
            <div className="flex flex-col gap-2">
              <Label className="font-semibold" htmlFor={field.id}>
                {field.translated_name || field.name}
              </Label>
              <div className="flex gap-2 flex-wrap">
                {field.values.map((option, index) => (
                  <button
                    key={option}
                    type="button"
                    className={`py-2 px-4 w-fit rounded-md border transition-colors ${
                      extraDetails[field.id] === option
                        ? "bg-primary text-white"
                        : ""
                    }`}
                    onClick={() => handleInputChange(field.id, option)}
                    aria-pressed={extraDetails[field.id] === option}
                  >
                    {field?.translated_value[index] || option}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Dropdown */}
          {field.type === "dropdown" && (
            <div className="w-full flex flex-col gap-2">
              <Label className="font-semibold capitalize" htmlFor={field.id}>
                {field.translated_name || field.name}
              </Label>
              <Select
                value={extraDetails[field.id] || ""}
                onValueChange={(val) => handleInputChange(field.id, val)}
              >
                <SelectTrigger>
                  <SelectValue
                    placeholder={`${t("select")} ${
                      field.translated_name || field.name
                    }`}
                  />
                </SelectTrigger>
                <SelectContent>
                  {field.values.map((option, index) => (
                    <SelectItem key={option} value={option}>
                      {field?.translated_value[index] || option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}
        </Fragment>
      ))}

      <Button
        variant="outline"
        className="hover:bg-primary hover:text-white"
        onClick={handleApply}
        disabled={isApplyDisabled()}
      >
        {t("apply")}
      </Button>
    </div>
  );
};

export default ExtraDetailsFilter;
