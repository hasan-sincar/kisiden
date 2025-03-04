import { useCallback } from "react";
import Image from "next/image";
import { FaAngleRight } from "react-icons/fa6";
import paystack from "../../../../public/assets/ic_paystack.png";
import { t, placeholderImage } from "@/utils";
import { createPaymentIntentApi } from "@/utils/api";
import toast from "react-hot-toast";

const PaystackPayment = ({ priceData, packageSettings }) => {
  const handlePayStackPayment = useCallback(async () => {
    try {
      const res = await createPaymentIntentApi.createIntent({
        package_id: priceData.id,
        payment_method: packageSettings.Paystack.payment_method,
        platform_type: "web",
      });

      if (res.data.error) {
        throw new Error(res.data.message);
      }

      const paymentIntent = res.data.data.payment_intent;
      const authorizationUrl =
        paymentIntent?.payment_gateway_response?.data?.authorization_url;

      if (authorizationUrl) {
        const popupWidth = 600;
        const popupHeight = 700;
        const popupLeft = window.innerWidth / 2 - popupWidth / 2;
        const popupTop = window.innerHeight / 2 - popupHeight / 2;

        window.open(
          authorizationUrl,
          "paymentWindow",
          `width=${popupWidth},height=${popupHeight},top=${popupTop},left=${popupLeft}`
        );
      } else {
        throw new Error("Unable to retrieve authorization URL.");
      }
    } catch (error) {
      console.error("An error occurred while processing the payment:", error);
      toast.error(t("errorOccurred"));
    }
  }, [packageSettings, priceData]);

  return (
    <div className="col-12">
      <button onClick={handlePayStackPayment}>
        <div className="payment_details">
          <Image
            loading="lazy"
            src={paystack}
            onEmptiedCapture={placeholderImage}
          />
          <span>{t("payStack")}</span>
        </div>
        <div className="payment_icon">
          <FaAngleRight size={18} />
        </div>
      </button>
    </div>
  );
};

export default PaystackPayment;
