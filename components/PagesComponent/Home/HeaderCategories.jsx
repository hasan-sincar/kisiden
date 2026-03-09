import {
  NavigationMenu,
  NavigationMenuContent,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  NavigationMenuTrigger,
  navigationMenuTriggerStyle,
} from "@/components/ui/navigation-menu";
import { t } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import { useEffect, useRef, useState } from "react";
import { IoIosMore } from "react-icons/io";
import CustomImage from "@/components/Common/CustomImage";
import { useNavigate } from "@/components/Common/useNavigate";
import { usePathname, useSearchParams } from "next/navigation";

const HeaderCategories = ({ cateData }) => {
  const containerRef = useRef(null);
  const measureRef = useRef(null);
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const { navigate } = useNavigate();

  const [fitCategoriesCount, setFitCategoriesCount] = useState(3);

  useEffect(() => {
    const calculateFit = () => {
      if (!containerRef.current || !measureRef.current) return;

      const containerWidth = containerRef.current.offsetWidth;
      const otherWidth = 80; //approx width of other option
      const availableWidth = containerWidth - otherWidth;

      const items = Array.from(measureRef.current.children);
      let totalWidth = 0;
      let visible = 0;

      for (const item of items) {
        const width = item.getBoundingClientRect().width + 48; // padding/gap buffer

        if (totalWidth + width > availableWidth) break;
        totalWidth += width;
        visible++;
      }

      setFitCategoriesCount(visible);
    };

    const resizeObserver = new ResizeObserver(calculateFit);
    if (containerRef.current) {
      resizeObserver.observe(containerRef.current);
    }

    return () => resizeObserver.disconnect();
  }, [cateData]);

  // Helper function to build URL with category while preserving existing search params
  const buildCategoryUrl = (categorySlug) => {
    if (pathname.startsWith("/ads")) {
      // Preserve existing search params and update category
      const newSearchParams = new URLSearchParams(searchParams.toString());
      newSearchParams.delete("lang");
      newSearchParams.set("category", categorySlug);
      return `/ads?${newSearchParams.toString()}`;
    } else {
      // Not on ads page, just add category
      return `/ads?category=${categorySlug}`;
    }
  };

  const handleCategoryClick = (slug) => {
    if (pathname.startsWith("/ads")) {
      const newSearchParams = new URLSearchParams(searchParams.toString());
      newSearchParams.set("category", slug);
      const newUrl = `/ads?${newSearchParams.toString()}`;
      window.history.pushState(null, "", newUrl);
    } else {
      navigate(`/ads?category=${slug}`);
    }
  };

  const handleOtherCategoryClick = () => {
    if (pathname.startsWith("/ads")) {
      const newSearchParams = new URLSearchParams(searchParams.toString());
      newSearchParams.delete("category");
      const newUrl = `/ads?${newSearchParams.toString()}`;
      window.history.pushState(null, "", newUrl);
    } else {
      navigate(`/ads`);
    }
  };

  return (
    <div className="hidden lg:block py-1.5 border-b">
      <div className="container" ref={containerRef}>
        {/* Hidden measurement row */}
        <div
          ref={measureRef}
          className="absolute opacity-0 pointer-events-none flex"
          style={{ position: "fixed", top: -9999, left: -9999 }}
        >
          {cateData.map((category) => (
            <div key={category.id} className="px-2">
              <span className="whitespace-nowrap font-medium text-sm">
                {category.translated_name}
              </span>
            </div>
          ))}
        </div>

        <NavigationMenu>
          <NavigationMenuList className="rtl:flex-row-reverse">
            {cateData?.slice(0, fitCategoriesCount)?.map((category) => (
              <NavigationMenuItem key={category.id}>
                {category.subcategories_count > 0 ? (
                  <>
                    <NavigationMenuTrigger
                      onClick={() => handleCategoryClick(category.slug)}
                    >
                      {category.translated_name}
                    </NavigationMenuTrigger>
                    <NavigationMenuContent className="rtl:[direction:rtl]">
                      <NavigationMenuLink asChild>
                        <div
                          style={{
                            width: containerRef?.current?.offsetWidth - 32,
                          }}
                          className="flex overflow-x-auto"
                        >
                          <div className="w-[20%] p-4 bg-muted">
                            <div className="flex gap-1">
                              <CustomImage
                                src={category?.image}
                                alt={category?.translated_name}
                                width={22}
                                height={22}
                                className="w-22 h-auto aspect-square"
                              />
                              <p className="font-bold">
                                {category?.translated_name}
                              </p>
                            </div>
                          </div>

                          <div className="w-[80%] p-4">
                            <div className="flex flex-col flex-wrap w-min gap-8 h-[30vh] max-h-[30vh]">
                              {/* <CustomLink
                                href={`/ads?category=${category.slug}`}
                                className="font-semibold whitespace-nowrap text-sm hover:text-primary"
                              >
                                {t("seeAllIn")} {category.translated_name}
                              </CustomLink> */}

                              {category.subcategories.map((subcategory) => (
                                <div key={subcategory.id}>
                                  <CustomLink
                                    href={buildCategoryUrl(subcategory.slug)}
                                    className="font-semibold whitespace-nowrap text-sm hover:text-primary"
                                  >
                                    {subcategory.translated_name}
                                  </CustomLink>

                                  {subcategory.subcategories_count > 0 && (
                                    <ul className="flex flex-col gap-2 mt-2">
                                      {subcategory?.subcategories
                                        ?.slice(0, 5)
                                        .map((nestedSubcategory) => (
                                          <li
                                            key={nestedSubcategory?.id}
                                            className="text-xs"
                                          >
                                            <CustomLink
                                              href={buildCategoryUrl(
                                                nestedSubcategory?.slug
                                              )}
                                              className="hover:text-primary whitespace-nowrap"
                                            >
                                              {
                                                nestedSubcategory?.translated_name
                                              }
                                            </CustomLink>
                                          </li>
                                        ))}
                                      {subcategory.subcategories.length > 5 && (
                                        <li className="text-xs">
                                          <CustomLink
                                            href={buildCategoryUrl(
                                              subcategory.slug
                                            )}
                                            className="hover:text-primary"
                                          >
                                            {t("viewAll")}
                                          </CustomLink>
                                        </li>
                                      )}
                                    </ul>
                                  )}
                                </div>
                              ))}
                            </div>
                          </div>
                        </div>
                      </NavigationMenuLink>
                    </NavigationMenuContent>
                  </>
                ) : (
                  <NavigationMenuLink
                    className={navigationMenuTriggerStyle()}
                    href={buildCategoryUrl(category?.slug)}
                    asChild
                  >
                    <CustomLink href={buildCategoryUrl(category?.slug)}>
                      {category.translated_name}
                    </CustomLink>
                  </NavigationMenuLink>
                )}
              </NavigationMenuItem>
            ))}
            {cateData && cateData.length > fitCategoriesCount && (
              <NavigationMenuItem>
                <NavigationMenuTrigger onClick={handleOtherCategoryClick}>
                  {t("other")}
                </NavigationMenuTrigger>
                <NavigationMenuContent className="rtl:[direction:rtl]">
                  <NavigationMenuLink asChild>
                    <div
                      style={{ width: containerRef?.current?.offsetWidth - 32 }}
                      className="flex overflow-x-auto w-[80vw]"
                    >
                      <div className="w-[20%] p-4 bg-muted">
                        <div className="flex gap-1">
                          <IoIosMore size={22} />
                          <p className="font-bold">{t("other")}</p>
                        </div>
                      </div>

                      <div className="w-[80%] p-4">
                        <div className="flex flex-col flex-wrap w-min gap-8 h-[30vh] max-h-[30vh]">
                          {cateData
                            .slice(fitCategoriesCount)
                            .map((subcategory) => (
                              <div key={subcategory.id}>
                                <CustomLink
                                  href={buildCategoryUrl(subcategory.slug)}
                                  className="font-semibold whitespace-nowrap text-sm hover:text-primary"
                                >
                                  {subcategory.translated_name}
                                </CustomLink>

                                {subcategory.subcategories_count > 0 && (
                                  <ul className="flex flex-col gap-2 mt-2">
                                    {subcategory?.subcategories
                                      ?.slice(0, 5)
                                      .map((nestedSubcategory) => (
                                        <li
                                          key={nestedSubcategory?.id}
                                          className="text-xs"
                                        >
                                          <CustomLink
                                            href={buildCategoryUrl(
                                              nestedSubcategory?.slug
                                            )}
                                            className="hover:text-primary"
                                          >
                                            {nestedSubcategory?.translated_name}
                                          </CustomLink>
                                        </li>
                                      ))}
                                    {subcategory.subcategories.length > 5 && (
                                      <li className="text-xs">
                                        <CustomLink
                                          href={buildCategoryUrl(
                                            subcategory.slug
                                          )}
                                          className="hover:text-primary"
                                        >
                                          {t("viewAll")}
                                        </CustomLink>
                                      </li>
                                    )}
                                  </ul>
                                )}
                              </div>
                            ))}
                        </div>
                      </div>
                    </div>
                  </NavigationMenuLink>
                </NavigationMenuContent>
              </NavigationMenuItem>
            )}
          </NavigationMenuList>
        </NavigationMenu>
      </div>
    </div>
  );
};

export default HeaderCategories;
