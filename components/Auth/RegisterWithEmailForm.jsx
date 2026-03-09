import { useState } from "react";
import { FaRegEye, FaRegEyeSlash } from "react-icons/fa";
import { Label } from "../ui/label";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import { Loader2 } from "lucide-react";
import { toast } from "sonner";
import { handleFirebaseAuthError, t } from "@/utils";
import {
  createUserWithEmailAndPassword,
  getAuth,
  sendEmailVerification,
} from "firebase/auth";
import { userSignUpApi } from "@/utils/api";
import useAutoFocus from "../Common/useAutoFocus";

const RegisterWithEmailForm = ({ OnHide, setIsMailSentSuccess }) => {
  const auth = getAuth();
  const emailRef = useAutoFocus();

  // Form state management
  const [formData, setFormData] = useState({
    email: "",
    username: "",
    password: "",
    IsPasswordVisible: false,
    showLoader: false,
  });

  const { email, username, password, IsPasswordVisible, showLoader } = formData;

  // Handle input changes
  const handleInputChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  // Toggle password visibility
  const togglePasswordVisibility = () => {
    setFormData((prev) => ({
      ...prev,
      IsPasswordVisible: !prev.IsPasswordVisible,
    }));
  };

  // Handle form submission
  const handleSignup = async (e) => {
    e.preventDefault();

    // Validate email
    if (!email) {
      toast.error(t("emailRequired"));
      return;
    } else if (!/\S+@\S+\.\S+/.test(email)) {
      toast.error(t("emailInvalid"));
      return;
    }

    // Validate username
    if (username?.trim() === "") {
      toast.error(t("usernameRequired"));
      return;
    }

    // Validate password
    if (!password) {
      toast.error(t("passwordRequired"));
      return;
    } else if (password.length < 6) {
      toast.error(t("passwordTooShort"));
      return;
    }

    try {
      setFormData((prev) => ({ ...prev, showLoader: true }));

      // Create user with email and password
      const userCredential = await createUserWithEmailAndPassword(
        auth,
        email,
        password
      );
      const user = userCredential.user;

      // Send email verification
      await sendEmailVerification(user);

      // Register user in backend
      try {
        const response = await userSignUpApi.userSignup({
          name: username ? username : "",
          email: email ? email : "",
          firebase_id: user?.uid,
          type: "email",
          registration: true,
        });

        // Close modal and show success message
        OnHide();
        setIsMailSentSuccess(true);
      } catch (error) {
        console.log("error", error);
        toast.error(t("registrationFailed"));
      }
    } catch (error) {
      const errorCode = error.code;
      console.log(error);
      handleFirebaseAuthError(errorCode);
    } finally {
      setFormData((prev) => ({ ...prev, showLoader: false }));
    }
  };

  return (
    <form className="flex flex-col gap-6" onSubmit={handleSignup}>
      {/* Email Input */}
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("email")}</Label>
        <Input
          type="email"
          placeholder={t("enterEmail")}
          value={email}
          onChange={(e) => handleInputChange("email", e.target.value)}
          ref={emailRef}
          required
        />
      </div>

      {/* Username Input */}
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("username")}</Label>
        <Input
          type="text"
          placeholder={t("typeUsername")}
          value={username}
          onChange={(e) => handleInputChange("username", e.target.value)}
          required
        />
      </div>

      {/* Password Input */}
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("password")}</Label>
        <div className="flex items-center relative">
          <Input
            type={IsPasswordVisible ? "text" : "password"}
            placeholder={t("enterPassword")}
            className="ltr:pr-9 rtl:pl-9"
            value={password}
            onChange={(e) => handleInputChange("password", e.target.value)}
            required
          />
          <button
            type="button"
            className="absolute ltr:right-3 rtl:left-3 cursor-pointer"
            onClick={togglePasswordVisibility}
          >
            {IsPasswordVisible ? (
              <FaRegEye size={20} />
            ) : (
              <FaRegEyeSlash size={20} />
            )}
          </button>
        </div>
      </div>

      {/* Submit Button */}
      <Button
        type="submit"
        disabled={showLoader}
        className="text-xl text-white font-light px-4 py-2"
        size="big"
      >
        {showLoader ? (
          <Loader2 className="size-4 animate-spin" />
        ) : (
          t("verifyEmail")
        )}
      </Button>
    </form>
  );
};

export default RegisterWithEmailForm;