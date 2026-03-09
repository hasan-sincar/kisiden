import { cn } from "@/lib/utils";
import { BreadcrumbPathData } from "@/redux/reducer/breadCrumbSlice";
import { t } from "@/utils";
import { categoryApi } from "@/utils/api";
import { Loader2, Minus, Plus } from "lucide-react";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { useSelector } from "react-redux";
import { useNavigate } from "../Common/useNavigate";

const CategoryNode = ({ category, extraDetails, setExtraDetails }) => {
  const { navigate } = useNavigate();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [expanded, setExpanded] = useState(false);
  const [subcategories, setSubcategories] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const breadcrumbPath = useSelector(BreadcrumbPathData);

  const selectedSlug = searchParams.get("category") || "";
  const isSelected = category.slug === selectedSlug;

  const shouldExpand = useMemo(() => {
    if (!Array.isArray(breadcrumbPath) || breadcrumbPath.length <= 2)
      return false;
    // Skip the first (All Categories) and last (leaf node)
    const keysToCheck = breadcrumbPath.slice(1, -1).map((crumb) => crumb.key);
    return keysToCheck.includes(category.slug);
  }, []);

  // 📦 Auto-expand if it's in the path
  useEffect(() => {
    if (shouldExpand && !expanded) {
      // If not already expanded and part of the path, expand and load children
      setExpanded(true);
      fetchSubcategories();
    }
  }, [shouldExpand]);
  const fetchSubcategories = async (page = 1, append = false) => {
    setIsLoading(true);
    try {
      const response = await categoryApi.getCategory({
        category_id: category.id,
        page,
      });
      const data = response.data.data.data;
      const hasMore =
        response.data.data.last_page > response.data.data.current_page;
      setSubcategories((prev) => (append ? [...prev, ...data] : data));
      setHasMore(hasMore);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleExpand = async () => {
    if (!expanded && subcategories.length === 0) {
      await fetchSubcategories();
    }
    setExpanded((prev) => !prev);
  };

  const handleClick = () => {
    const newSearchParams = new URLSearchParams(searchParams);
    newSearchParams.set("category", category.slug);
    Object.keys(extraDetails || {}).forEach((key) => {
      newSearchParams.delete(key);
    });

    setExtraDetails({})

    if (pathname.startsWith("/ads")) {
      window.history.pushState(null, "", `/ads?${newSearchParams.toString()}`);
    } else {
      navigate(`/ads?${newSearchParams.toString()}`);
    }
  };

  const loadMore = async () => {
    const nextPage = page + 1;
    setPage(nextPage);
    await fetchSubcategories(nextPage, true);
  };

  return (
    <li>
      <div className="flex items-center rounded text-sm">
        {category.subcategories_count > 0 &&
          (isLoading ? (
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
          ))}

        <button
          onClick={handleClick}
          className={cn(
            "flex-1 ltr:text-left rtl:text-right py-1 px-2 rounded-sm flex items-center justify-between gap-2",
            isSelected && "border bg-muted"
          )}
        >
          <span className="break-all">{category.translated_name}</span>
          <span>({category.all_items_count})</span>
        </button>
      </div>

      {expanded && (
        <ul className="ltr:ml-3 rtl:mr-3 ltr:border-l rtl:border-r ltr:pl-2 rtl:pr-2 space-y-1">
          {subcategories.map((sub) => (
            <CategoryNode
              key={sub.id + "filter-tree"}
              category={sub}
              selectedSlug={selectedSlug}
              searchParams={searchParams}
              extraDetails={extraDetails}
              setExtraDetails={setExtraDetails}
            />
          ))}

          {hasMore && (
            <button
              onClick={loadMore}
              className="text-primary text-center text-sm py-1 px-2"
            >
              {t("loadMore")}
            </button>
          )}
        </ul>
      )}
    </li>
  );
};

export default CategoryNode;
