import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Loader2 } from "lucide-react";
import { FaRegEye, FaRegEyeSlash } from "react-icons/fa";
import { toast } from "sonner";
import { t } from "@/utils";
import { resetPasswordApi, userSignUpApi } from "@/utils/api";
import { useState } from "react";

const ResetPasswordScreen = ({
  formattedNumber,
  countryCode,
  onSuccess,
  onCancel,
  FirebaseId,
}) => {
  const [newPassword, setNewPassword] = useState("");
  const [isPasswordVisible, setIsPasswordVisible] = useState(false);
  const [resetPasswordLoader, setResetPasswordLoader] = useState(false);

  const handleResetPassword = async (e) => {
    e.preventDefault();

    if (!newPassword) {
      toast.error(t("passwordRequired"));
      return;
    }

    if (newPassword.length < 6) {
      toast.error(t("passwordTooShort"));
      return;
    }

    setResetPasswordLoader(true);
    try {
      // Step 1: Get token by calling userSignUpApi
      const loginResponse = await userSignUpApi.userSignup({
        mobile: formattedNumber,
        country_code: countryCode,
        type: "phone",
        firebase_id: FirebaseId,
      });

      // Extract token from response
      const token = loginResponse?.data?.token;

      if (!token) {
        toast.error(t("errorOccurred"));
        return;
      }

      const response = await resetPasswordApi.resetPassword({
        number: formattedNumber,
        country_code: countryCode,
        new_password: newPassword,
        token: token,
      });

      if (response?.data?.error === false) {
        toast.success(response?.data?.message);
        onSuccess(); // Go back to login screen
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
      toast.error(t("errorOccurred"));
    } finally {
      setResetPasswordLoader(false);
    }
  };

  return (
    <form className="flex flex-col gap-6 mt-3.5" onSubmit={handleResetPassword}>
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("newPassword")}</Label>
        <div className="flex items-center relative">
          <Input
            type={isPasswordVisible ? "text" : "password"}
            placeholder={t("enterNewPassword")}
            className="ltr:pr-9 rtl:pl-9"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            required
          />
          <button
            type="button"
            className="absolute ltr:right-3 rtl:left-3 cursor-pointer"
            onClick={() => setIsPasswordVisible(!isPasswordVisible)}
          >
            {isPasswordVisible ? (
              <FaRegEye size={20} />
            ) : (
              <FaRegEyeSlash size={20} />
            )}
          </button>
        </div>
      </div>
      <Button
        type="submit"
        disabled={resetPasswordLoader}
        className="text-xl text-white font-light px-4 py-2"
        size="big"
      >
        {resetPasswordLoader ? (
          <Loader2 className="size-6 animate-spin" />
        ) : (
          t("submitResetPassword")
        )}
      </Button>
      {onCancel && (
        <Button
          type="button"
          variant="outline"
          className="text-lg text-black font-light px-4 py-2"
          size="big"
          onClick={onCancel}
        >
          {t("cancel")}
        </Button>
      )}
    </form>
  );
};

export default ResetPasswordScreen;
