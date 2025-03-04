import { useCallback } from "react";
import Image from "next/image";
import { FaAngleRight } from "react-icons/fa6";
import razorpay from "../../../../public/assets/ic_razorpay.png";
import { t, placeholderImage } from "@/utils";
import { createPaymentIntentApi } from "@/utils/api";
import toast from "react-hot-toast";
import useRazorpay from "react-razorpay";

const RazorpayPayment = ({
  priceData,
  packageSettings,
  settingsData,
  user,
  updateActivePackage,
  PaymentModalClose,
}) => {
  const [Razorpay, isLoaded] = useRazorpay();
  let rzpay; // Define rzpay outside the function

  const PayWithRazorPay = useCallback(async () => {
    try {
      const res = await createPaymentIntentApi.createIntent({
        package_id: priceData.id,
        payment_method: packageSettings.Razorpay.payment_method,
      });
      if (res.data.error) {
        toast.error(res.data.message);
        return;
      }
      PaymentModalClose();
      const paymentIntent = res.data.data.payment_intent;
      const options = {
        key: packageSettings.Razorpay.api_key,
        name: settingsData.company_name,
        description: settingsData.company_name,
        image: settingsData.company_logo,
        order_id: paymentIntent.id,
        handler: function (response) {
          updateActivePackage();
        },
        prefill: {
          name: user.name,
          email: user.email,
          contact: user.mobile,
        },
        notes: {
          address: user.address,
          user_id: user.id,
          package_id: priceData.id,
        },
        theme: {
          color: settingsData.web_theme_color,
        },
      };

      rzpay = new Razorpay(options); // Assign rzpay outside the function

      rzpay.on("payment.failed", function (response) {
        console.error(response.error.description);
        if (rzpay) {
          rzpay?.close(); // Close the Razorpay payment modal
        }
      });
      
      rzpay.open();
    } catch (error) {
      console.error("Error during payment", error);
      toast.error(t("errorProcessingPayment"));
    }
  }, [
    packageSettings,
    priceData,
    settingsData,
    user,
    updateActivePackage,
    PaymentModalClose,
  ]);

  return (
    <div className="col-12">
      <button onClick={PayWithRazorPay}>
        <div className="payment_details">
          <Image
            loading="lazy"
            src={razorpay}
            onEmptiedCapture={placeholderImage}
          />
          <span>{t("razorPay")}</span>
        </div>
        <div className="payment_icon">
          <FaAngleRight size={18} />
        </div>
      </button>
    </div>
  );
};

export default RazorpayPayment;
