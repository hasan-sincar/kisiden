import { Button } from "@/components/ui/button";
import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogTitle,
} from "@/components/ui/dialog";
import { t } from "@/utils";
import { IoAlertCircleOutline } from "react-icons/io5";
import { LuBadgeCheck } from "react-icons/lu";
import { AiOutlineClose } from "react-icons/ai";
import { useState } from "react";
import { useNavigate } from "@/components/Common/useNavigate";
import { LiaAdSolid } from "react-icons/lia";

const PackageRequiredModal = ({ open, onClose, initialStep = 1, categoryId = null, categoryName = null }) => {
    const [step, setStep] = useState(initialStep);
    const { navigate } = useNavigate();

    const handleOnClose = () => {
        setStep(1);
        onClose();
    };

    const handleSelectPlan = (type) => {
        handleOnClose();
        if (type === 'listing') {
            const categoryQuery = categoryId ? `&category_id=${categoryId}` : "";
            navigate(`/subscription?plan=listing${categoryQuery}`);
        } else {
            navigate("/subscription?plan=featured");
        }
    };

    const handleSubscribe = () => {
        if (categoryId) {
            // If categoryId exists, skip "Select Subscription Type" 
            // and go straight to the Listing plan
            handleSelectPlan('listing');
        } else {
            // Otherwise, show Step 2 to let them choose
            setStep(2);
        }
    }

    return (
        <Dialog open={open} onOpenChange={handleOnClose}>
            <DialogContent
                className={`${step === 1 ? "max-w-[360px] sm:max-w-[400px]" : "max-w-[580px]"} [&>button]:hidden !p-0 overflow-hidden border-none shadow-2xl`}
            >
                {/* Accessible but visually hidden title/description */}
                <DialogTitle className="sr-only">
                    {step === 1 ? t("noPackage") : t("selectSubscriptionType")}
                </DialogTitle>
                <DialogDescription className="sr-only">
                    {step === 1 ? t("subscribeBeforeAdListing") : "Choose between ad listing and feature plans"}
                </DialogDescription>

                {step === 1 ? (
                    <div className="p-6">
                        <div className="flex flex-col items-center text-center gap-4">
                            <div className="size-20 rounded-full bg-muted flex items-center justify-center">
                                <IoAlertCircleOutline className="size-14 text-primary" />
                            </div>
                            <h3 className="font-semibold text-lg">{t("noPackage")}</h3>
                            <p className="text-sm text-muted-foreground leading-relaxed">
                                {categoryName
                                    ? `${t("subscribeToPackageFor")} ${categoryName}`
                                    : t("subscribeBeforeAdListing")}
                            </p>
                        </div>
                        <div className="flex gap-3 mt-6 pt-6 border-t font-medium">
                            <DialogClose asChild>
                                <Button variant="outline" className="flex-1 bg-muted hover:bg-muted/80">{t('cancel')}</Button>
                            </DialogClose>
                            <Button
                                className="flex-1"
                                onClick={handleSubscribe}
                            >
                                {t('subscribe')}
                            </Button>
                        </div>
                    </div>
                ) : (
                    <>
                        <div className="flex items-center justify-between p-4 px-6 border-b">
                            <h3 className="font-semibold text-lg text-gray-800">{t('selectSubscriptionType')}</h3>
                            <button
                                onClick={handleOnClose}
                                className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                            >
                                <AiOutlineClose size={20} className="text-muted-foreground" />
                            </button>
                        </div>

                        <div className="p-8 grid grid-cols-1 sm:grid-cols-2 gap-6">
                            {/* Ad Listing Plan */}
                            <button
                                onClick={() => handleSelectPlan('listing')}
                                className="group flex flex-col items-center p-6 border rounded-2xl text-center"
                            >
                                <div className="size-16 rounded-full bg-muted flex items-center justify-center mb-4 transition-transform group-hover:scale-110 duration-300">
                                    <LiaAdSolid className='size-8 text-primary' />
                                </div>
                                <h4 className="font-semibold mb-1">{t('adListingPlan')}</h4>
                                <p className="text-xs text-muted-foreground">{t('buyCategoryBasedSubscription')}</p>
                            </button>

                            {/* Feature Ads Plan */}
                            <button
                                onClick={() => handleSelectPlan('feature')}
                                className="group flex flex-col items-center p-6 border rounded-2xl transition-all duration-300 text-center"
                            >
                                <div className="size-16 rounded-full bg-muted flex items-center justify-center mb-4 transition-transform group-hover:scale-110 duration-300">
                                    <LuBadgeCheck className="size-8 text-primary" />
                                </div>
                                <h4 className="font-semibold mb-1">{t('featuredAdPlan')}</h4>
                                <p className="text-xs text-muted-foreground">{t('increaseVisibilityForSpecificAds')}</p>
                            </button>
                        </div>
                    </>
                )}
            </DialogContent>
        </Dialog>
    );
};

export default PackageRequiredModal;
