import { getAuth, signInWithPhoneNumber } from "firebase/auth";
import useAutoFocus from "../Common/useAutoFocus";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { toast } from "sonner";
import { handleFirebaseAuthError, t } from "@/utils";
import { getOtpApi, userSignUpApi, verifyOtpApi } from "@/utils/api";
import { loadUpdateData } from "@/redux/reducer/authSlice";
import { useSelector } from "react-redux";
import { Fcmtoken, getOtpServiceProvider } from "@/redux/reducer/settingSlice";
import { Loader2 } from "lucide-react";
import { useEffect, useState } from "react";
import { useNavigate } from "../Common/useNavigate";

const OtpScreen = ({
  generateRecaptcha,
  countryCode,
  formattedNumber,
  confirmationResult,
  setConfirmationResult,
  OnHide,
  resendTimer,
  setResendTimer,
  regionCode,
  isDemoMode,
  isRegister = false,
  onOtpVerified,
  password
}) => {
  const { navigate } = useNavigate();
  const otpInputRef = useAutoFocus();
  const fetchFCM = useSelector(Fcmtoken);
  const auth = getAuth();
  const [resendOtpLoader, setResendOtpLoader] = useState(false);
  const [showLoader, setShowLoader] = useState(false);
  const [otp, setOtp] = useState(isDemoMode && !isRegister ? "123456" : "");
  const otp_service_provider = useSelector(getOtpServiceProvider);

  useEffect(() => {
    let intervalId;
    if (resendTimer > 0) {
      intervalId = setInterval(() => {
        setResendTimer((prevTimer) => prevTimer - 1);
      }, 1000);
    }

    return () => {
      if (intervalId) clearInterval(intervalId);
    };
  }, [resendTimer]);

  const verifyOTPWithTwillio = async () => {
    try {

      const payload = {
        number: formattedNumber,
        country_code: countryCode,
        otp: otp,
      }

      if (isRegister && password) {
        payload.password = password;
      }

      const response = await verifyOtpApi.verifyOtp(payload);
      if (response?.data?.error === false) {
        // If callback provided, use it (for forgot password)
        if (onOtpVerified) {
          onOtpVerified();
          return;
        }
        // Otherwise, do normal login
        loadUpdateData(response?.data);
        toast.success(response?.data?.message);
        if (
          response?.data?.data?.email === "" ||
          response?.data?.data?.name === ""
        ) {
          navigate("/profile");
        }
        OnHide();
      } else {
        toast.error(response?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setShowLoader(false);
    }
  };

  const verifyOTPWithFirebase = async () => {
    try {
      const result = await confirmationResult.confirm(otp);
      // Access user information from the result
      const user = result.user;

      const firebase_id = user?.uid;

      // If callback provided, use it (for forgot password)
      if (onOtpVerified) {
        onOtpVerified(firebase_id);
        return;
      }

      const payload = {
        mobile: formattedNumber,
        firebase_id: user.uid, // Accessing UID directly from the user object
        fcm_id: fetchFCM ? fetchFCM : "",
        country_code: countryCode,
        type: "phone",
        region_code: regionCode?.toUpperCase() || "",
      }

      if (isRegister && password) {
        payload.password = password;
      }

      // Otherwise, do normal login
      const response = await userSignUpApi.userSignup(payload);
      const data = response.data;
      loadUpdateData(data);
      toast.success(data.message);
      OnHide();
      if (data?.data?.email === "" || data?.data?.name === "") {
        navigate("/profile");
      }
    } catch (error) {
      console.log(error);
      const errorCode = error?.code;
      handleFirebaseAuthError(errorCode);
    } finally {
      setShowLoader(false);
    }
  };

  const verifyOTP = async (e) => {
    e.preventDefault();
    if (otp === "") {
      toast.error(t("otpmissing"));
      return;
    }
    setShowLoader(true);
    if (otp_service_provider === "twilio") {
      await verifyOTPWithTwillio();
    } else {
      await verifyOTPWithFirebase();
    }
  };

  const resendOtpWithTwillio = async () => {
    try {
      const response = await getOtpApi.getOtp({ number: formattedNumber, country_code: countryCode });
      if (response?.data?.error === false) {
        toast.success(t("otpSentSuccess"));
        setResendTimer(60); // Start the 60-second timer
      } else {
        toast.error(t("failedToSendOtp"));
      }
    } catch (error) {
      console.log(error);
    } finally {
      setResendOtpLoader(false);
    }
  };

  const resendOtpWithFirebase = async (PhoneNumber) => {
    try {
      const appVerifier = await generateRecaptcha();
      const confirmation = await signInWithPhoneNumber(
        auth,
        PhoneNumber,
        appVerifier
      );
      setConfirmationResult(confirmation);
      toast.success(t("otpSentSuccess"));
    } catch (error) {
      const errorCode = error.code;
      handleFirebaseAuthError(errorCode);
    } finally {
      setResendOtpLoader(false);
    }
  };

  const resendOtp = async (e) => {
    e.preventDefault();
    setResendOtpLoader(true);
    const PhoneNumber = `${countryCode}${formattedNumber}`;
    if (otp_service_provider === "twilio") {
      await resendOtpWithTwillio();
    } else {
      await resendOtpWithFirebase(PhoneNumber);
    }
  };

  return (
    <form className="flex flex-col gap-6" onSubmit={verifyOTP}>
      <div className="labelInputCont">
        <Label className="requiredInputLabel">{t("otp")}</Label>
        <Input
          type="text"
          placeholder={t("enterOtp")}
          id="otp"
          name="otp"
          value={otp}
          maxLength={6}
          onChange={(e) => setOtp(e.target.value)}
          ref={otpInputRef}
        />
      </div>
      <Button
        type="submit"
        disabled={showLoader}
        className="text-xl text-white font-light px-4 py-2"
        size="big"
      >
        {showLoader ? (
          <Loader2 className="w-4 h-4 animate-spin" />
        ) : (
          t("verify")
        )}
      </Button>

      <Button
        type="button"
        className="text-lg text-black font-light bg-transparent"
        size="big"
        onClick={resendOtp}
        disabled={resendOtpLoader || showLoader || resendTimer > 0}
      >
        {resendOtpLoader ? (
          <Loader2 className="size-6 animate-spin" />
        ) : resendTimer > 0 ? (
          `${t("resendOtp")} ${resendTimer}s`
        ) : (
          t("resendOtp")
        )}
      </Button>
    </form>
  );
};

export default OtpScreen;
