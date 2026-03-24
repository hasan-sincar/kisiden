import PhoneInput from "react-phone-input-2";
import { Label } from "../ui/label";
import { Button } from "../ui/button";
import useAutoFocus from "../Common/useAutoFocus";
import { Loader2 } from "lucide-react";
import { isValidPhoneNumber } from "libphonenumber-js/max";
import { toast } from "sonner";
import { t } from "@/utils";
import { Input } from "../ui/input";
import { useState } from "react";
import { FaRegEye, FaRegEyeSlash } from "react-icons/fa";
import { getUserExistsApi, userSignUpApi } from "@/utils/api";
import { Fcmtoken } from "@/redux/reducer/settingSlice";
import { useSelector } from "react-redux";
import { loadUpdateData } from "@/redux/reducer/authSlice";

const LoginWithMobileForm = ({
  loginStates,
  setLoginStates,
  formattedNumber,
  onForgotPassword,
  OnHide,
  setForgotPasswordLoading,
  forgotPasswordLoading,
  isLoadingWithGoogle,
  showLoader,
  setShowLoader
}) => {
  const numberInputRef = useAutoFocus();
  const { number, countryCode } = loginStates;
  const [isPasswordVisible, setIsPasswordVisible] = useState(false);
  const fcm_id = useSelector(Fcmtoken);

  const handleInputChange = (value, data) => {
    setLoginStates((prev) => ({
      ...prev,
      number: value,
      countryCode: "+" + (data?.dialCode || ""),
      regionCode: data?.countryCode.toLowerCase() || "",
    }));
  };

  const handleCountryChange = (code) => {
    setLoginStates((prev) => ({
      ...prev,
      countryCode: code,
    }));
  };

  const handleLoginWithMobile = async (e) => {
    e.preventDefault();
    try {
      if (!isValidPhoneNumber(`${countryCode}${formattedNumber}`)) {
        toast.error(t("invalidPhoneNumber"));
        return;
      }
      setShowLoader(true)
      const params = {
        mobile: formattedNumber,
        password: loginStates.password,
        country_code: countryCode,
        type: "phone",
        fcm_id: fcm_id ? fcm_id : "",
        is_login: 1,
      };
      const response = await userSignUpApi.userSignup(params);
      if (response?.data?.error === false) {
        toast.success(response?.data?.message);
        loadUpdateData(response?.data);
        OnHide();
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setShowLoader(false)
    }
  };


  const checkIfUserExistsOrNot = async () => {
    try {
      const res = await getUserExistsApi.getUserExists({
        mobile: formattedNumber,
        country_code: countryCode,
        forgot_password: 1
      })
      if (res?.data?.error === false) {
        return true
      } else {
        toast.error(res?.data?.message)
        return false
      }
    } catch (error) {
      console.log(error)
      return false;
    }
  }

  // NEW: Handle forgot password with loading state
  const handleForgotPasswordClick = async () => {
    if (!isValidPhoneNumber(`${countryCode}${formattedNumber}`)) {
      toast.error(t("invalidPhoneNumber"));
      return;
    }
    setForgotPasswordLoading(true);
    const isUserExists = await checkIfUserExistsOrNot()
    if (!isUserExists) {
      setForgotPasswordLoading(false);
      return;
    }
    await onForgotPassword();
    setForgotPasswordLoading(false);
  };

  return (
    <form className="flex flex-col gap-6" onSubmit={handleLoginWithMobile}>
      <div className="labelInputCont">
        <Label className="font-semibold after:content-['*'] after:text-red-500">
          {t("mobileNumber")}
        </Label>
        <PhoneInput
          country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
          value={number}
          onChange={(phone, data) => handleInputChange(phone, data)}
          onCountryChange={handleCountryChange}
          inputProps={{
            name: "phone",
            required: true,
            ref: numberInputRef,
          }}
          enableLongNumbers
        />
      </div>
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("password")}</Label>
        <div className="flex items-center relative">
          <Input
            type={isPasswordVisible ? "text" : "password"}
            placeholder={t("enterPassword")}
            className="ltr:pr-9 rtl:pl-9"
            value={loginStates.password}
            onChange={(e) =>
              setLoginStates((prev) => ({ ...prev, password: e.target.value }))
            }
            required
          />
          <button
            type="button"
            className="absolute ltr:right-3 rtl:left-3 cursor-pointer"
            onClick={() => setIsPasswordVisible((prev) => !prev)}
          >
            {isPasswordVisible ? (
              <FaRegEye size={20} />
            ) : (
              <FaRegEyeSlash size={20} />
            )}
          </button>
        </div>
        <button
          className="text-right font-semibold text-primary w-fit self-end"
          onClick={handleForgotPasswordClick}
          type="button"
          disabled={forgotPasswordLoading || showLoader || isLoadingWithGoogle}
        >
          {forgotPasswordLoading ? (
            <>
              <span className="flex items-center gap-2 justify-end">
                <Loader2 className="size-4 animate-spin" />
                <span>{t("loading")}</span>
              </span>
            </>
          ) : (
            t("forgtPassword")
          )}
        </button>
      </div>
      <Button
        type="submit"
        disabled={showLoader || forgotPasswordLoading || isLoadingWithGoogle}
        className="text-xl text-white font-light px-4 py-2"
        size="big"
      >
        {showLoader ? <Loader2 className="!size-6 animate-spin" /> : t("login")}
      </Button>
    </form>
  );
};

export default LoginWithMobileForm;
