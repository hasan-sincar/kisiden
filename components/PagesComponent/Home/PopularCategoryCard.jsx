import CustomLink from "@/components/Common/CustomLink";
import CustomImage from "@/components/Common/CustomImage";
import { useUpdateLocationInUrl } from "@/components/Common/useUpdateLocationInUrl";

const PopularCategoryCard = ({ item }) => {

  const { generateAdsUrl } = useUpdateLocationInUrl();

  return (
    <CustomLink
      href={generateAdsUrl({ category: item?.slug }, true)}
      className="flex flex-col gap-4"
    >
      <div className="border rounded-full">
        <CustomImage
          src={item?.image}
          width={96}
          height={96}
          className="aspect-square w-full rounded-full object-contain bg-muted"
          alt="Category"
          loading="eager"
        />
      </div>

      <p className="text-sm sm:text-base line-clamp-2 font-medium text-center leading-tight">
        {item?.translated_name}
      </p>
    </CustomLink>
  );
};

export default PopularCategoryCard;
