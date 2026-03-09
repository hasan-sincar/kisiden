"use client";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import { setBreadcrumbPath } from "@/redux/reducer/breadCrumbSlice";
import { formatDateMonthYear, t, truncate } from "@/utils";
import { getBlogsApi } from "@/utils/api";
import { useEffect, useState } from "react";
import { FaEye, FaRegCalendarCheck } from "react-icons/fa";
import { useDispatch, useSelector } from "react-redux";
import parse from "html-react-parser";
import {
  FacebookShareButton,
  TwitterShareButton,
  WhatsappShareButton,
} from "react-share";
import { BiLink, BiLogoFacebook, BiLogoWhatsapp } from "react-icons/bi";
import { RiTwitterXLine } from "react-icons/ri";
import { usePathname } from "next/navigation";
import { toast } from "sonner";
import BlogCard from "../LandingPage/BlogCard";
import { Badge } from "@/components/ui/badge";
import Layout from "@/components/Layout/Layout";
import { getCompanyName } from "@/redux/reducer/settingSlice";
import PopularPosts from "../Blogs/PopularPosts";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import NoData from "@/components/EmptyStates/NoData";
import PageLoader from "@/components/Common/PageLoader";
import CustomImage from "@/components/Common/CustomImage";

const BlogDetailPage = ({ slug }) => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const path = usePathname();
  const dispatch = useDispatch();
  const admin = useSelector((state) => state?.Settings?.data?.data?.admin);
  const CompanyName = useSelector(getCompanyName);
  const [blogData, setBlogData] = useState([]);
  const [relatedBlogs, setRelatedBlogs] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const currentUrl = `${process.env.NEXT_PUBLIC_WEB_URL}${path}`;

  const langCode = CurrentLanguage?.code?.toUpperCase();

  useEffect(() => {
    getBlogsData();
  }, [CurrentLanguage.id]);

  const getBlogsData = async () => {
    try {
      setIsLoading(true);
      const res = await getBlogsApi.getBlogs({ slug: slug, views: 1 });
      setBlogData(res?.data?.data?.data[0]);
      const title = res?.data?.data?.data[0]?.title;
      dispatch(
        setBreadcrumbPath([
          {
            name: t("ourBlogs"),
            slug: "/blogs",
          },
          {
            name: truncate(title, 30),
          },
        ])
      );
      setRelatedBlogs(res?.data?.other_blogs);
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopyUrl = async () => {
    try {
      await navigator.clipboard.writeText(currentUrl);
      toast(t("copyToClipboard"));
    } catch (error) {
      console.error("Error copying to clipboard:", error);
    }
  };

  return (
    <Layout>
      <BreadCrumb />
      <div className="container">
        <div className="flex flex-col mt-8 gap-12">
          <div className="grid md:grid-cols-12 grid-col-1 gap-6">
            {isLoading ? (
              <div className="col-span-1 md:col-span-8">
                <PageLoader />
              </div>
            ) : blogData ? (
              <div className="col-span-1 md:col-span-8 flex flex-col gap-8">
                <h1 className="text-3xl font-medium">
                  {blogData?.translated_title || blogData?.title}
                </h1>
                <div className="flex items-center flex-wrap gap-2 opacity-60 text-sm">
                  <div className="flex gap-2 items-center">
                    <CustomImage
                      src={admin?.profile}
                      alt={admin?.name || "Admin Image"}
                      height={28}
                      width={28}
                      className="size-7 aspect-square rounded-md"
                    />
                    <p>{admin?.name}</p>
                  </div>
                  <div className="border-r h-[16px]"></div>
                  <div className="flex items-center gap-1">
                    <FaEye size={16} />
                    {t("views")}: {blogData?.views}
                  </div>
                  <div className="border-r h-[16px] "></div>
                  <div className="flex gap-2 items-center">
                    <FaRegCalendarCheck size={16} color="" />
                    {t("postedOn")}: {formatDateMonthYear(blogData?.created_at)}
                  </div>
                </div>
                <CustomImage
                  src={blogData?.image}
                  alt={blogData?.title || "Blog Image"}
                  height={838}
                  width={500}
                  className="w-full h-auto aspect-[838/500] rounded-lg"
                />
                <div className="max-w-full prose lg:prose-lg">
                  {parse(
                    blogData?.translated_description ||
                      blogData?.description ||
                      ""
                  )}
                </div>
                <div className="border-t pt-4 flex items-center justify-between ">
                  <div className="flex flex-col gap-2 opacity-60">
                    <span className="pb-2 font-sm ">{t("shareThis")}</span>
                    <div className="flex gap-3">
                      <button className="border-none" onClick={handleCopyUrl}>
                        <BiLink size={24} />
                      </button>
                      <FacebookShareButton
                        url={currentUrl}
                        title={currentUrl + CompanyName}
                        hashtag={CompanyName}
                      >
                        <BiLogoFacebook size={24} />
                      </FacebookShareButton>
                      <TwitterShareButton url={currentUrl}>
                        <RiTwitterXLine size={24} />
                      </TwitterShareButton>
                      <WhatsappShareButton
                        url={currentUrl}
                        title={
                          blogData?.translated_title ||
                          blogData?.title + "" + " - " + "" + CompanyName
                        }
                        hashtag={CompanyName}
                      >
                        <BiLogoWhatsapp size={24} />
                      </WhatsappShareButton>
                    </div>
                  </div>
                  <div>
                    {blogData?.translated_tags && (
                      <div className="flex gap-2 items-center flex-wrap justify-end">
                        {blogData?.translated_tags?.map((e) => (
                          <Badge
                            key={e}
                            variant="outline"
                            className="font-normal"
                          >
                            {e}
                          </Badge>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ) : (
              <div className="col-span-1 md:col-span-8">
                <NoData name={t("blog")} />
              </div>
            )}

            <div className="col-span-1 md:col-span-4">
              <PopularPosts langCode={langCode} />
            </div>
          </div>
          <div className="flex gap-8 flex-col">
            <h1 className="text-2xl font-medium">{t("relatedArticle")}</h1>
            <div className="grid md:grid-cols-12 grid-cols-1 gap-4">
              {relatedBlogs &&
                relatedBlogs?.map((blog, index) => (
                  <div className="md:col-span-4 col-span-12" key={index}>
                    <BlogCard blog={blog} />
                  </div>
                ))}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
};
export default BlogDetailPage;
