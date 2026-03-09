import { formatDate, t } from "@/utils";
import { BiBadgeCheck } from "react-icons/bi";
import { FaHeart, FaRegHeart } from "react-icons/fa";
import { manageFavouriteApi } from "@/utils/api";
import { useSelector } from "react-redux";
import { userSignUpData } from "@/redux/reducer/authSlice";
import CustomLink from "@/components/Common/CustomLink";
import { toast } from "sonner";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import CustomImage from "./CustomImage";

const ProductCard = ({ item, handleLike }) => {
  const userData = useSelector(userSignUpData);
  const isJobCategory = Number(item?.category?.is_job_category) === 1;
  const translated_item = item.translated_item;

  const isHidePrice = isJobCategory
    ? !item?.formatted_salary_range
    : !item?.formatted_price;

  const price = isJobCategory
    ? item?.formatted_salary_range
    : item?.formatted_price;

  const productLink =
    userData?.id === item?.user_id
      ? `/my-listing/${item?.slug}`
      : `/ad-details/${item.slug}`;

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
      className="border p-2 rounded-2xl flex flex-col gap-2 h-full"
    >
      <div className="relative">
        <CustomImage
          src={item?.image}
          width={288}
          height={249}
          className="w-full aspect-square rounded object-cover"
          alt="Product"
        />
        {item?.is_feature && (
          <div className="flex items-center gap-1 ltr:rounded-tl rtl:rounded-tr py-0.5 px-1 bg-primary absolute top-0 ltr:left-0 rtl:right-0">
            <BiBadgeCheck size={16} color="white" />
            <p className="text-white text-xs sm:text-sm">{t("featured")}</p>
          </div>
        )}

        <div
          onClick={handleLikeItem}
          className="absolute h-10 w-10 ltr:right-2 rtl:left-2 top-2 bg-white p-2 rounded-full flex items-center justify-center text-primary"
        >
          {item?.is_liked ? (
            <button>
              <FaHeart size={24} className="like_icon" />
            </button>
          ) : (
            <button>
              <FaRegHeart size={24} className="like_icon" />
            </button>
          )}
        </div>
      </div>

      <div className="space-between gap-2">
        {isHidePrice ? (
          <p className="text-sm sm:text-base font-medium line-clamp-1">
            {translated_item?.name || item?.name}
          </p>
        ) : (
          <p
            className="text-sm sm:text-lg font-bold break-all text-balance line-clamp-2"
            title={price}
          >
            {price}
          </p>
        )}

        <p className="text-xs sm:text-sm opacity-65 whitespace-nowrap">
          {formatDate(item?.created_at)}&lrm;
        </p>
      </div>

      {!isHidePrice && (
        <p className="text-sm sm:text-base font-medium line-clamp-1">
          {translated_item?.name || item?.name}
        </p>
      )}
      <p className="text-xs sm:text-sm opacity-65 line-clamp-1">
        {item?.translated_address}
      </p>
    </CustomLink>
  );
};

export default ProductCard;
