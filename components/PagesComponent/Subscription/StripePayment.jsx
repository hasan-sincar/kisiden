import React, { useState, useEffect, useCallback } from "react";

import {
  Elements,
  ElementsConsumer,
  PaymentElement,
} from "@stripe/react-stripe-js";
import { loadStripe } from "@stripe/stripe-js";
import { createPaymentIntentApi } from "@/utils/api";
import { toast } from "sonner";
import { t } from "@/utils";
import { Loader2 } from "lucide-react";

const StripePayment = ({
  selectedPackage,
  packageSettings,
  PaymentModalClose,
  setShowStripePayment,
  setToggleApiAfterPaymentSuccess
}) => {
  const [stripePromise, setStripePromise] = useState(null);
  const [clientSecret, setClientSecret] = useState("");
  const [loading, setLoading] = useState(true);
  const [formattedPrice, setFormattedPrice] = useState('')

  useEffect(() => {
    const loadStripeInstance = async () => {
      if (packageSettings?.Stripe?.api_key) {
        const stripeInstance = await loadStripe(packageSettings.Stripe.api_key);
        setStripePromise(stripeInstance);
      }
    };
    loadStripeInstance();
  }, [packageSettings?.Stripe?.api_key]);

  const handleStripePayment = useCallback(async () => {
    try {
      const res = await createPaymentIntentApi.createIntent({
        package_id: selectedPackage.id,
        payment_method: packageSettings.Stripe.payment_method,
      });
      if (res.data.error === true) {
        toast.error(res.data.message);
        return;
      }
      // Extract payment intent data from response
      const paymentIntent =
        res.data.data.payment_intent?.payment_gateway_response;

      // Extract formatted price from payment_intent (not from payment_gateway_response)
      const formattedPrice = res.data.data.payment_intent?.formatted_price;
      if (formattedPrice) {
        setFormattedPrice(formattedPrice);
      }

      const clientSecret = paymentIntent.client_secret;
      setClientSecret(clientSecret);
      setShowStripePayment(true);
    } catch (error) {
      console.error("Error during Stripe payment", error);
      toast.error(t("errorOccurred"));
    } finally {
      setLoading(false);
    }
  }, [
    selectedPackage.id,
    packageSettings?.Stripe?.payment_method,
    setShowStripePayment,
  ]);

  useEffect(() => {
    handleStripePayment();
  }, [handleStripePayment]);

  // PaymentForm component that uses the formattedPrice from parent scope
  const PaymentForm = ({ elements, stripe }) => {
    const [IsProcessing, setIsProcessing] = useState(false);

    const handleSubmit = async (event) => {
      event.preventDefault();
      setIsProcessing(true);

      // First, submit the elements to validate and prepare the payment method
      // This must be called before confirmPayment
      const { error: submitError } = await elements.submit();

      if (submitError) {
        // Handle validation errors
        toast.error(submitError.message || t("paymentFailed"));
        setIsProcessing(false);
        return;
      }

      // PaymentElement handles payment method creation internally
      // Just confirm the payment with the client secret
      try {
        const { error: confirmError } = await stripe.confirmPayment({
          elements,
          clientSecret,
          redirect: "if_required",
        });

        if (confirmError) {
          // Handle payment confirmation error
          console.error(confirmError.message);
          toast.error(confirmError.message || t("paymentFailed"));
        } else {
          // Payment succeeded
          toast.success(t("paymentSuccess"));
          setToggleApiAfterPaymentSuccess((prev) => !prev)
          PaymentModalClose();
        }
      } catch (error) {
        console.error("Error during payment:", error);
      } finally {
        setIsProcessing(false);
      }
    };

    return (
      <form onSubmit={handleSubmit}>
        <div className="stripe_module">
          {/* <div className="mb-4 text-lg font-semibold">
            {t("pay")} {amountToPay / 100} {currency?.toUpperCase()}
          </div> */}
          <PaymentElement />
          <button
            className="w-full bg-primary text-white p-2 rounded-md my-4 flex items-center justify-center"
            type="submit"
            disabled={!stripePromise || IsProcessing}
          >
            {IsProcessing ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              t("pay") + " " + formattedPrice
            )}
          </button>
        </div>
      </form>
    );
  };

  return (
    <>
      {loading ? (
        <div className="">
          <div className="animate-pulse">
            <div className="w-full h-10 bg-gray-200 rounded-md mb-2"></div>
            <div className="flex justify-between mb-4">
              <div className="w-1/2 h-5 bg-gray-200 rounded-md"></div>
              <div className="w-1/4 h-5 bg-gray-200 rounded-md"></div>
            </div>
            <div className="w-full h-12 bg-gray-200 rounded-md mt-6"></div>
          </div>
        </div>
      ) : (
        stripePromise &&
        clientSecret && (
          <div className="card">
            {/* <div className="card-header">{t("payWithStripe")} :</div> */}
            <div className="card-body">
              <Elements stripe={stripePromise} options={{
                clientSecret
              }}  >
                <ElementsConsumer>
                  {({ stripe, elements }) => (
                    <PaymentForm elements={elements} stripe={stripe} />
                  )}
                </ElementsConsumer>
              </Elements>
            </div>
          </div>
        )
      )}
    </>
  );
};

export default StripePayment;
