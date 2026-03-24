"use client";
import { formatPhoneNumber, handleFirebaseAuthError, t } from "@/utils";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "../ui/dialog";
import { useEffect, useState } from "react";
import { useSelector } from "react-redux";
import {
  Fcmtoken,
  getIsDemoMode,
  getOtpServiceProvider,
  settingsData,
} from "@/redux/reducer/settingSlice";
import "react-phone-input-2/lib/style.css";
import { Button } from "../ui/button";
import { FcGoogle } from "react-icons/fc";
import { MdOutlineEmail, MdOutlineLocalPhone } from "react-icons/md";
import {
  getAuth,
  GoogleAuthProvider,
  RecaptchaVerifier,
  signInWithPhoneNumber,
  signInWithPopup,
} from "firebase/auth";
import { toast } from "sonner";
import { getOtpApi, userSignUpApi } from "@/utils/api";
import { loadUpdateData } from "@/redux/reducer/authSlice";
import LoginWithEmailForm from "./LoginWithEmailForm";
import LoginWithMobileForm from "./LoginWithMobileForm";
import OtpScreen from "./OtpScreen";
import TermsAndPrivacyLinks from "./TermsAndPrivacyLinks";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import ResetPasswordScreen from "./ResetPasswordScreen";
import { Loader2 } from "lucide-react";

