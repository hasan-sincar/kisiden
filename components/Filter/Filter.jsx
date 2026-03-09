import FilterTree from "./FilterTree";
import { t } from "@/utils";
import { useSelector } from "react-redux";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import LocationTree from "./LocationTree";
import BudgetFilter from "./BudgetFilter";
import DatePostedFilter from "./DatePostedFilter";
import RangeFilter from "./RangeFilter";
import ExtraDetailsFilter from "./ExtraDetailsFilter";

const Filter = ({
  customFields,
  extraDetails,
  setExtraDetails,
  newSearchParams,
  country,
  state,
  city,
  area,
}) => {
  const langId = useSelector(getCurrentLangCode);
  const isShowCustomfieldFilter =
    customFields &&
    customFields.length > 0 &&
    customFields.some(
      (field) =>
        field.type === "checkbox" ||
        field.type === "radio" ||
        field.type === "dropdown"
    );

  const isLocationSelected = country || state || city || area;

  return (
    <div className="w-full border rounded-lg overflow-hidden">
      <div className="px-4 py-2 font-semibold border-b text-xl">
        {t("filters")}
      </div>
      <div className=" flex flex-col ">
        <Accordion
          type="multiple"
          defaultValue={
            isLocationSelected ? ["location", "category"] : ["category"]
          }
          className="w-full"
        >
          <AccordionItem value="category" className="border-b">
            <AccordionTrigger className="p-4">
              <span className="font-semibold text-base">{t("category")}</span>
            </AccordionTrigger>
            <AccordionContent className="px-4 pb-4">
              <FilterTree key={langId} extraDetails={extraDetails} setExtraDetails={setExtraDetails} />
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="location" className="border-b">
            <AccordionTrigger className="p-4">
              <span className="font-semibold text-base">{t("location")}</span>
            </AccordionTrigger>
            <AccordionContent className="px-4 pb-4">
              <LocationTree />
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="budget" className="border-b">
            <AccordionTrigger className="p-4">
              <span className="font-semibold text-base">{t("budget")}</span>
            </AccordionTrigger>
            <AccordionContent className="px-4 pb-4">
              <BudgetFilter />
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="date-posted" className="border-b">
            <AccordionTrigger className="p-4">
              <span className="font-semibold text-base">{t("datePosted")}</span>
            </AccordionTrigger>
            <AccordionContent className="px-4 pb-4">
              <DatePostedFilter />
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="nearby-range" className="border-b">
            <AccordionTrigger className="p-4">
              <span className="font-semibold text-base">
                {t("nearByKmRange")}
              </span>
            </AccordionTrigger>
            <AccordionContent className="px-4 pb-4">
              <RangeFilter />
            </AccordionContent>
          </AccordionItem>
          {isShowCustomfieldFilter && (
            <AccordionItem value="extra-details">
              <AccordionTrigger className="p-4">
                <span className="font-semibold text-base">
                  {t("extradetails")}
                </span>
              </AccordionTrigger>
              <AccordionContent className="px-4 pb-4">
                <ExtraDetailsFilter
                  customFields={customFields}
                  extraDetails={extraDetails}
                  setExtraDetails={setExtraDetails}
                  newSearchParams={newSearchParams}
                />
              </AccordionContent>
            </AccordionItem>
          )}
        </Accordion>
      </div>
    </div>
  );
};

export default Filter;
