"use client";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import { t } from "@/utils";
import { getBlogsApi } from "@/utils/api";
import { useEffect, useState } from "react";
import BlogCardSkeleton from "@/components/Skeletons/BlogCardSkeleton";
import BlogCard from "../LandingPage/BlogCard";
import Layout from "@/components/Layout/Layout";
import { Button } from "@/components/ui/button";
import NoData from "@/components/EmptyStates/NoData";
import Tags from "./Tags";
import { useSearchParams } from "next/navigation";
import { useSelector } from "react-redux";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";

const Blogs = () => {
  const searchParams = useSearchParams();
  const tag = searchParams?.get("tag");
  const langCode = useSelector(getCurrentLangCode);
  const [blogs, setBlogs] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [isLoadMore, setIsLoadMore] = useState(false);
  useEffect(() => {
    getBlogsData(currentPage);
  }, [tag, langCode]);

  const getBlogsData = async (page) => {
    try {
      page > 1 ? setIsLoadMore(true) : setIsLoading(true);
      const res = await getBlogsApi.getBlogs({
        sort_by: "new-to-old",
        page,
        ...(tag && { tag }),
      });

      if (res?.data?.error === false) {
        page === 1
          ? setBlogs(res?.data?.data?.data)
          : setBlogs([...blogs, ...res?.data?.data?.data]);
        setCurrentPage(res?.data?.data?.current_page);
        setHasMore(res?.data?.data?.current_page < res?.data?.data?.last_page);
      } else {
        console.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
      setIsLoadMore(false);
    }
  };

  const handleLoadMore = () => {
    getBlogsData(currentPage + 1);
  };

  return (
    <Layout>
      <BreadCrumb title2={t("ourBlogs")} />
      <div className="container">
        <div className="flex flex-col mt-8 gap-6">
          <h1 className="text-2xl font-medium">{t("ourBlogs")}</h1>
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 lg:gap-4 ">
            <div className="lg:col-span-8 col-span-12 order-2 lg:order-1">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {isLoading ? (
                  Array.from({ length: 6 })?.map((_, index) => (
                    <BlogCardSkeleton key={index} />
                  ))
                ) : blogs && blogs?.length > 0 ? (
                  blogs?.map((blog) => <BlogCard key={blog?.id} blog={blog} />)
                ) : (
                  <div className="col-span-full">
                    <NoData name={t("blog")} />
                  </div>
                )}
              </div>
              {hasMore && (
                <div className="text-center mt-6 mb-2">
                  <Button
                    variant="outline"
                    className="text-sm sm:text-base text-primary w-[256px]"
                    disabled={isLoading || isLoadMore}
                    onClick={handleLoadMore}
                  >
                    {isLoadMore ? t("loading") : t("loadMore")}
                  </Button>
                </div>
              )}
            </div>
            <div className="col-span-12 lg:col-span-4 order-1 lg:order-2">
              <Tags tag={tag} langCode={langCode} />
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default Blogs;
