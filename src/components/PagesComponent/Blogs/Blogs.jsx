'use client'
import React, { useEffect, useState } from 'react'
import BreadcrumbComponent from '@/components/Breadcrumb/BreadcrumbComponent'
import OurBlogCard from '@/components/Cards/OurBlogCard'
import { t } from '@/utils'
import { getBlogTagsApi, getBlogsApi } from '@/utils/api'
import Tags from '@/components/OurBlogPage/Tags'
import { useSelector } from 'react-redux'
import { searchedTag } from '@/redux/reuducer/searchSlice'
import PopularPosts from '@/components/OurBlogPage/PopularPosts'
import NoData from '@/components/NoDataFound/NoDataFound'
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice'
import OurBlogCardSkeleton from '@/components/Skeleton/OurBlogCardSkeleton'
import BlogTagsSkeleton from '@/components/Skeleton/BlogTagsSkeleton'
import PopularPostsSkeleton from '@/components/Skeleton/PopularPostsSkeleton'

const Blogs = () => {

    const CurrentLanguage = useSelector(CurrentLanguageData)
    const tag = useSelector(searchedTag)
    const [Blogs, setBlogs] = useState([])
    const [blogTags, setBlogTags] = useState([])
    const [populerBlogs, setPopulerBlogs] = useState([])
    const [IsBlogsLoading, setIsBlogsLoading] = useState(true)
    const [IsTagsLoading, setIsTagsLoading] = useState(true)
    const [IsPopularPostLoading, setIsPopularPostLoading] = useState(true)

    const getBlogsData = async () => {
        try {
            const res = await getBlogsApi.getBlogs({
                tag: tag ? tag : ""
            })
            setBlogs(res?.data?.data?.data)

        } catch (error) {
            console.log(error)
        }
        finally {
            setIsBlogsLoading(false)
        }
    }

    useEffect(() => {
        getBlogsData()
    }, [tag])

    const getBlogTagsData = async () => {
        try {
            const res = await getBlogTagsApi.getBlogs({})
            setBlogTags(res?.data?.data)
        } catch (error) {
            console.log(error)
        } finally {
            setIsTagsLoading(false)
        }
    }
    const getPopulerBlogsData = async () => {
        try {
            const res = await getBlogsApi.getBlogs({ sort_by: "new-to-old" })
            setPopulerBlogs(res?.data?.data?.data)
        } catch (error) {
            console.log(error)
        } finally {
            setIsPopularPostLoading(false)
        }
    }

    useEffect(() => {
        getBlogTagsData()
        getPopulerBlogsData()
    }, [])


    return (
        <section className='static_pages'>
            <BreadcrumbComponent title2={t("ourBlogs")} />
            <div className='container'>
                <div className="static_div">
                    <div className="main_title">
                        <span>
                            {t('ourBlogs')}
                        </span>
                    </div>
                    <div className="page_content">
                        <div className="row blog_separator">
                            <div className="col-12 col-md-12 col-lg-9">
                                <div className="row blog_separator">
                                    {
                                        IsBlogsLoading ?
                                            Array.from({ length: 4 }).map((_, index) => (
                                                <div className="col-6 col-lg-6" key={index}>
                                                    <OurBlogCardSkeleton />
                                                </div>
                                            ))
                                            :
                                            Blogs && Blogs?.length > 0 ?
                                                Blogs.map((item, index) => (
                                                    <div className="col-6 col-lg-6" key={index}>
                                                        <OurBlogCard data={item} />
                                                    </div>
                                                )) :
                                                <NoData name={t('blog')} />
                                    }
                                </div>
                            </div>
                            <div className="col-12 col-md-12 col-lg-3">
                                <div className="row blog_separator">
                                    {
                                        IsTagsLoading ?
                                            <BlogTagsSkeleton />
                                            :
                                            blogTags && blogTags?.length > 0 &&
                                            <div className="col-12">
                                                <Tags data={blogTags} />
                                            </div>
                                    }
                                    {
                                        IsPopularPostLoading ?
                                            <div className="col-12">
                                                <PopularPostsSkeleton />
                                            </div>
                                            :
                                            populerBlogs && populerBlogs.length > 0 &&
                                            <div className="col-12">
                                                <PopularPosts data={populerBlogs} />
                                            </div>
                                    }
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    )
}

export default Blogs
