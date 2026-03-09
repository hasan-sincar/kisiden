import { Badge } from "@/components/ui/badge";
import { FaRegLightbulb } from "react-icons/fa";
import { isPdf, t } from "@/utils/index";
import { MdOutlineAttachFile } from "react-icons/md";
import CustomLink from "@/components/Common/CustomLink";
import CustomImage from "@/components/Common/CustomImage";

const ProductFeature = ({ filteredFields }) => {
  return (
    <div className="flex flex-col gap-2 bg-muted rounded-lg">
      <div className="flex flex-col gap-2 p-4">
        <div>
          <Badge className="bg-primary rounded-sm gap-1 text-base  text-white py-2 px-4">
            <FaRegLightbulb />
            {t("highlights")}
          </Badge>
        </div>
        <div className="flex flex-col gap-6 items-start mt-6">
          {filteredFields?.map((feature, index) => {
            return (
              <div className="flex flex-col md:flex-row md:items-center gap-2 md:gap-3 w-full" key={index}>
                <div className="flex items-center gap-2 w-full md:w-1/3">
                  <CustomImage
                    src={feature?.image}
                    alt={feature?.translated_name || feature?.name}
                    height={24}
                    width={24}
                    className="aspect-square size-6"
                  />
                  <p className="text-base font-medium text-wrap">
                    {feature?.translated_name || feature?.name}
                  </p>
                </div>

                <div className="flex items-center gap-2 sm:gap-4 w-full md:w-2/3">
                  <span className="hidden md:inline">:</span>
                  {feature.type === "fileinput" ? (
                    isPdf(feature?.value?.[0]) ? (
                      <div className="flex gap-1 items-center">
                        <MdOutlineAttachFile size={20} />
                        <CustomLink
                          href={feature?.value?.[0]}
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          {t("viewPdf")}
                        </CustomLink>
                      </div>
                    ) : (
                      <CustomLink
                        href={feature?.value}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <CustomImage
                          src={feature?.value}
                          alt="Preview"
                          width={36}
                          height={36}
                        />
                      </CustomLink>
                    )
                  ) : (
                    <p className="text-base text-muted-foreground w-full">
                      {Array.isArray(feature?.translated_selected_values)
                        ? feature?.translated_selected_values.join(", ")
                        : feature?.translated_selected_values}
                    </p>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default ProductFeature;
