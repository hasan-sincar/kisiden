import React, { useCallback } from "react";
import Image from "next/image";
import { FaAngleRight } from "react-icons/fa6";
import phonepay from "../../../../public/assets/phonepe-icon.png";
import { t, placeholderImage } from "@/utils";
import { createPaymentIntentApi } from "@/utils/api";
import toast from "react-hot-toast";
import { useSelector } from "react-redux";
import { userSignUpData } from "@/redux/reuducer/authSlice";


const PhonepePayment = ({ priceData }) => {
  const userData = useSelector(userSignUpData);

  const handlePhonepePayment = useCallback(async () => {
    if (!userData?.mobile) {
      toast.error(t("addMobileNumberToProceed"));
      return;
    }
    try {
      const res = await createPaymentIntentApi.createIntent({
        package_id: priceData.id,
        payment_method: "PhonePe",
        platform_type: 'web'
      });
      if (res.data.error) {
        console.log("Error in payment intent response:", res.data.message);
        toast.error(res.data.message);
        return;
      }

      const payment_gateway_response =
        res.data.data.payment_intent.payment_gateway_response?.payment_gateway_response;

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
      console.error("Error during PhonePe payment", error);
      toast.error(t("errorOccurred"));
    }
  }, [priceData, userData]);

  return (
    <div className="col-12">
      <button onClick={handlePhonepePayment}>
        <div className="payment_details">
          <Image
            loading="lazy"
            src={phonepay}
            onEmptiedCapture={placeholderImage}
            width={30}
            height={30}
          />
          <span>{t("phonepe")}</span>
        </div>
        <div className="payment_icon">
          <FaAngleRight size={18} />
        </div>
      </button>
    </div>
  );
};

export default PhonepePayment;
