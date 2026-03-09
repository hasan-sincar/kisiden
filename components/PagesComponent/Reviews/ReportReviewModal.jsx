'use client';
import { useState, useEffect } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { addReportReviewApi } from "@/utils/api";
import { toast } from "sonner";
import { t } from "@/utils";

const ReportReviewModal = ({ isOpen, setIsOpen, reviewId, setMyReviews }) => {
    const [reason, setReason] = useState("");
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [validationError, setValidationError] = useState("");

    // Clear reason and validation error when modal closes
    useEffect(() => {
        if (!isOpen) {
            setReason("");
            setValidationError("");
        }
    }, [isOpen]);

    const handleSubmit = async () => {
        if (!reason.trim()) {
            setValidationError("Please provide a reason for the report");
            return;
        }
        setValidationError("");
        setIsSubmitting(true);
        try {
            const res = await addReportReviewApi.addReportReview({
                seller_review_id: reviewId,
                report_reason: reason,
            });

            if (res?.data?.error === false) {
                toast.success(res?.data?.message)
                setMyReviews(prevReviews =>
                    prevReviews.map(review =>
                        review.id === reviewId ? { ...review, report_reason: res?.data?.data.report_reason, report_status: res?.data?.data.report_status } : review
                    )
                );
                setReason("");
                setIsOpen(false);
            } else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.error("Error reporting review:", error);
            toast.error(t("somethingWentWrong"))
        } finally {
            setIsSubmitting(false);
        }
    };

    // Clear validation error when user types
    const handleReasonChange = (e) => {
        setReason(e.target.value);
        if (validationError) {
            setValidationError("");
        }
    };

    return (
        <Dialog open={isOpen} onOpenChange={setIsOpen}>
            <DialogContent onInteractOutside={(e) => e.preventDefault()} className="px-6 py-6 sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle className="text-xl font-medium">
                        {t('reportReview')}
                    </DialogTitle>
                    <DialogDescription className="text-sm text-gray-600 mt-2">
                        {t('reportReviewDescription')}
                    </DialogDescription>
                </DialogHeader>

                <div className="mt-4">
                    <Textarea
                        placeholder="Write your reason here"
                        className={`h-32 resize-none ${validationError ? 'border-red-500 focus-visible:ring-red-500' : ''}`}
                        value={reason}
                        onChange={handleReasonChange}
                    />
                    {validationError && (
                        <p className="text-red-500 text-sm mt-1">{validationError}</p>
                    )}
                </div>

                <div className="mt-6 flex justify-end gap-3">
                    <Button
                        type="button"
                        variant="outline"   
                        onClick={() => setIsOpen(false)}
                    >
                        Cancel
                    </Button>
                    <Button
                        type="button"
                        onClick={handleSubmit}
                        disabled={isSubmitting}
                    >
                        {isSubmitting ? t("submitting") : t("report")}
                    </Button>
                </div>
            </DialogContent>
        </Dialog>
    );
};

export default ReportReviewModal; 