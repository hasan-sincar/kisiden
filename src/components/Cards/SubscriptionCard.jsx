import { FaArrowRight, FaCheck } from "react-icons/fa6";
import Image from "next/image";
import { formatPriceAbbreviated, placeholderImage, t } from "@/utils";

const SubscriptionCard = ({ data, handlePurchasePackage }) => {
  const descriptionItems = data?.description
    ? data.description.split("\r\n")
    : [];

  return (
    <div className={`card regular_card ${data.is_active ? "active_card" : ""}`}>
      <div className="card-header">
        <div className="sub_icon_div">
          <Image
            src={data?.icon}
            alt={data?.name}
            width={80}
            height={80}
            className="sub_icon"
            onErrorCapture={placeholderImage}
          />
        </div>
        <div className="sub_details">
          <span className="name">{data?.name}</span>
          <div className="price">
            {data?.final_price !== 0 ? (
              <span className="price">
                {formatPriceAbbreviated(data?.final_price)}
              </span>
            ) : (
              t("Free")
            )}
            {data?.price > data?.final_price && (
              <span className="sale_price">
                {formatPriceAbbreviated(data?.price)}
              </span>
            )}
          </div>
          {!data.is_active
            ? data?.discount_in_percentage !== 0 && (
                <span className="sale_tag">
                  {data?.discount_in_percentage}% {t("off")}
                </span>
              )
            : null}
        </div>
      </div>
      <div className="card-body">
        <div className="details_list">
          <div className="list_menu">
            <div>
              <FaCheck size={24} className="right" />
            </div>
            <div>
              <span>
                {data?.item_limit} {t("adsListing")}
              </span>
            </div>
          </div>
          <div className="list_menu">
            <div>
              <FaCheck size={24} className="right" />
            </div>
            <div>
              <span>
                {data?.duration !== "unlimited"
                  ? `${data?.duration}  ${t("days")}`
                  : `${data?.duration}  ${t("days")}`}{" "}
              </span>
            </div>
          </div>

          {descriptionItems.map((item, index) => (
            <div className="list_menu" key={index}>
              <div>
                <FaCheck size={24} className="right" />
              </div>
              <div>
                <span>{item}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="card-footer">
        <button
          onClick={(e) => handlePurchasePackage(e, data)}
          style={{ visibility: data.is_active ? "hidden" : "visible" }}
        >
          <span>{t("choosePlan")}</span>
          <FaArrowRight size={24} className="sub_card_arrow" />
        </button>
      </div>
    </div>
  );
};

export default SubscriptionCard;
