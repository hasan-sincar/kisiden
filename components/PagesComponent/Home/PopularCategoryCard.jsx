import CustomLink from "@/components/Common/CustomLink";
import CustomImage from "@/components/Common/CustomImage";

const PopularCategoryCard = ({ item }) => {
  return (
    <CustomLink
      href={`/ads?category=${item?.slug}`}
      className="flex flex-col gap-4"
    >
      <div className="border p-2.5 rounded-full">
        <CustomImage
          src={item?.image}
          width={96}
          height={96}
          className="aspect-square w-full rounded-full"
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
