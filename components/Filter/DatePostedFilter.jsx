import { useSearchParams } from "next/navigation";
import { Checkbox } from "../ui/checkbox";
import { t } from "@/utils";

const DatePostedFilter = () => {
  const searchParams = useSearchParams();
  const value = searchParams.get("date_posted") || "";

  const datesPostedOptions = [
    {
      label: "allTime",
      value: "all-time",
    },
    {
      label: "today",
      value: "today",
    },
    {
      label: "within1Week",
      value: "within-1-week",
    },
    {
      label: "within2Weeks",
      value: "within-2-week",
    },
    {
      label: "within1Month",
      value: "within-1-month",
    },
    {
      label: "within3Months",
      value: "within-3-month",
    },
  ];

  const handleCheckboxChange = (optionValue) => {
    const newSearchParams = new URLSearchParams(searchParams);
    if (value === optionValue) {
      // Uncheck: remove the filter
      newSearchParams.delete("date_posted");
    } else {
      // Check: set the filter
      newSearchParams.set("date_posted", optionValue);
    }
    window.history.pushState(null, '', `/ads?${newSearchParams.toString()}`);
  };

  return (
    <div className="flex flex-col gap-4">
      {datesPostedOptions.map((option) => (
        <div className="flex items-center gap-2" key={option.value}>
          <Checkbox
            checked={value === option.value}
            onCheckedChange={() => handleCheckboxChange(option.value)}
          />
          <label>{t(option.label)}</label>
        </div>
      ))}
    </div>
  );
};

export default DatePostedFilter;