const LoginModal = ({ IsLoginOpen, setIsRegisterModalOpen }) => {
  const settings = useSelector(settingsData);
  const auth = getAuth();
  const fetchFCM = useSelector(Fcmtoken);
  const isDemoMode = useSelector(getIsDemoMode);
  const [IsOTPScreen, setIsOTPScreen] = useState(null);
  const [resendTimer, setResendTimer] = useState(0);
  const [loginStates, setLoginStates] = useState({
    number: isDemoMode ? "919876598765" : "",
    countryCode: isDemoMode ? "+91" : '',
    regionCode: "",
    password: isDemoMode ? "123456" : "",
  });
  const [forgotPasswordLoading, setForgotPasswordLoading] = useState(false);
  const [isLoadingWithGoogle, setIsLoadingWithGoogle] = useState(false)
  const [showLoader, setShowLoader] = useState(false)

  const [confirmationResult, setConfirmationResult] = useState(null);
  const [FirebaseId, setFirebaseId] = useState("");
  const { number, countryCode } = loginStates;
  const formattedNumber = formatPhoneNumber(number, countryCode);

  const otp_service_provider = useSelector(getOtpServiceProvider);

  // Active authentication methods
  const mobile_authentication = Number(settings?.mobile_authentication);
  const google_authentication = Number(settings?.google_authentication);
  const email_authentication = Number(settings?.email_authentication);

  const [IsLoginWithEmail, setIsLoginWithEmail] = useState(
    mobile_authentication === 0 && email_authentication === 1 ? true : false
  );

  const IsShowOrSignIn =
    !(
      mobile_authentication === 0 &&
      email_authentication === 0 &&
      google_authentication === 1
    ) && google_authentication === 1;

  const OnHide = async () => {
    setIsOTPScreen(null);
    setIsLoginOpen(false);
    setConfirmationResult(null);
    setResendTimer(0);
  };

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

  const handleGoogleSignup = async () => {
    const provider = new GoogleAuthProvider();
    try {
      setIsLoadingWithGoogle(true)
      const res = await signInWithPopup(auth, provider);
      const user = res.user;
      try {
        const response = await userSignUpApi.userSignup({
          name: user.displayName ? user.displayName : "",
          email: user?.email,
          firebase_id: user?.uid, // Accessing UID directly from the user object
          fcm_id: fetchFCM ? fetchFCM : "",
          type: "google",
        });

        const data = response.data;
        if (data.error === true) {
          toast.error(data.message);
        } else {
          loadUpdateData(data);
          toast.success(data.message);
        }
        OnHide();
      } catch (error) {
        console.error("Error:", error);
        toast.error("Failed to complete signup");
      }
    } catch (error) {
      const errorCode = error.code;
      handleFirebaseAuthError(errorCode);
    } finally {
      setIsLoadingWithGoogle(false)
    }
  };

  const handleCreateAnAccount = () => {
    OnHide();
    setIsRegisterModalOpen(true);
  };

  // Handle forgot password - send OTP and show OTP screen
  const handleForgotPassword = async () => {
    const PhoneNumber = `${loginStates.countryCode}${formattedNumber}`;
    if (otp_service_provider === "twilio" || otp_service_provider === "2factor") {
      try {
        const response = await getOtpApi.getOtp({ number: formattedNumber, country_code: countryCode });
        if (response?.data?.error === false) {
          toast.success(t("otpSentSuccess"));
          setResendTimer(60);
          setIsOTPScreen("otp");
        } else {
          toast.error(t("failedToSendOtp"));
        }
      } catch (error) {
        console.log(error);
      }
    } else {
      try {
        const appVerifier = await generateRecaptcha();
        const confirmation = await signInWithPhoneNumber(
          auth,
          PhoneNumber,
          appVerifier
        );
        setConfirmationResult(confirmation);
        toast.success(t("otpSentSuccess"));
        setResendTimer(60);
        setIsOTPScreen("otp");
      } catch (error) {

        console.log(error)

        handleFirebaseAuthError(error.code);
      }
    }
  };

  // Handle OTP verification success - move to reset password screen
  const handleForgotPasswordOtpVerified = (firebase_id) => {
    setFirebaseId(firebase_id);
    setIsOTPScreen("reset");
    toast.success(t("otpVerified"));
  };

  // Handle successful password reset - go back to login
  const handleResetPasswordSuccess = () => {
    setIsOTPScreen(null);
    setConfirmationResult(null);
    setResendTimer(0);
  };

  return (
    <>
      <Dialog open={IsLoginOpen} onOpenChange={setIsLoginOpen}>
        <DialogContent
          onInteractOutside={(e) => e.preventDefault()}
          className="px-[40px] sm:py-[50px] sm:px-[90px]"
        >
          <DialogHeader>
            <DialogTitle className="text-3xl sm:text-4xl font-light">
              {IsOTPScreen === "otp" ? (
                t("verifyOtp")
              ) : IsOTPScreen === "reset" ? (
                t("resetYourPassword")
              ) : (
                <>
                  {t("loginTo")}{" "}
                  <span className="text-primary">{settings?.company_name}</span>
                </>
              )}
            </DialogTitle>
            <DialogDescription className="text-base text-black font-light">
              {IsOTPScreen === "otp" ? (
                <>
                  {t("sentTo")} {`${countryCode}${formattedNumber}`}{" "}
                  <span
                    onClick={() => setIsOTPScreen(false)}
                    className="text-primary underline cursor-pointer"
                  >
                    {t("change")}
                  </span>
                </>
              ) : IsOTPScreen === "reset" ? (
                t("enterNewPassword")
              ) : (
                <>
                  {t("newto")} {settings?.company_name}?{" "}
                  <span
                    className="text-primary cursor-pointer underline"
                    onClick={handleCreateAnAccount}
                  >
                    {t("createAccount")}
                  </span>
                </>
              )}
            </DialogDescription>
          </DialogHeader>

          {IsOTPScreen === "otp" ? (
            <OtpScreen
              OnHide={OnHide}
              generateRecaptcha={generateRecaptcha}
              countryCode={countryCode}
              formattedNumber={formattedNumber}
              confirmationResult={confirmationResult}
              setConfirmationResult={setConfirmationResult}
              resendTimer={resendTimer}
              setResendTimer={setResendTimer}
              regionCode={loginStates.regionCode}
              isDemoMode={isDemoMode}
              onOtpVerified={handleForgotPasswordOtpVerified}
              key="forgot-password-otp"
            />
          ) : IsOTPScreen === "reset" ? (
            <ResetPasswordScreen
              FirebaseId={FirebaseId}
              formattedNumber={formattedNumber}
              countryCode={loginStates.countryCode}
              onSuccess={handleResetPasswordSuccess}
              onCancel={() => setIsOTPScreen(null)}
            />
          ) : (
            <div className="flex flex-col gap-[30px] mt-3.5">
              {!(
                mobile_authentication === 0 &&
                email_authentication === 0 &&
                google_authentication === 1
              ) &&
                mobile_authentication === 1 &&
                email_authentication === 1 &&
                (IsLoginWithEmail ? (
                  <LoginWithEmailForm OnHide={OnHide} key={IsLoginWithEmail} forgotPasswordLoading={forgotPasswordLoading} setForgotPasswordLoading={setForgotPasswordLoading} showLoader={showLoader} setShowLoader={setShowLoader} isLoadingWithGoogle={isLoadingWithGoogle} />
                ) : (
                  <LoginWithMobileForm
                    formattedNumber={formattedNumber}
                    loginStates={loginStates}
                    setLoginStates={setLoginStates}
                    onForgotPassword={handleForgotPassword}
                    OnHide={OnHide}
                    key={IsLoginWithEmail}
                    forgotPasswordLoading={forgotPasswordLoading}
                    setForgotPasswordLoading={setForgotPasswordLoading}
                    isLoadingWithGoogle={isLoadingWithGoogle}
                    showLoader={showLoader}
                    setShowLoader={setShowLoader}
                  />
                ))}

              {email_authentication === 1 && mobile_authentication === 0 && (
                <LoginWithEmailForm OnHide={OnHide} key={IsLoginWithEmail} forgotPasswordLoading={forgotPasswordLoading} setForgotPasswordLoading={setForgotPasswordLoading} showLoader={showLoader} setShowLoader={setShowLoader} isLoadingWithGoogle={isLoadingWithGoogle} />
              )}

              {mobile_authentication === 1 && email_authentication === 0 && (
                <LoginWithMobileForm
                  OnHide={OnHide}
                  formattedNumber={formattedNumber}
                  loginStates={loginStates}
                  setLoginStates={setLoginStates}
                  onForgotPassword={handleForgotPassword}
                  key={IsLoginWithEmail}
                  forgotPasswordLoading={forgotPasswordLoading}
                  setForgotPasswordLoading={setForgotPasswordLoading}
                  isLoadingWithGoogle={isLoadingWithGoogle}
                />
              )}

              {IsShowOrSignIn && (
                <div className="flex items-center gap-2">
                  <hr className="w-full" />
                  <p className="text-nowrap text-sm">{t("orSignInWith")}</p>
                  <hr className="w-full" />
                </div>
              )}

              <div className="flex flex-col gap-4">
                {google_authentication === 1 && (
                  <Button
                    variant="outline"
                    size="big"
                    className="flex items-center justify-center py-4 text-base"
                    onClick={handleGoogleSignup}
                    disabled={isLoadingWithGoogle || showLoader || forgotPasswordLoading}
                  >
                    {
                      isLoadingWithGoogle ? <Loader2 className="!size-6 animate-spin" /> : <FcGoogle className="!size-6" />
                    }
                    <span>{t("continueWithGoogle")}</span>
                  </Button>
                )}

                {IsLoginWithEmail && mobile_authentication === 1 ? (
                  <Button
                    variant="outline"
                    size="big"
                    className="flex items-center justify-center py-4 text-base h-auto"
                    onClick={() => setIsLoginWithEmail(false)}
                    disabled={showLoader || forgotPasswordLoading || isLoadingWithGoogle}
                  >
                    <MdOutlineLocalPhone className="!size-6" />
                    {t("continueWithMobile")}
                  </Button>
                ) : (
                  !IsLoginWithEmail &&
                  email_authentication === 1 && (
                    <Button
                      variant="outline"
                      size="big"
                      className="flex items-center justify-center py-4 text-base h-auto"
                      onClick={() => setIsLoginWithEmail(true)}
                      disabled={showLoader || forgotPasswordLoading || isLoadingWithGoogle}
                    >
                      <MdOutlineEmail className="!size-6" />
                      {t("continueWithEmail")}
                    </Button>
                  )
                )}
              </div>
              <TermsAndPrivacyLinks t={t} settings={settings} OnHide={OnHide} />
            </div>
          )}
          <div id="recaptcha-container" style={{ display: "none" }}></div>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default LoginModal;
