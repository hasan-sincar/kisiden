import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { itemOfferApi, tipsApi } from "@/utils/api";
import { t } from "@/utils";
import { Skeleton } from "@/components/ui/skeleton";
import { FaCheck } from "react-icons/fa";
import { useNavigate } from "@/components/Common/useNavigate";

const MakeOfferModal = ({ isOpen, onClose, productDetails }) => {
  const { navigate } = useNavigate();
  const [offerAmount, setOfferAmount] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [tips, setTips] = useState([]);
  const [isLoadingTips, setIsLoadingTips] = useState(true);
  const [canProceed, setCanProceed] = useState(false);

  useEffect(() => {
    if (isOpen) {
      fetchTips();
    }
  }, [isOpen]);

  const fetchTips = async () => {
    try {
      setIsLoadingTips(true);
      const response = await tipsApi.tips();
      if (response?.data?.error === false) {
        const tipsData = response.data.data || [];
        setTips(tipsData);
        // If no tips found, automatically set canProceed to true
        if (!tipsData.length) {
          setCanProceed(true);
        }
      }
    } catch (error) {
      console.error("Error fetching tips:", error);
      // If error occurs, show make offer interface
      setCanProceed(true);
    } finally {
      setIsLoadingTips(false);
    }
  };

  const validateOffer = () => {
    if (!offerAmount.trim()) {
      setError(t("offerAmountRequired"));
      return false;
    }

    const amount = Number(offerAmount);
    if (amount >= productDetails?.price) {
      setError(t("offerMustBeLessThanSellerPrice"));
      return false;
    }

    setError("");
    return true;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!validateOffer()) {
      return;
    }

    try {
      setIsSubmitting(true);
      const response = await itemOfferApi.offer({
        item_id: productDetails?.id,
        amount: Number(offerAmount),
      });

      if (response?.data?.error === false) {
        toast.success(t("offerSentSuccessfully"));
        onClose();
        navigate("/chat?activeTab=buying&chatid=" + response?.data?.data?.id + '&chat_ad_id=' + productDetails?.id);
      } else {
        toast.error(t("unableToSendOffer"));
      }
    } catch (error) {
      toast.error(t("unableToSendOffer"));
      console.error(error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleChange = (e) => {
    setOfferAmount(e.target.value);
    setError(""); // Clear error when user starts typing
  };

  const handleContinue = () => {
    setCanProceed(true);
  };

  const renderMakeOfferForm = () => (
    <div className="space-y-4">
      <DialogHeader>
        <DialogTitle className="text-4xl font-normal">
          {t("makeAn")}
          <span className="text-primary">&nbsp;{t("offer")}</span>
        </DialogTitle>
        <DialogDescription>{t("openToOffers")}</DialogDescription>
      </DialogHeader>

      <div className="flex flex-col gap-2 bg-muted py-6 px-3 rounded-md justify-center items-center">
        <span>{t("sellerPrice")}</span>
        <span className="text-2xl font-medium">
          {productDetails?.formatted_price}
        </span>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        <div className="space-y-2">
          <Label htmlFor="offerAmount" className="requiredInputLabel">
            {t("yourOffer")}
          </Label>
          <Input
            id="offerAmount"
            type="number"
            value={offerAmount}
            onChange={handleChange}
            placeholder={t("typeOfferPrice")}
            min={0}
            className={error ? "border-red-500 focus-visible:ring-red-500" : ""}
          />
          {error && <span className="text-red-500 text-sm">{error}</span>}
        </div>
        <Button
          type="submit"
          className="py-2 px-4 rounded-md"
          disabled={isSubmitting}
        >
          {isSubmitting ? t("sending") : t("sendOffer")}
        </Button>
      </form>
    </div>
  );

  const renderTipsSection = () => (
    <>
      <DialogHeader>
        <DialogTitle className="text-4xl text-center font-normal">
          {t("safety")}
          <span className="text-primary">&nbsp;{t("tips")}</span>
        </DialogTitle>
      </DialogHeader>
      {isLoadingTips ? (
        <div className="space-y-3">
          {Array.from({ length: 12 }).map((_, i) => (
            <div key={i} className="flex items-center space-x-4">
              <Skeleton className="h-4 w-[5%]" />
              <Skeleton className="h-4 w-[95%]" />
            </div>
          ))}
        </div>
      ) : (
        <div className="space-y-3">
          {tips.map((tip) => (
            <div key={tip?.id} className="flex items-center gap-2">
              <div className="p-2 text-white bg-primary rounded-full">
                <FaCheck size={18} />
              </div>
              <p className="">{tip?.translated_name}</p>
            </div>
          ))}
        </div>
      )}
      <Button onClick={handleContinue}>{t("continue")}</Button>
    </>
  );

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent
        onInteractOutside={(e) => e.preventDefault()}
        className="sm:py-[50px] sm:px-[90px]"
      >
        {!canProceed ? renderTipsSection() : renderMakeOfferForm()}
      </DialogContent>
    </Dialog>
  );
};

export default MakeOfferModal;
