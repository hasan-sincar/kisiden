import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { t } from "@/utils";
import { updateBankTransferApi } from "@/utils/api";
import { useState, useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { MdClose } from "react-icons/md";
import { toast } from "sonner";

const UploadReceiptModal = ({
  IsUploadRecipt,
  setIsUploadRecipt,
  transactionId,
  setData,
}) => {
  const [selectedFile, setSelectedFile] = useState(null);
  const [isUploading, setIsUploading] = useState(false);
  const [preview, setPreview] = useState(null);

  const onDrop = useCallback((acceptedFiles) => {
    const file = acceptedFiles[0];
    setSelectedFile(file);

    // Create preview URL
    const previewUrl = URL.createObjectURL(file);
    setPreview(previewUrl);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      "image/*": [".png", ".jpg", ".jpeg"],
    },
    maxFiles: 1,
    multiple: false,
  });

  const clearSelection = () => {
    if (preview) {
      URL.revokeObjectURL(preview);
    }
    setSelectedFile(null);
    setPreview(null);
  };

  const handleReceiptSubmit = async () => {
    try {
      setIsUploading(true);
      const res = await updateBankTransferApi.updateBankTransfer({
        payment_transection_id: transactionId,
        payment_receipt: selectedFile,
      });

      if (res?.data?.error === false) {
        setData((prevData) =>
          prevData.map((item) =>
            item.id === transactionId ? res?.data?.data : item
          )
        );
        toast.success(t("receiptUploaded"));
        setIsUploadRecipt(false);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log("Failed To Upload Receipt", error);
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <Dialog open={IsUploadRecipt} onOpenChange={setIsUploadRecipt}>
      <DialogContent onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle className="text-xl font-semibold">
            {t("uploadPaymentReceipt")}
          </DialogTitle>
          <DialogDescription className="!text-base">
            {t("uploadReceiptDescription")}
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col gap-4 mt-4">
          {!selectedFile ? (
            <div
              {...getRootProps()}
              className={`border-2 border-dashed border-gray-300 rounded-lg p-8 text-center transition-all duration-200 cursor-pointer hover:border-primary hover:bg-gray-50 ${
                isDragActive ? "border-primary bg-gray-50" : ""
              }`}
            >
              <input {...getInputProps()} />
              {/* <FileImage className="receipt-icon" /> */}
              <p className="text-sm text-black opacity-60">
                {isDragActive
                  ? t("dropYourReceiptHere")
                  : t("dragAndDropReceipt")}
              </p>
              <p className="text-sm text-black opacity-60">
                {t("clickToSelect")}
              </p>
            </div>
          ) : (
            <div className="relative">
              <img
                src={preview}
                alt="Receipt preview"
                className="w-full h-48 object-contain rounded-lg border border-gray-200"
              />
              <button
                className="absolute top-2 right-2 bg-red-500 text-white border-none rounded flex items-center justify-center w-8 h-8 cursor-pointer"
                onClick={clearSelection}
              >
                <MdClose size={24} />
              </button>
            </div>
          )}
          <button
            className="border-0 bg-primary text-white px-3 py-1.5 rounded w-max self-end disabled:opacity-65"
            onClick={handleReceiptSubmit}
            disabled={!selectedFile || isUploading}
          >
            {t("submit")}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default UploadReceiptModal;
