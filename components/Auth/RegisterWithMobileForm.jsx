import { useEffect, useState } from "react";
import PhoneInput from "react-phone-input-2";
import "react-phone-input-2/lib/style.css";
import { Label } from "../ui/label";
import { Button } from "../ui/button";
import { Loader2 } from "lucide-react";
import { isValidPhoneNumber } from "libphonenumber-js/max";
import { toast } from "sonner";
import { handleFirebaseAuthError, t } from "@/utils";
import {
  getAuth,
  RecaptchaVerifier,
  signInWithPhoneNumber,
} from "firebase/auth";
import { getOtpApi, getUserExistsApi } from "@/utils/api";
import { useSelector } from "react-redux";
import {
  getOtpServiceProvider,
  settingsData,
} from "@/redux/reducer/settingSlice";
import useAutoFocus from "../Common/useAutoFocus";
import OtpScreen from "./OtpScreen";
import { Input } from "../ui/input";
import { FaRegEye, FaRegEyeSlash } from "react-icons/fa";

const RegisterWithMobileForm = ({
  OnHide,
  setDescriptionState,
  isOTPScreen,
  setIsOTPScreen,
}) => {
  const auth = getAuth();
  const settings = useSelector(settingsData);
  const isDemoMode = settings?.demo_mode;
  const otp_service_provider = useSelector(getOtpServiceProvider);
  const phoneInputRef = useAutoFocus();

  // Mobile registration states
  const [number, setNumber] = useState(isDemoMode ? "919876598765" : "");
  const [countryCode, setCountryCode] = useState("");
  const [regionCode, setRegionCode] = useState("");
  const [confirmationResult, setConfirmationResult] = useState(null);
  const [showLoader, setShowLoader] = useState(false);
  const [resendTimer, setResendTimer] = useState(0);
  const [isPasswordVisible, setIsPasswordVisible] = useState(false);
  const [password, setPassword] = useState("");

  // Remove any non-digit characters from the country code
  const countryCodeDigitsOnly = countryCode.replace(/\D/g, "");

  // Check if the entered number starts with the selected country code
  const startsWithCountryCode = number.startsWith(countryCodeDigitsOnly);

  // If the number starts with the country code, remove it
  const formattedNumber = startsWithCountryCode
    ? number.substring(countryCodeDigitsOnly.length)
    : number;

  // Generate reCAPTCHA verifier
  const generateRecaptcha = async () => {
    // Reuse existing verifier if it's still valid
    if (window.recaptchaVerifier && !window.recaptchaVerifier.destroyed) {
      return window.recaptchaVerifier;
    }
    const recaptchaContainer = document.getElementById("recaptcha-container");
    if (!recaptchaContainer) {
      console.error("Container element 'recaptcha-container' not found.");
      return null;
    }
    // Clear container and reset reference
    recaptchaContainer.innerHTML = "";
    window.recaptchaVerifier = undefined;
    try {
      window.recaptchaVerifier = new RecaptchaVerifier(
        auth,
        recaptchaContainer,
        { size: "invisible" }
      );
      return window.recaptchaVerifier;
    } catch (error) {
      console.error("Error initializing RecaptchaVerifier:", error.message);
      return null;
    }
  };

  useEffect(() => {
    return () => {
      recaptchaClear();
    };
  }, []);

  const recaptchaClear = async () => {
    if (window.recaptchaVerifier && !window.recaptchaVerifier.destroyed) {
      try {
        await window.recaptchaVerifier.clear();
      } catch (error) {
        // Ignore errors - verifier might already be cleared
      }
    }
    window.recaptchaVerifier = undefined;
    const recaptchaContainer = document.getElementById("recaptcha-container");
    if (recaptchaContainer) {
      recaptchaContainer.innerHTML = "";
    }
  };

  // Send OTP with Twilio
  const sendOtpWithTwillio = async (PhoneNumber) => {
    try {
      const response = await getOtpApi.getOtp({
        number: formattedNumber,
        country_code: countryCode,
      });
      if (response?.data?.error === false) {
        toast.success(t("otpSentSuccess"));
        setIsOTPScreen(true);
        setResendTimer(60);
        setDescriptionState({
          type: "otp",
          phoneNumber: PhoneNumber,
        });
      } else {
        toast.error(t("failedToSendOtp"));
      }
    } catch (error) {
      console.error("error", error);
    } finally {
      setShowLoader(false);
    }
  };

  // Send OTP with Firebase
  const sendOtpWithFirebase = async (PhoneNumber) => {
    try {
      const appVerifier = await generateRecaptcha();
      const confirmation = await signInWithPhoneNumber(
        auth,
        PhoneNumber,
        appVerifier
      );
      setConfirmationResult(confirmation);
      toast.success(t("otpSentSuccess"));
      setIsOTPScreen(true);
      setResendTimer(60);
      setDescriptionState({
        type: "otp",
        phoneNumber: PhoneNumber,
      });
    } catch (error) {
      console.log(error);
      const errorCode = error.code;
      handleFirebaseAuthError(errorCode);
    } finally {
      setShowLoader(false);
    }
  };

  // Handle phone input change
  const handleInputChange = (value, data) => {
    setNumber(value);
    setCountryCode("+" + (data?.dialCode || ""));
    setRegionCode(data?.countryCode.toLowerCase() || "");
  };

  // Handle country change
  const handleCountryChange = (code) => {
    setCountryCode(code);
  };

  const checkIfUserExistsOrNot = async () => {
    try {
      const res = await getUserExistsApi.getUserExists({
        mobile: formattedNumber,
        country_code: countryCode,
      });
      if (res?.data?.error === false) {
        toast.error(res?.data?.message);
        return true;
      } else {
        return false;
      }
    } catch (error) {
      console.log(error);
      return false;
    }
  };

  // Handle form submission
  const handleMobileSubmit = async (e) => {
    e.preventDefault();

    // Validate phone number
    const PhoneNumber = `${countryCode}${formattedNumber}`;

    if (!isValidPhoneNumber(PhoneNumber)) {
      toast.error(t("invalidPhoneNumber"));
      return;
    }

    // Validate password
    if (!password) {
      toast.error(t("passwordRequired"));
      return;
    }
    if (password.length < 6) {
      toast.error(t("passwordTooShort"));
      return;
    }
    // Send OTP
    setShowLoader(true);
    const isUserExists = await checkIfUserExistsOrNot();
    if (isUserExists) {
      setShowLoader(false);
      return;
    }
    if (otp_service_provider === "twilio") {
      await sendOtpWithTwillio(PhoneNumber);
    } else {
      await sendOtpWithFirebase(PhoneNumber);
    }
  };

  // Toggle password visibility
  const togglePasswordVisibility = () => {
    setIsPasswordVisible((prev) => !prev);
  };

  // Show OTP screen if OTP was sent
  if (isOTPScreen) {
    return (
      <OtpScreen
        OnHide={OnHide}
        generateRecaptcha={generateRecaptcha}
        countryCode={countryCode}
        formattedNumber={formattedNumber}
        confirmationResult={confirmationResult}
        setConfirmationResult={setConfirmationResult}
        setResendTimer={setResendTimer}
        resendTimer={resendTimer}
        regionCode={regionCode}
        password={password}
        isDemoMode={isDemoMode}
        isRegister={true}
        key="register-otp"
      />
    );
  }

  // Show mobile registration form
  return (
    <form className="flex flex-col gap-6" onSubmit={handleMobileSubmit}>
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("phoneNumber")}</Label>
        <PhoneInput
          country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
          value={number}
          onChange={(phone, data) => handleInputChange(phone, data)}
          onCountryChange={handleCountryChange}
          inputProps={{
            name: "phone",
            required: true,
            ref: phoneInputRef,
          }}
          enableLongNumbers
        />
      </div>

      {/* Password Input */}
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("password")}</Label>
        <div className="flex items-center relative">
          <Input
            type={isPasswordVisible ? "text" : "password"}
            placeholder={t("enterPassword")}
            className="ltr:pr-9 rtl:pl-9"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button
            type="button"
            className="absolute ltr:right-3 rtl:left-3 cursor-pointer"
            onClick={togglePasswordVisibility}
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
        disabled={showLoader}
        className="text-xl text-white font-light px-4 py-2"
        size="big"
      >
        {showLoader ? (
          <Loader2 className="size-4 animate-spin" />
        ) : (
          t("continue")
        )}
      </Button>
    </form>
  );
};

export default RegisterWithMobileForm;
