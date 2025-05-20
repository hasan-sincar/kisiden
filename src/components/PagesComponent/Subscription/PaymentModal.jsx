import { placeholderImage, t } from "@/utils";
import { Modal } from "antd";
import Image from "next/image";
import React, { useState, useEffect } from "react";
import { FaAngleRight } from "react-icons/fa6";
import { MdClose } from "react-icons/md";
import stripe from "../../../../public/assets/ic_stripe.png";
import toast from "react-hot-toast";
import PaymentModalSkeleton from "@/components/Skeleton/PaymentModalSkeleton";
import StripePayment from "./StripePayment";
import RazorpayPayment from "./RazorpayPayment";
import PaystackPayment from "./PaystackPayment";
import FlutterwavePayment from "./FlutterwavePayment";
import PhonepePayment from "./PhonepePayment";
import BankTransfer from "./BankTransfer";

const PaymentModal = ({
  isPaymentModal,
  OnHide,
  packageSettings,
  priceData,
  settingsData,
  user,
  setItemPackages,
  setAdvertisementPackage,
  IsPaymentModalOpening,
}) => {
  const PayStackActive = packageSettings?.Paystack;
  const RazorPayActive = packageSettings?.Razorpay;
  const StripeActive = packageSettings?.Stripe;
  const PhonepayActive = packageSettings?.PhonePe;
  const FlutterwaveActive = packageSettings?.flutterwave;
  const [showStripeForm, setShowStripeForm] = useState(false);
  const isBankTransferActive = Number(packageSettings?.bankTransfer?.status);

  const PaymentModalClose = () => {
    OnHide();
    setShowStripeForm(false);
  };

  const CloseIcon = (
    <div className="close_icon_cont">
      <MdClose size={24} color="black" />
    </div>
  );
  const updateActivePackage = () => {
    if (priceData.type === "advertisement") {
      setAdvertisementPackage((prev) => {
        return prev.map((item) => {
          if (item.id === priceData.id) {
            return { ...item, is_active: true };
          }
          return item;
        });
      });
    } else if (priceData.type === "item_listing") {
      setItemPackages((prev) => {
        return prev.map((item) => {
          if (item.id === priceData.id) {
            return { ...item, is_active: true };
          }
          return item;
        });
      });
    }
    toast.success(t("paymentSuccess"));
  };

  const handleMessage = (event) => {
    if (event.origin === process.env.NEXT_PUBLIC_API_URL) {
      const { status } = event.data;
      if (status === "success") {
        updateActivePackage();
        PaymentModalClose();
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
    <>
      <Modal
        centered
        open={isPaymentModal}
        closeIcon={CloseIcon}
        colorIconHover="transparent"
        className="ant_payment_modal"
        onCancel={PaymentModalClose}
        footer={null}
        maskClosable={false}
      >
        <div className="payment_section">
          {IsPaymentModalOpening ? (
            <PaymentModalSkeleton />
          ) : showStripeForm ? (
            <StripePayment
              priceData={priceData}
              packageSettings={packageSettings}
              updateActivePackage={updateActivePackage}
              PaymentModalClose={PaymentModalClose}
              setShowStripeForm={setShowStripeForm}
            />
          ) : (
            <div className="card">
              <div className="card-header">
                <span>{t("paymentWith")}</span>
              </div>
              <div className="card-body">
                <div className="row">
                  {StripeActive?.status === 1 && (
                    <div className="col-12">
                      <button onClick={() => setShowStripeForm(true)}>
                        <div className="payment_details">
                          <Image
                            loading="lazy"
                            src={stripe}
                            onEmptiedCapture={placeholderImage}
                          />
                          <span>{t("stripe")}</span>
                        </div>
                        <div className="payment_icon">
                          <FaAngleRight size={18} />
                        </div>
                      </button>
                    </div>
                  )}
                  {RazorPayActive?.status === 1 && (
                    <RazorpayPayment
                      priceData={priceData}
                      packageSettings={packageSettings}
                      settingsData={settingsData}
                      user={user}
                      updateActivePackage={updateActivePackage}
                      PaymentModalClose={PaymentModalClose}
                    />
                  )}
                  {PayStackActive?.status === 1 && (
                    <PaystackPayment
                      priceData={priceData}
                      packageSettings={packageSettings}
                    />
                  )}
                  {PhonepayActive?.status === 1 && (
                    <PhonepePayment priceData={priceData} />
                  )}
                  {FlutterwaveActive?.status === 1 && (
                    <FlutterwavePayment priceData={priceData} />
                  )}
                  {
                    isBankTransferActive === 1 && <BankTransfer closePaymentModal={PaymentModalClose} priceData={priceData} />
                  }
                </div>
              </div>
            </div>
          )}
        </div>
      </Modal>
    </>
  );
};

export default PaymentModal;
