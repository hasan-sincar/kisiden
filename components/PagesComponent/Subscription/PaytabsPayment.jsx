import CustomImage from "@/components/Common/CustomImage";
import paytabsLogo from "../../../public/assets/paytabs.webp";
import { Loader2 } from "lucide-react";
import { FaAngleRight } from "react-icons/fa";
import { t } from "@/utils";
import { useState } from "react";
import { createPaymentIntentApi } from "@/utils/api";
import { toast } from "sonner";


const PaytabsPayment = ({ selectedPackage }) => {

    const [isLoading, setIsLoading] = useState(false);

    const handlePaytabsPayment = async () => {
        try {
            setIsLoading(true);
            const res = await createPaymentIntentApi.createIntent({
                package_id: selectedPackage.id,
                payment_method: "Paytabs",
                platform_type: "web",
            });
            if (res.data.error) {
                toast.error(res.data.message);
                return;
            }
            const payment_gateway_response =
                res?.data?.data?.payment_intent?.payment_url;

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
        } finally {
            setIsLoading(false);
        }
    }

    return (
        <button onClick={handlePaytabsPayment} className="w-full p-2">
            <div className="flex items-center gap-2 justify-between ">
                <div className="flex gap-3 items-center">
                    <div className="w-8 h-8">
                        <CustomImage
                            height={32}
                            width={32}
                            src={paytabsLogo}
                            alt="PayTabs"
                            className="w-full h-full "
                        />
                    </div>
                    <p className="text-lg font-semibold">{t("paytabs")}</p>
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
    )
}

export default PaytabsPayment