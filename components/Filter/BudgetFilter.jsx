import { useState } from "react";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import { t } from "@/utils";
import { useSearchParams } from "next/navigation";

const BudgetFilter = () => {
  const searchParams = useSearchParams();
  const [budget, setBudget] = useState({
    minPrice: searchParams.get("min_price") || "",
    maxPrice: searchParams.get("max_price") || "",
  });

  const { minPrice, maxPrice } = budget;

  const handleMinMaxPrice = () => {
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("min_price", minPrice);
    newSearchParams.set("max_price", maxPrice);
    window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
  };


  return (
    <div className="flex flex-col gap-4 mt-4">
      <form className="flex gap-4">
        <Input
          type="number"
          placeholder={t("from")}
          min={0}
          onChange={(e) =>
            setBudget((prev) => ({ ...prev, minPrice: Number(e.target.value) }))
          }
          value={minPrice}
        />
        <Input
          type="number"
          placeholder={t("to")}
          min={0}
          onChange={(e) =>
            setBudget((prev) => ({ ...prev, maxPrice: Number(e.target.value) }))
          }
          value={maxPrice}
        />
      </form>
      <Button
        type="submit"
        className="hover:bg-primary hover:text-white"
        variant="outline"
        disabled={minPrice == null || maxPrice == null || minPrice >= maxPrice}
        onClick={handleMinMaxPrice}
      >
        {t("apply")}
      </Button>
    </div>
  );
};

export default BudgetFilter;
