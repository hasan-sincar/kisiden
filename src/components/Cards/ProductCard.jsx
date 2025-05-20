"use client";
import Image from "next/image";
import { FaRegHeart } from "react-icons/fa";
import {
  formatDate,
  formatPriceAbbreviated,
  placeholderImage,
  t,
} from "@/utils";
import { BiBadgeCheck } from "react-icons/bi";
import { FaHeart } from "react-icons/fa6";
import { manageFavouriteApi } from "@/utils/api";
import toast from "react-hot-toast";
import { userSignUpData } from "../../redux/reuducer/authSlice";
import { useSelector } from "react-redux";
import { toggleLoginModal } from "@/redux/reuducer/globalStateSlice";

const ProductCard = ({ data, handleLike }) => {
  const userData = useSelector(userSignUpData);

  const handleLikeItem = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      if (!userData) {
        toggleLoginModal(true)
        return;
      }
      const response = await manageFavouriteApi.manageFavouriteApi({
        item_id: data?.id,
      });
      if (response?.data?.error === false) {
        toast.success(response?.data?.message);
        handleLike(data?.id);
      } else {
        toast.success(t("failedToLike"));
      }
    } catch (error) {
      console.log(error);
      toast.success(t("failedToLike"));
    }
  };

  return (
    <div className="product_card">
      <div className="position-relative">
        <Image
          src={data?.image}
          width={220}
          height={190}
          alt="Product"
          className="product_card_prod_img"
          onErrorCapture={placeholderImage}
        />
        {data?.is_feature ? (
          <div className="product_card_featured_cont">
            <BiBadgeCheck size={16} color="white" />
            <p className="product_card_featured">{t("featured")}</p>
          </div>
        ) : null}

        <div
          className="product_card_black_heart_cont"
          onClick={(e) => handleLikeItem(e)}
        >
          {data?.is_liked ? (
            <button className="isLiked">
              <FaHeart size={24} className="like_icon" />
            </button>
          ) : (
            <button>
              <FaRegHeart size={24} className="like_icon" />
            </button>
          )}
        </div>
      </div>
      <div className="product_card_prod_price_cont">
        <span className="product_card_prod_price">
          {formatPriceAbbreviated(data?.price)}
        </span>
        <p className="product_card_prod_date">
          {formatDate(data?.created_at)}&lrm;
        </p>
      </div>
      <p className="product_card_prod_name">{data?.name}</p>
      {/* <span className='decs'>{data?.description}</span> */}
      <p className="product_card_prod_det">
        {data?.city}
        {data?.state ? "," : null}
        {data?.state}
        {data?.country ? "," : null}
        {data?.country}
      </p>
    </div>
  );
};

export default ProductCard;
