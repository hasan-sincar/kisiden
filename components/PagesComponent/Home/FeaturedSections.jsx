"use client";
import { t } from "@/utils";
import CustomLink from "@/components/Common/CustomLink";
import ProductCard from "@/components/Common/ProductCard";
import { Fragment } from "react";

const FeaturedSections = ({ featuredData, setFeaturedData, allEmpty }) => {
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

  return (
    featuredData &&
    featuredData.length > 0 &&
    !allEmpty && (
      <section className="container">
        {featuredData.map(
          (ele) =>
            ele?.section_data.length > 0 && (
              <Fragment key={ele?.id}>
                <div className="space-between gap-2 mt-12">
                  <h5 className="text-xl sm:text-2xl font-medium">
                    {ele?.translated_name || ele?.title}
                  </h5>

                  {ele?.section_data.length > 4 && (
                    <CustomLink
                      href={`/ads?featured_section=${ele?.slug}`}
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
              </Fragment>
            )
        )}
      </section>
    )
  );
};

export default FeaturedSections;
