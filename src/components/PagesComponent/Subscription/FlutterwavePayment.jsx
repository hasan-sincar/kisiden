import React, { useCallback } from "react";
import Image from "next/image";
import { FaAngleRight } from "react-icons/fa6";
import fluttervave from "../../../../public/assets/flutterwave.png";
import { t, placeholderImage } from "@/utils";
import { createPaymentIntentApi } from "@/utils/api";
import toast from "react-hot-toast";

const FlutterwavePayment = ({
  priceData,
}) => {
  
  const handleFlutterwavePayment = useCallback(async () => {
    try {
      const res = await createPaymentIntentApi.createIntent({
        package_id: priceData.id,
        payment_method: "FlutterWave",
      });
      if (res.data.error) {
        toast.error(res.data.message);
        return;
      }
      const payment_gateway_response =
        res?.data?.data?.payment_intent?.payment_gateway_response?.data?.link;

      if (payment_gateway_response) {
        const popupWidth = 600;
        const popupHeight = 700;
        const popupLeft = window.innerWidth / 2 - popupWidth / 2;
        const popupTop = window.innerHeight / 2 - popupHeight / 2;

        window.open(
          payment_gateway_response,
          "paymentWindow",
          `width=${popupWidth},height=${popupHeight},top=${popupTop},left=${popupLeft}`
        );
      } else {
        throw new Error("Unable to retrieve payment gateway response.");
      }
    } catch (error) {
      console.error("Error during Flutterwave payment", error);
      toast.error(t("errorOccurred"));
    }
  }, [priceData]);

  return (
    <div className="col-12">
      <button onClick={handleFlutterwavePayment}>
        <div className="payment_details">
          <Image
            loading="lazy"
            src={fluttervave}
            onEmptiedCapture={placeholderImage}
            width={30}
            height={30}
          />
          <span>{t("flutterwave")}</span>
        </div>
        <div className="payment_icon">
          <FaAngleRight size={18} />
        </div>
      </button>
    </div>
  );
};

export default FlutterwavePayment;
