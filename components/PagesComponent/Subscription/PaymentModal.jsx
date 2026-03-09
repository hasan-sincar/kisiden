import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { t } from "@/utils";
import RazorpayPayment from "./RazorpayPayment";
import PayStackPayment from "./PayStackPayment";
import FlutterwavePayment from "./FlutterwavePayment";
import PhonepePayment from "./PhonepePayment";
import StripePayment from "./StripePayment";
import StripeLogo from "../../../public/assets/ic_stripe.png";
import { FaAngleRight } from "react-icons/fa";
import PaymentModalLoading from "./PaymentModalLoading";
import { toast } from "sonner";
import BankTransferPayment from "./BankTransferPayment";
import CustomImage from "@/components/Common/CustomImage";
import PaypalPayment from "./PaypalPayment";

const PaymentModal = ({
  showPaymentModal,
  setShowPaymentModal,
  selectedPackage,
  packageSettings,
  isLoading,
  setToggleApiAfterPaymentSuccess
}) => {
  const [showStripePayment, setShowStripePayment] = useState(false);
  const isBankTransferActive =
    Number(packageSettings?.bankTransfer?.status) === 1;
  const PaymentModalClose = () => {
    setShowPaymentModal(false);
    setShowStripePayment(false);
  };

  const handleMessage = (event) => {
    if (event.origin === process.env.NEXT_PUBLIC_API_URL) {
      const { status } = event.data;
      if (status === "success") {
        toast.success(t("paymentSuccess"));
        setToggleApiAfterPaymentSuccess((prev) => !prev)
      } else if (status === "cancel") {
        toast.error(t("paymentCancelled"));
      } else {
        toast.error(t("paymentFailed"));
      }
      PaymentModalClose();
    }
  };

  useEffect(() => {
    window.addEventListener("message", handleMessage);
    return () => {
      window.removeEventListener("message", handleMessage);
    };
  }, [handleMessage]);

  return (
    <div>
      <Dialog open={showPaymentModal} onOpenChange={PaymentModalClose}>
        <DialogContent
          className="!max-w-[520px]"
          onInteractOutside={(e) => {
            e.preventDefault();
          }}
        >
          <DialogHeader className="border-b border-gray-400 pb-5 ">
            <DialogTitle className="text-lg">{t("paymentWith")} {showStripePayment && t("stripe")}</DialogTitle>
          </DialogHeader>
          {isLoading ? (
            <div className="flex justify-center items-center h-full flex-col gap-4">
              {Array.from({ length: 7 }).map((_, index) => (
                <PaymentModalLoading key={index} />
              ))}
            </div>
          ) : showStripePayment ? (
            <StripePayment
              selectedPackage={selectedPackage}
              packageSettings={packageSettings}
              PaymentModalClose={PaymentModalClose}
              setShowStripePayment={setShowStripePayment}
              setToggleApiAfterPaymentSuccess={setToggleApiAfterPaymentSuccess}
            />
          ) : (
            <div className="flex flex-col gap-4 mt-2">
              {packageSettings?.Stripe?.status == 1 && (
                <button
                  onClick={() => setShowStripePayment(true)}
                  className="w-full p-2"
                >
                  <div className="flex items-center gap-2 justify-between ">
                    <div className="flex gap-3 items-center">
                      <div className="w-8 h-8">
                        <CustomImage
                          height={32}
                          width={32}
                          src={StripeLogo.src}
                          alt="Stripe"
                          className="w-full h-full "
                        />
                      </div>
                      <p className="text-lg font-semibold">{t("stripe")}</p>
                    </div>
                    <FaAngleRight size={18} className="rtl:scale-x-[-1]" />
                  </div>
                </button>
              )}
              {packageSettings?.Razorpay?.status == 1 && (
                <RazorpayPayment
                  packageSettings={packageSettings}
                  selectedPackage={selectedPackage}
                  setShowPaymentModal={setShowPaymentModal}
                  setToggleApiAfterPaymentSuccess={setToggleApiAfterPaymentSuccess}
                />
              )}
              {packageSettings?.Paystack?.status == 1 && (
                <PayStackPayment
                  packageSettings={packageSettings}
                  selectedPackage={selectedPackage}
                />
              )}
              {packageSettings?.flutterwave?.status == 1 && (
                <FlutterwavePayment selectedPackage={selectedPackage} />
              )}
              {packageSettings?.PhonePe?.status == 1 && (
                <PhonepePayment selectedPackage={selectedPackage} />
              )}

              {packageSettings?.Paypal?.status == 1 && (
                <PaypalPayment selectedPackage={selectedPackage} />
              )}

              {isBankTransferActive && (
                <BankTransferPayment closePaymentModal={PaymentModalClose} />
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default PaymentModal;
