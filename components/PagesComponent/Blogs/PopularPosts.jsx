import NoData from "@/components/EmptyStates/NoData";
import { Skeleton } from "@/components/ui/skeleton";
import { t } from "@/utils";
import { getBlogsApi } from "@/utils/api";
import CustomLink from "@/components/Common/CustomLink";
import { useEffect, useState } from "react";
import CustomImage from "@/components/Common/CustomImage";

const PopularPosts = ({ langCode }) => {
  const [isPopularPostLoading, setIsPopularPostLoading] = useState(false);
  const [popularBlogs, setPopulerBlogs] = useState([]);

  useEffect(() => {
    getPopulerBlogsData();
  }, [langCode]);

  const getPopulerBlogsData = async () => {
    setIsPopularPostLoading(true);
    try {
      const res = await getBlogsApi.getBlogs({ sort_by: "popular" });
      setPopulerBlogs(res?.data?.data?.data);
    } catch (error) {
      console.log(error);
    } finally {
      setIsPopularPostLoading(false);
    }
  };

  return (
    <div className="flex flex-col border rounded-xl">
      <div className="p-4 border-b">
        <p className="font-medium">{t("popularPosts")}</p>
      </div>
      <div className="flex flex-col gap-2">
        {isPopularPostLoading ? (
          Array.from({ length: 8 })?.map((_, index) => (
            <PopularPostsSkeleton key={index} />
          ))
        ) : popularBlogs && popularBlogs?.length > 0 ? (
          popularBlogs?.map((popularBlog) => (
            <CustomLink
              key={popularBlog?.id}
              href={`/blogs/${popularBlog?.slug}`}
              className="flex gap-3 px-4 py-2 items-center"
            >
              <CustomImage
                src={popularBlog?.image}
                alt={popularBlog?.title}
                height={48}
                width={64}
                className="aspect-[64/48] rounded object-cover"
              />
              <p className="line-clamp-3 font-medium">
                {popularBlog?.translated_title || popularBlog?.title}
              </p>
            </CustomLink>
          ))
        ) : (
          <div className="col-span-full">
            <NoData name={t("popularPosts")} />
          </div>
        )}
      </div>
    </div>
  );
};

export default PopularPosts;

const PopularPostsSkeleton = () => {
  return (
    <div className="flex gap-3 px-4 py-2 items-center">
      <Skeleton className="h-12 w-16 rounded-lg" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-4 w-3/4" />
        <Skeleton className="h-4 w-1/2" />
      </div>
    </div>
  );
};
