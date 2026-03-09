import { cn } from "@/lib/utils";
import { Skeleton } from "@/components/ui/skeleton";
import { t } from "@/utils";
import { getBlogTagsApi } from "@/utils/api";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { useNavigate } from "@/components/Common/useNavigate";

const Tags = ({ tag, langCode }) => {
  const pathname = usePathname();
  const { navigate } = useNavigate();
  const [isLoading, setIsLoading] = useState(false);
  const [blogTags, setBlogTags] = useState([]);

  const isAllTagActive = pathname === "/blogs" && !tag;

  useEffect(() => {
    getBlogTagsData();
  }, [langCode]);

  const getBlogTagsData = async () => {
    try {
      setIsLoading(true);
      const res = await getBlogTagsApi.getBlogs();
      setBlogTags(res?.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleAllTags = () => {
    navigate("/blogs", { scroll: false });
  };

  const handleTagClick = (tagItem) => {
    window.history.pushState(null, "", `/blogs?tag=${tagItem}`);
  };
  return (
    <div className="flex flex-col border rounded-lg ">
      <div className="p-4">
        <p className="font-bold">{t("tags")}</p>
      </div>
      <div className="border-b w-full"></div>
      <div className="p-4 flex flex-wrap gap-2">
        {isLoading ? (
          Array.from({ length: 10 }).map((_, index) => (
            <Skeleton key={index} className="w-20 h-8" />
          ))
        ) : (
          <>
            <button
              className={cn(
                "border px-4 text-sm py-2 rounded-md",
                isAllTagActive && "border-primary text-primary"
              )}
              onClick={handleAllTags}
            >
              {t("all")}
            </button>

            {blogTags?.map((tagItem) => (
              <button
                key={tagItem.value}
                className={cn(
                  "border px-4 text-sm py-2 rounded-md break-all",
                  tag === String(tagItem.value) && "border-primary text-primary"
                )}
                onClick={() => handleTagClick(tagItem.value)}
              >
                {tagItem.label}
              </button>
            ))}
          </>
        )}
      </div>
    </div>
  );
};

export default Tags;
