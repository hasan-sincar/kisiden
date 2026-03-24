import { createPaymentIntentApi } from "@/utils/api";
import { useState } from "react";
import { useRazorpay } from "react-razorpay";
import RazorpayLogo from "../../../public/assets/ic_razorpay.png";
import { FaAngleRight } from "react-icons/fa";
import { useSelector } from "react-redux";
import { toast } from "sonner";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";
import { Loader2 } from "lucide-react";

const RazorpayPayment = ({
  packageSettings,
  selectedPackage,
  setShowPaymentModal,
  navigate
}) => {
  const { Razorpay } = useRazorpay();
  const { data: settingsData } = useSelector((state) => state.Settings);
  const { data: user } = useSelector((state) => state.UserSignup);
  const [isLoading, setIsLoading] = useState(false);
  let rzpay;

  const PayWithRazorPay = async () => {
    try {
      setIsLoading(true);
      const res = await createPaymentIntentApi.createIntent({
        package_id: selectedPackage.id,
        payment_method: packageSettings.Razorpay.payment_method,
      });
      if (res.data.error) {
        toast.error(res.data.message);
        return;
      }
      setShowPaymentModal(false);
      const paymentIntent = res.data.data.payment_intent;
      const options = {
        key: packageSettings.Razorpay.api_key,
        name: settingsData.company_name,
        description: settingsData.company_name,
        image: settingsData.company_logo,
        order_id: paymentIntent.id,
        handler: function (response) {
          toast.success(t("paymentSuccess"));
          navigate('/')
        },
        prefill: {
          name: user.name,
          email: user.email,
          contact: user.mobile,
        },
        notes: {
          address: user.address,
          user_id: user.id,
          package_id: selectedPackage.id,
        },
        theme: {
          color: settingsData.web_theme_color,
        },
      };

      rzpay = new Razorpay(options); // Assign rzpay outside the function

      rzpay.on("payment.failed", function (response) {
        console.error(response.error.description);
        if (rzpay) {
          rzpay?.close();
        }
      });

      rzpay.open();
    } catch (error) {
      console.error("Error during payment", error);
      toast.error(t("errorProcessingPayment"));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div>
      <button onClick={PayWithRazorPay} className="w-full p-2">
        <div className="flex items-center gap-2 justify-between ">
          <div className="flex gap-3 items-center">
            <div className="w-8 h-8">
              <CustomImage
                src={RazorpayLogo.src}
                alt="Razorpay"
                width={32}
                height={32}
                className="w-full h-full "
              />
            </div>
            <p className="text-lg font-semibold">{t("razorPay")}</p>
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

export default RazorpayPayment;
