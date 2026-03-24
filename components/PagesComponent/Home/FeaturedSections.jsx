"use client";
import { t } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import ProductCard from "@/components/Common/ProductCard";
import { Fragment } from "react";
import AdBanner from "@/components/AdSense/AdBanner";
import { useUpdateLocationInUrl } from "@/components/Common/useUpdateLocationInUrl";

const FeaturedSections = ({ featuredData, setFeaturedData, allEmpty }) => {

  const { generateAdsUrl } = useUpdateLocationInUrl();

  const handleLike = (id) => {
    const updatedData = featuredData.map((section) => {
      const updatedSectionData = section.section_data.map((item) => {
        if (item.id === id) {
          return { ...item, is_liked: !item.is_liked };
        }
        return item;
      });
      return { ...section, section_data: updatedSectionData };
    });
    setFeaturedData(updatedData);
  };

  const getFeaturedSectionUrl = (ele) => {
    // Navigating from home, so always take Header Location
    return generateAdsUrl({
      featured_section: ele?.slug
    }, true);
  };

  return (
    featuredData &&
    featuredData.length > 0 &&
    !allEmpty && (
      <section>
        {featuredData.map(
          (ele, index) => {
            const isNotLastSection = index < featuredData.length - 1;
            return (
              <Fragment key={ele?.id}>
                {
                  ele?.section_data.length > 0 &&
                  <>
                    <div className="space-between gap-2 mt-12">
                      <h5 className="text-xl sm:text-2xl font-medium">
                        {ele?.translated_name || ele?.title}
                      </h5>

                      {ele?.section_data.length > 4 && (
                        <CustomLink
                          href={getFeaturedSectionUrl(ele)}
                          className="text-sm sm:text-base font-medium whitespace-nowrap"
                          prefetch={false}
                        >
                          {t("viewAll")}
                        </CustomLink>
                      )}
                    </div>
                    <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 sm:gap-6 mt-6">
                      {ele?.section_data.slice(0, 4).map((data) => (
                        <ProductCard
                          key={data?.id}
                          item={data}
                          handleLike={handleLike}
                        />
                      ))}
                    </div>
                  </>
                }
                {isNotLastSection && (
                  <div className="mt-12 lg:hidden">
                    <AdBanner />
                  </div>
                )}
              </Fragment>
            )
          }
        )}
      </section>
    )
  );
};

export default FeaturedSections;
