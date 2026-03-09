import React, { useState } from "react";
import PayStackLogo from "../../../public/assets/ic_paystack.png";
import { FaAngleRight } from "react-icons/fa";
import { createPaymentIntentApi } from "@/utils/api";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";
const PayStackPayment = ({ packageSettings, selectedPackage }) => {
  const [isLoading, setIsLoading] = useState(false);
  const handlePayStackPayment = async () => {
    try {
      setIsLoading(true);
      const res = await createPaymentIntentApi.createIntent({
        package_id: selectedPackage.id,
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
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div>
      <button onClick={handlePayStackPayment} className="w-full p-2">
        <div className="flex items-center gap-2 justify-between ">
          <div className="flex gap-3 items-center">
            <div className="w-8 h-8">
              <CustomImage
                height={32}
                width={32}
                src={PayStackLogo.src}
                alt="Paystack"
                className="w-full h-full "
              />
            </div>
            <p className="text-lg font-semibold">{t("payStack")}</p>
          </div>
          <div>
            {isLoading ? (
              <Loader2 className="w-5 h-5 animate-spin" />
            ) : (
              <FaAngleRight size={18} className="rtl:scale-x-[-1]" />
            )}
          </div>
        </div>
      </button>
    </div>
  );
};

export default PayStackPayment;
