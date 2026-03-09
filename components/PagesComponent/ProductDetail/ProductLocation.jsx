import { IoLocationOutline } from "react-icons/io5";
import dynamic from "next/dynamic";
import { t } from "@/utils";

const Map = dynamic(() => import("@/components/Location/Map"), {
  ssr: false,
});

const ProductLocation = ({ productDetails }) => {
  const handleShowMapClick = () => {
    const locationQuery = `${
      productDetails?.translated_item?.address || productDetails?.address
    }`;
    const googleMapsUrl = `https://www.google.com/maps?q=${locationQuery}&ll=${productDetails?.latitude},${productDetails?.longitude}&z=12&t=m`;
    window.open(googleMapsUrl, "_blank");
  };

  return (
    <div className="flex flex-col border rounded-lg ">
      <div className="p-4">
        <p className="font-bold">{t("postedIn")}</p>
      </div>
      <div className="border-b w-full"></div>
      <div className="flex flex-col p-4 gap-4">
        <div className="flex items-start gap-2   ">
          <IoLocationOutline size={22} className="mt-1" />
          <p className="w-full overflow-hidden text-ellipsis">
            {productDetails?.translated_address}
          </p>
        </div>
        <div className="rounded-lg overflow-hidden">
          <Map
            latitude={productDetails?.latitude}
            longitude={productDetails?.longitude}
          />
        </div>
        <div>
          <button
            className="border px-4 py-2 rounded-md w-full flex items-center gap-2 text-base  justify-center"
            onClick={handleShowMapClick}
          >
            {t("showOnMap")}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ProductLocation;
