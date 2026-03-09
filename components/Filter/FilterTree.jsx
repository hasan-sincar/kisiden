import { cn } from "@/lib/utils";
import { Loader2, Minus, Plus } from "lucide-react";
import { usePathname, useSearchParams } from "next/navigation";
import { t } from "@/utils";
import CategoryNode from "./CategoryNode";
import { useState } from "react";
import { useNavigate } from "../Common/useNavigate";
import useGetCategories from "../Layout/useGetCategories";

const FilterTree = ({ extraDetails, setExtraDetails }) => {
  const { navigate } = useNavigate();
  const searchParams = useSearchParams();
  const pathname = usePathname();

  const {
    getCategories,
    cateData,
    isCatLoading,
    isCatLoadMore,
    catCurrentPage,
    catLastPage,
  } = useGetCategories();
  const hasMore = catCurrentPage < catLastPage;

  const selectedSlug = searchParams.get("category") || "";
  const isSelected = !selectedSlug; // "All" category is selected when no category is selected

  const [expanded, setExpanded] = useState(true);

  const handleToggleExpand = () => {
    setExpanded((prev) => !prev);
  };

  const handleClick = () => {
    const params = new URLSearchParams(searchParams);
    params.delete("category");
    Object.keys(extraDetails || {})?.forEach((key) => {
      params.delete(key);
    });

    setExtraDetails({})

    if (pathname.startsWith("/ads")) {
      window.history.pushState(null, "", `/ads?${params.toString()}`);
    } else {
      navigate(`/ads?${params.toString()}`);
    }
  };

  return (
    <ul>
      <li>
        <div className="flex items-center rounded text-sm">
          {isCatLoading ? (
            <div className="p-1">
              <Loader2 className="size-[14px] animate-spin text-muted-foreground" />
            </div>
          ) : (
            <button
              className="text-sm p-1 hover:bg-muted rounded-sm"
              onClick={handleToggleExpand}
            >
              {expanded ? <Minus size={14} /> : <Plus size={14} />}
            </button>
          )}

          <button
            onClick={handleClick}
            className={cn(
              "flex-1 ltr:text-left rtl:text-right py-1 px-2 rounded-sm",
              isSelected && "border bg-muted"
            )}
          >
            {t("allCategories")}
          </button>
        </div>
        {expanded && cateData.length > 0 && (
          <ul className="ltr:ml-3 rtl:mr-3 ltr:border-l rtl:border-r ltr:pl-2 rtl:pr-2 space-y-1">
            {cateData.map((category) => (
              <CategoryNode
                key={category.id + "filter-tree"}
                category={category}
                extraDetails={extraDetails}
                setExtraDetails={setExtraDetails}
              />
            ))}

            {hasMore && (
              <button
                onClick={() => getCategories(catCurrentPage + 1)}
                className="text-primary text-center text-sm py-1 px-2"
                disabled={isCatLoadMore}
              >
                {isCatLoadMore ? t("loading") : t("loadMore")}
              </button>
            )}
          </ul>
        )}
      </li>
    </ul>
  );
};

export default FilterTree;
