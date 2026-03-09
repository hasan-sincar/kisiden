import { formatDate, t } from "@/utils";
import { BiBadgeCheck } from "react-icons/bi";
import { FaHeart, FaRegHeart } from "react-icons/fa";
import { manageFavouriteApi } from "@/utils/api";
import { useSelector } from "react-redux";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { toast } from "sonner";
import CustomLink from "@/components/Common/CustomLink";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import CustomImage from "./CustomImage";

const ProductHorizontalCard = ({ item, handleLike }) => {
  const userData = useSelector(userSignUpData);
  const translated_item = item.translated_item;

  const productLink =
    userData?.id === item?.user_id
      ? `/my-listing/${item?.slug}`
      : `/ad-details/${item.slug}`;
  const isJobCategory = Number(item?.category?.is_job_category) === 1;

  const isHidePrice = isJobCategory
    ? !item?.formatted_salary_range
    : !item?.formatted_price;

  const price = isJobCategory
    ? item?.formatted_salary_range
    : item?.formatted_price;

  const handleLikeItem = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      if (!userData) {
        setIsLoginOpen(true);
        return;
      }
      const response = await manageFavouriteApi.manageFavouriteApi({
        item_id: item?.id,
      });
      if (response?.data?.error === false) {
        toast.success(response?.data?.message);
        handleLike(item?.id);
      } else {
        toast.error(t("failedToLike"));
      }
    } catch (error) {
      console.log(error);
      toast.error(t("failedToLike"));
    }
  };

  return (
    <CustomLink
      href={productLink}
      className="border p-2 rounded-md flex items-center gap-2 sm:gap-4 w-full relative"
    >
      <CustomImage
        src={item?.image}
        width={219}
        height={190}
        alt="Product"
        className="w-[100px] sm:w-[219px] h-auto aspect-square sm:aspect-[219/190] rounded object-cover"
      />

      <div
        onClick={handleLikeItem}
        className="absolute h-8 w-8 ltr:right-2 rtl:left-2 top-2 bg-white p-1.5 rounded-full flex items-center justify-center text-primary z-10"
      >
        {item?.is_liked ? (
          <button>
            <FaHeart size={20} className="like_icon" />
          </button>
        ) : (
          <button>
            <FaRegHeart size={20} className="like_icon" />
          </button>
        )}
      </div>

      <div className="flex flex-col gap-1 sm:gap-2 flex-1 relative min-w-0">
        {item?.is_feature && (
          <div className="flex items-center gap-1 rounded-md py-0.5 px-1 bg-primary w-fit mb-1">
            <BiBadgeCheck size={16} color="white" />
            <p className="text-white text-xs sm:text-sm">{t("featured")}</p>
          </div>
        )}

        {!isHidePrice && (
          <p className="text-sm sm:text-lg font-bold truncate" title={price}>
            {price}
          </p>
        )}

        <p
          className="text-xs sm:text-base font-medium line-clamp-1"
          title={translated_item?.name || item?.name}
        >
          {translated_item?.name || item?.name}
        </p>

        <p className="text-xs sm:text-sm opacity-65 line-clamp-1">
          {item?.translated_address}
        </p>

        <div className="flex justify-end mt-auto">
          <p className="text-xs sm:text-sm opacity-65 whitespace-nowrap">
            {formatDate(item?.created_at)}&lrm;
          </p>
        </div>
      </div>
    </CustomLink>
  );
};

export default ProductHorizontalCard;
