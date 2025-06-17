import { userSignUpData } from "@/redux/reuducer/authSlice"
import { t } from "@/utils"
import { jobApplyApi } from "@/utils/api"
import { Modal } from "antd"
import { useRef, useState } from "react"
import toast from "react-hot-toast"
import { MdClose } from "react-icons/md"
import { useSelector } from "react-redux"


const ApplyJobModal = ({ showApplyModal, OnHide, item_id, setProductData }) => {
  const CloseIcon = (
    <div className="close_icon_cont">
      <MdClose size={24} color="black" />
    </div>
  );
  const fileInputRef = useRef(null);
  const [IsApplying, setIsApplying] = useState(false);
  const userData = useSelector(userSignUpData);
  const [formData, setFormData] = useState({
    fullName: userData?.name || "",
    mobile: userData?.mobile || "",
    email: userData?.email || "",
    resume: null,
  });

  const resetForm = () => {
    setFormData({
      fullName: "",
      mobile: "",
      email: "",
      resume: null,
    });
    // Reset the file input element
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handlePhoneChange = (e) => {
    const { value } = e.target;
    // Only allow numeric input
    const numericValue = value.replace(/\D/g, "");
    setFormData((prev) => ({
      ...prev,
      mobile: numericValue,
    }));
  };

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setFormData((prev) => ({
        ...prev,
        resume: file,
      }));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      // Create form data object to send
      const data = {
        full_name: formData.fullName,
        mobile: formData.mobile,
        email: formData.email,
        item_id: item_id,
      };

      // Only include resume if it's available
      if (formData.resume) {
        data.resume = formData.resume;
      }
      setIsApplying(true);
      const res = await jobApplyApi.jobApply(data);
      if (res?.data?.error === false) {
        toast.success(t("applicationSubmitted"));
        setProductData((prev) => ({ ...prev, is_already_job_applied: true}));
        resetForm();
        OnHide(); // Close modal after successful submission
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsApplying(false);
    }
  };

  return (
    <Modal
      centered
      open={showApplyModal}
      closeIcon={CloseIcon}
      colorIconHover="transparent"
      className="ant_register_modal"
      onCancel={OnHide}
      footer={null}
      maskClosable={false}
    >
      <h5 className="head_loc">{t("applyNow")}</h5>
      <form onSubmit={handleSubmit} className="applyJobForm">
        <div className="applyJobField">
          <label htmlFor="fullName" className="auth_label">
            {t("fullName")}
          </label>
          <input
            type="text"
            id="fullName"
            name="fullName"
            value={formData.fullName}
            onChange={handleChange}
            placeholder={t("enterFullName")}
            required
          />
        </div>

        <div className="applyJobField">
          <label htmlFor="mobile" className="auth_label">
            {t("phoneNumber")}
          </label>
          <input
            type="tel"
            id="mobile"
            name="mobile"
            value={formData.mobile}
            onChange={handlePhoneChange}
            placeholder={t("enterPhoneNumber")}
            required
            pattern="[0-9]*"
            inputMode="numeric"
          />
        </div>

        <div className="applyJobField">
          <label htmlFor="email" className="auth_label">
            {t("emailAddress")}
          </label>
          <input
            type="email"
            id="email"
            name="email"
            value={formData.email}
            onChange={handleChange}
            placeholder={t("enterEmailAddress")}
            required
          />
        </div>

        <div className="applyJobField">
          <label htmlFor="resume" className="auth_pers_label">
            {t("resume")}
          </label>
          <input
            type="file"
            id="resume"
            name="resume"
            onChange={handleFileChange}
            accept=".pdf,.doc,.docx"
            className="resumeFileInput"
            ref={fileInputRef}
          />
          <small>
            {t("allowedFileTypes")} ({t("optional")})
          </small>
        </div>

        <button type="submit" className="applyJobButton" disabled={IsApplying}>
          {IsApplying ? t("submitting") : t("submit")}
        </button>
      </form>
    </Modal>
  );
};

export default ApplyJobModal