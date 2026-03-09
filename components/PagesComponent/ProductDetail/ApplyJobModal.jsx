import { useState, useCallback, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { t } from "@/utils";
import { HiOutlineUpload } from "react-icons/hi";
import { MdOutlineAttachFile } from "react-icons/md";
import { useDropzone } from "react-dropzone";
import { jobApplyApi } from "@/utils/api";
import { userSignUpData } from "@/redux/reducer/authSlice";
import { useSelector } from "react-redux";

const ApplyJobModal = ({
  showApplyModal,
  setShowApplyModal,
  item_id,
  setProductDetails,
}) => {
  const userData = useSelector(userSignUpData);

  const [formData, setFormData] = useState({
    fullName: userData?.name || "",
    phoneNumber: userData?.mobile || "",
    email: userData?.email || "",
    resume: null,
  });

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [resumePreview, setResumePreview] = useState(null);

  // this is the useEffect to revoke the object url of the resume preview
  useEffect(() => {
    return () => {
      if (resumePreview?.url) {
        URL.revokeObjectURL(resumePreview.url);
      }
    };
  }, [resumePreview?.url]);

  const onDrop = useCallback((acceptedFiles) => {
    const file = acceptedFiles[0];
    if (file) {
      setFormData((prev) => ({
        ...prev,
        resume: file,
      }));

      // Create preview for PDF files
      if (file.type === "application/pdf") {
        const fileUrl = URL.createObjectURL(file);
        setResumePreview({
          url: fileUrl,
          isPdf: true,
          name: file.name,
        });
      } else {
        setResumePreview({
          url: null,
          isPdf: false,
          name: file.name,
        });
      }
    }
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      "application/pdf": [".pdf"],
      "application/msword": [".doc"],
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
        [".docx"],
    },
    maxFiles: 1,
    multiple: false,
  });

  const removeResume = () => {
    setFormData((prev) => ({
      ...prev,
      resume: null,
    }));
    if (resumePreview?.url) {
      URL.revokeObjectURL(resumePreview.url);
    }
    setResumePreview(null);
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      // Create form data object to send
      const data = {
        full_name: formData.fullName,
        mobile: formData.phoneNumber,
        email: formData.email,
        item_id: item_id,
      };

      // Only include resume if it's available
      if (formData.resume) {
        data.resume = formData.resume;
      }
      setIsSubmitting(true);
      const res = await jobApplyApi.jobApply(data);
      if (res?.data?.error === false) {
        toast.success(res?.data?.message);
        setProductDetails((prev) => ({
          ...prev,
          is_already_job_applied: true,
        }));
        setShowApplyModal(false);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={showApplyModal} onOpenChange={setShowApplyModal}>
      <DialogContent
        className="max-w-md sm:max-w-lg"
        onInteractOutside={(e) => e.preventDefault()}
      >
        <DialogHeader>
          <DialogTitle className="text-xl font-semibold">
            {t("applyNow")}
          </DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Full Name */}
          <div className="labelInputCont">
            <Label htmlFor="fullName" className="requiredInputLabel">
              {t("fullName")}
            </Label>
            <Input
              id="fullName"
              name="fullName"
              type="text"
              placeholder={t("enterFullName")}
              value={formData.fullName}
              onChange={handleInputChange}
              required
            />
          </div>

          {/* Phone Number */}
          <div className="labelInputCont">
            <Label htmlFor="phoneNumber" className="requiredInputLabel">
              {t("phoneNumber")}
            </Label>
            <Input
              id="phoneNumber"
              name="phoneNumber"
              type="tel"
              placeholder={t("enterPhoneNumber")}
              value={formData.phoneNumber}
              onChange={handleInputChange}
              required
              pattern="[0-9]*"
              inputMode="numeric"
            />
          </div>

          {/* Email */}
          <div className="labelInputCont">
            <Label htmlFor="email" className="requiredInputLabel">
              {t("email")}
            </Label>
            <Input
              id="email"
              name="email"
              type="email"
              placeholder={t("enterEmail")}
              value={formData.email}
              onChange={handleInputChange}
              required
            />
          </div>

          {/* Resume Upload */}
          <div className="labelInputCont">
            <Label>
              {t("resume")} ({t("optional")})
            </Label>
            <div className="space-y-2">
              {!resumePreview ? (
                <div
                  {...getRootProps()}
                  className={`border-2 border-dashed rounded-lg p-6 text-center transition-all duration-200 cursor-pointer hover:border-primary hover:bg-muted ${
                    isDragActive ? "border-primary bg-muted" : ""
                  }`}
                >
                  <input {...getInputProps()} />
                  <HiOutlineUpload className="mx-auto h-8 w-8 text-muted-foreground mb-2" />
                  <p className="text-sm text-muted-foreground">
                    {isDragActive
                      ? t("dropResumeHere")
                      : t("dragAndDropResume")}
                  </p>
                  <p className="text-sm text-gray-600">{t("clickToSelect")}</p>
                  <p className="text-xs text-gray-500 mt-1">PDF, DOC, DOCX</p>
                </div>
              ) : (
                <div className="border rounded-lg p-3 bg-gray-50">
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center space-x-2">
                      <MdOutlineAttachFile className="h-5 w-5 shrink-0 text-muted-foreground" />
                      <span className="text-sm font-medium text-muted-foreground break-all text-balance">
                        {resumePreview.name}
                      </span>
                    </div>
                    <button
                      type="button"
                      onClick={removeResume}
                      className="text-red-500 hover:text-red-700 text-sm"
                    >
                      {t("remove")}
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Submit Button */}
          <div className="flex gap-3 pt-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => setShowApplyModal(false)}
              className="flex-1"
              disabled={isSubmitting}
            >
              {t("cancel")}
            </Button>
            <Button type="submit" disabled={isSubmitting} className="flex-1">
              {isSubmitting ? t("submitting") : t("submit")}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
};

export default ApplyJobModal;
