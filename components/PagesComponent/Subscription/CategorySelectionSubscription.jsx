'use client'
import { useEffect, useRef, useState } from "react"
import { MdArrowBack, MdChevronRight } from "react-icons/md"
import { toast } from "sonner"
import CustomImage from "@/components/Common/CustomImage"
import NoData from "@/components/EmptyStates/NoData"
import Layout from "@/components/Layout/Layout"
import { Button } from "@/components/ui/button"
import { t } from "@/utils"
import { categoryApi, getParentCategoriesApi } from "@/utils/api"
import useGetCategories from "@/components/Layout/useGetCategories"
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb"
import { LuPenLine } from "react-icons/lu"
import BuyPackage from "./BuyPackage"
import { getIsFreAdListing } from "@/redux/reducer/settingSlice"
import FreeAdListingPlaceholder from "./FreeAdListingPlaceholder"
import { useLangFromSearchParams } from "@/components/Common/useLangFromSearchParams"
import { getIsLoggedIn } from "@/redux/reducer/authSlice"
import { useSelector } from "react-redux"
import { useSearchParams } from "next/navigation"
import { Globe } from "lucide-react"

const CategorySelectionSubscription = () => {
    const searchParams = useSearchParams();
    const isFeaturedPlan = searchParams.get("plan") === "featured";
    const { cateData, isCatLoading, isCatLoadMore, catLastPage, catCurrentPage } = useGetCategories()
    const isLoggedIn = useSelector(getIsLoggedIn)
    const isFreeAdListing = useSelector(getIsFreAdListing)
    const langCode = useLangFromSearchParams();
    const [categories, setCategories] = useState(cateData || [])
    const [categoriesLoading, setCategoriesLoading] = useState(isCatLoading)
    const [isLoadMoreCat, setIsLoadMoreCat] = useState(isCatLoadMore)
    const [categoryPath, setCategoryPath] = useState([])
    const [currentPage, setCurrentPage] = useState(catCurrentPage)
    const [lastPage, setLastPage] = useState(catLastPage)
    const [selectedCategory, setSelectedCategory] = useState({
        isSelected: false,
        category: null
    })
    const isFirstRender = useRef(true);

    useEffect(() => {
        if (isFirstRender.current) {
            isFirstRender.current = false;
            return;
        }
        setCategoryPath([]);
        setSelectedCategory({ isSelected: false, category: null });
        handleFetchCategories(null, "forward", 1);
    }, [langCode, isLoggedIn]);

    useEffect(() => {
        const categoryId = searchParams.get("category_id");
        if (categoryId) {
            fetchAndSetCategory(categoryId);
        }
    }, []);

    const fetchAndSetCategory = async (id) => {
        try {
            setCategoriesLoading(true);
            const res = await getParentCategoriesApi.getPaymentCategories({
                child_category_id: id,
            });
            if (res?.data?.error === false) {
                const path = res?.data?.data;
                if (path?.length > 0) {
                    if (path.length > 1) {
                        const parentCategory = path[path.length - 2]; // Headphones
                        await handleFetchCategories(parentCategory, "sync", 1);
                    }
                    const category = path[path.length - 1]; // The selected category
                    setSelectedCategory({
                        isSelected: true,
                        category: category
                    });
                    // Set the parent hierarchy so breadcrumbs work
                    setCategoryPath(path.slice(0, -1));
                    // ONLY fetch siblings if we are deep inside a subcategory
                }
            }
        } catch (error) {
            console.log("Error pre-selecting category:", error);
        } finally {
            setCategoriesLoading(false); // 2. Stop loading UI
        }
    }

    /**
     * Handles clicking on category
     */
    const handleCategoryTabClick = (category) => {
        if (category?.subcategories_count > 0) {
            handleFetchCategories(category, "forward")
        } else {
            setSelectedCategory({
                isSelected: true,
                category
            })
        }
    }
    /**
     * Fetch categories
     * navigationType:
     *  - forward
     *  - backward
     */
    const handleFetchCategories = async (
        category = null,
        navigationType = "forward",
        page = 1
    ) => {
        if (page > 1) {
            setIsLoadMoreCat(true);
        } else {
            setCategoriesLoading(true);
        }
        try {
            const categoryId = category ? category.id : null
            const res = await categoryApi.getCategory({
                category_id: categoryId,
                page
            })
            if (res?.data?.error === false) {
                const responseData = res?.data?.data
                page > 1 ? setCategories(prev => [...prev, ...responseData?.data]) : setCategories(responseData?.data || [])
                setCurrentPage(responseData?.current_page)
                setLastPage(responseData?.last_page)
                // Manage path
                if (navigationType === "forward" && page === 1 && category) {
                    setCategoryPath(prev => [...prev, category])
                }

                if (navigationType === "backward") {
                    setCategoryPath(prev => prev.slice(0, -1))
                }
            } else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.log("Category fetch error:", error)
            toast.error("Something went wrong")
        } finally {
            setCategoriesLoading(false)
            setIsLoadMoreCat(false)
        }
    }

    /**
     * Back Button Logic
     */
    const handleBack = () => {
        const previousCategory =
            categoryPath[categoryPath.length - 2] || null

        handleFetchCategories(previousCategory, "backward")
    }


    const handleLoadMore = () => {
        setIsLoadMoreCat(true)
        const currentCategory = categoryPath.length > 0 ? categoryPath[categoryPath.length - 1] : null;
        handleFetchCategories(currentCategory, "forward", currentPage + 1)
    }

    return (
        <Layout>
            <BreadCrumb title2={t("subscription")} />
            {

                isFeaturedPlan ? (
                    <BuyPackage categoryId={null} isFeaturedPlan={isFeaturedPlan} />
                ) : isFreeAdListing ? (
                    <div className="container">
                        <FreeAdListingPlaceholder />
                    </div>
                ) :
                    selectedCategory.isSelected ?
                        <>
                            <div className="container">
                                <h1 className="mt-8 sectionTitle">{t('selectSubscriptionPlan')}</h1>
                                <div className="p-4 border rounded-lg mt-8">
                                    <div className="flex items-center justify-between gap-2" >
                                        <div className="flex items-center gap-2">
                                            <div className="size-[45px] bg-muted flex items-center justify-center rounded-full">
                                                {
                                                    selectedCategory.category ?
                                                        <CustomImage
                                                            width={28}
                                                            height={28}
                                                            src={selectedCategory?.category?.image}
                                                            alt={selectedCategory?.category?.translated_name}
                                                            className="object-contain aspect-square"
                                                        />
                                                        :
                                                        <Globe className="text-primary size-6" />
                                                }
                                            </div>
                                            <p>{selectedCategory.category ? selectedCategory?.category?.translated_name : t("globalPackage")}</p>
                                        </div>
                                        <button onClick={() => setSelectedCategory({ isSelected: false, category: null })}>
                                            <LuPenLine />
                                        </button>
                                    </div>
                                </div>
                            </div>
                            <BuyPackage categoryId={selectedCategory?.category?.id} isFeaturedPlan={isFeaturedPlan} />
                        </>
                        :
                        <div className="container mt-8">
                            <h1 className="sectionTitle">
                                {t('selectACategory')}
                            </h1>
                            <div className="p-4 border mt-8 rounded-md">
                                {
                                    categoryPath?.length > 0 ?
                                        <div className="flex items-center gap-3 mb-6">
                                            <button
                                                onClick={handleBack}
                                                className="flex items-center justify-center p-2 rounded-md hover:bg-muted transition-colors"
                                                aria-label={t("back")}
                                                disabled={categoriesLoading || isLoadMoreCat}
                                            >
                                                <MdArrowBack size={20} className="rtl:scale-x-[-1]" />
                                            </button>
                                            <div className="flex items-center gap-1 text-muted-foreground">
                                                {categoryPath?.map((item, index) => {
                                                    return (
                                                        <span key={item?.id} className="text-primary">
                                                            {index > 0 && ", "}
                                                            {item?.translated_name || item?.name}
                                                        </span>
                                                    );
                                                })}
                                            </div>
                                        </div>
                                        :
                                        <button
                                            className="sm:bg-muted sm:p-3 rounded mb-6 border-primary w-full text-left"
                                            onClick={() => setSelectedCategory({ isSelected: true, category: null })}
                                        >
                                            <div className="flex items-center justify-between gap-3">
                                                <div className="flex items-center gap-3">
                                                    <div className="bg-muted sm:bg-white shrink-0 size-12 rounded-full flex items-center justify-center">
                                                        <Globe className="text-primary size-6" />
                                                    </div>
                                                    <div className="flex flex-col gap-1">
                                                        <h5 className="font-medium">{t('globalPackage')}</h5>
                                                        <p className="text-muted-foreground text-sm">{t('availableForAllCategories')}</p>
                                                    </div>
                                                </div>
                                                <div className="bg-black rounded p-2">
                                                    <MdChevronRight className="size-5 rtl:scale-x-[-1] text-white" />
                                                </div>
                                            </div>
                                        </button>
                                }

                                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">

                                    {categoriesLoading ? (
                                        <div className="col-span-12 py-28">
                                            <Loader />
                                        </div>
                                    ) : categories.length > 0 ? (
                                        categories.map((category) => (
                                            <div key={category?.id}>
                                                <button
                                                    className="flex justify-between items-center w-full"
                                                    onClick={() => handleCategoryTabClick(category)}
                                                >
                                                    <div className="flex items-center gap-2">
                                                        <CustomImage
                                                            src={category?.image}
                                                            alt={category?.translated_name || category?.name}
                                                            height={48}
                                                            width={48}
                                                            className="h-12 w-12 rounded-full"
                                                        />
                                                        <span className="ltr:text-left rtl:text-right break-normal">
                                                            {category?.translated_name || category?.name}
                                                        </span>
                                                    </div>

                                                    {category?.subcategories_count > 0 && (
                                                        <MdChevronRight size={24} className="rtl:scale-x-[-1]" />
                                                    )}
                                                </button>
                                            </div>
                                        ))
                                    ) : (
                                        <div className="col-span-12">
                                            <NoData name={t('category')} />
                                        </div>
                                    )}
                                </div>

                                {/* Load More */}
                                {!categoriesLoading &&
                                    lastPage > currentPage && (
                                        <div className="text-center mt-6">
                                            <Button
                                                variant="outline"
                                                className="text-sm sm:text-base text-primary w-[256px]"
                                                disabled={isLoadMoreCat || categoriesLoading}
                                                onClick={handleLoadMore}
                                            >
                                                {isLoadMoreCat
                                                    ? t("loading")
                                                    : t("loadMore")}
                                            </Button>
                                        </div>
                                    )}
                            </div>
                        </div>
            }
        </Layout>
    )
}

export default CategorySelectionSubscription


const Loader = () => {
    return (
        <div className="flex justify-center">
            <div className="relative w-12 h-12">
                <div className="absolute w-12 h-12 bg-primary rounded-full animate-ping"></div>
                <div className="absolute w-12 h-12 bg-primary rounded-full animate-ping delay-1000"></div>
            </div>
        </div>
    )
}