import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "../ui/dialog";
import { t } from "@/utils";
import { settingsData } from "@/redux/reducer/settingSlice";
import { useSelector } from "react-redux";
import TermsAndPrivacyLinks from "./TermsAndPrivacyLinks";
import { setIsLoginOpen } from "@/redux/reducer/globalStateSlice";
import { MdOutlineEmail, MdOutlineLocalPhone } from "react-icons/md";
import RegisterWithEmailForm from "./RegisterWithEmailForm";
import RegisterWithMobileForm from "./RegisterWithMobileForm";
import { Button } from "../ui/button";

const RegisterModal = ({
  setIsMailSentSuccess,
  IsRegisterModalOpen,
  setIsRegisterModalOpen,
}) => {
  // Get Global data
  const settings = useSelector(settingsData);
  const [showLoader, setShowLoader] = useState(false);
  const [descriptionState, setDescriptionState] = useState({
    type: "register", // "register" | "otp"
    phoneNumber: "",
  });
  const [isOTPScreen, setIsOTPScreen] = useState(false);

  // Active authentication methods
  const mobile_authentication = Number(settings?.mobile_authentication);
  const email_authentication = Number(settings?.email_authentication);

  // Toggle between email and mobile registration
  const [IsRegisterWithEmail, setIsRegisterWithEmail] = useState(
    !mobile_authentication == 1
  );

  const OnHide = () => {
    setIsRegisterModalOpen(false);
  };

  const handleLoginClick = () => {
    OnHide();
    setIsLoginOpen(true);
  };

  const handleChangeClick = () => {
    setIsOTPScreen(false);
    setDescriptionState({ type: "register", phoneNumber: "" });
  };

  // Show divider when alternative auth methods (email/mobile toggle) are available
  const showOrSignInWith =
    !isOTPScreen &&
    ((IsRegisterWithEmail && mobile_authentication == 1) ||
      (!IsRegisterWithEmail && email_authentication == 1));

  return (
    <>
      <Dialog open={IsRegisterModalOpen} onOpenChange={setIsRegisterModalOpen}>
        <DialogContent
          onInteractOutside={(e) => e.preventDefault()}
          className="px-[40px] sm:py-[50px] sm:px-[90px]"
        >
          <DialogHeader>
            <DialogTitle className="text-3xl sm:text-4xl font-light">
              {descriptionState.type === "otp" ? (
                t("verifyOtp")
              ) : (
                <>
                  {t("welcomeTo")}{" "}
                  <span className="text-primary">{settings?.company_name}</span>
                </>
              )}
            </DialogTitle>
            <DialogDescription className="text-base text-black font-light">
              {descriptionState.type === "otp" ? (
                <>
                  {t("sentTo")} {descriptionState.phoneNumber}{" "}
                  <span
                    className="text-primary cursor-pointer underline"
                    onClick={handleChangeClick}
                  >
                    {t("change")}
                  </span>
                </>
              ) : (
                <>
                  {t("haveAccount")}{" "}
                  <span
                    className="text-primary cursor-pointer underline"
                    onClick={handleLoginClick}
                  >
                    {t("logIn")}
                  </span>
                </>
              )}
            </DialogDescription>
          </DialogHeader>

          <div className="flex flex-col gap-[30px] mt-3.5">
            {/* Show RegisterWithEmailForm when email auth is enabled */}
            {email_authentication === 1 &&
              (mobile_authentication == 0 || IsRegisterWithEmail) && (
                <RegisterWithEmailForm
                  OnHide={OnHide}
                  setIsMailSentSuccess={setIsMailSentSuccess}
                  key={IsRegisterWithEmail}
                  showLoader={showLoader}
                  setShowLoader={setShowLoader}
                />
              )}

            {/* Show RegisterWithMobileForm when mobile auth is enabled */}
            {mobile_authentication == 1 &&
              (email_authentication == 0 || !IsRegisterWithEmail) && (
                <RegisterWithMobileForm
                  OnHide={OnHide}
                  setDescriptionState={setDescriptionState}
                  key={IsRegisterWithEmail}
                  isOTPScreen={isOTPScreen}
                  setIsOTPScreen={setIsOTPScreen}
                  showLoader={showLoader}
                  setShowLoader={setShowLoader}
                />
              )}

            {/* Show divider when alternative auth methods are available */}
            {showOrSignInWith && (
              <div className="flex items-center gap-2">
                <hr className="w-full" />
                <p className="text-nowrap text-sm">{t("orSignUpWith")}</p>
                <hr className="w-full" />
              </div>
            )}

            {/* Toggle buttons for switching between email and mobile */}

            {showOrSignInWith && (
              <div className="flex flex-col gap-4">
                {/* Show "Continue with Mobile" button when email is selected and mobile is enabled */}
                {IsRegisterWithEmail && mobile_authentication == 1 && (
                  <Button
                    variant="outline"
                    size="big"
                    className="flex items-center justify-center py-4 text-base h-auto"
                    onClick={() => setIsRegisterWithEmail(false)}
                    disabled={showLoader}
                  >
                    <MdOutlineLocalPhone className="!size-6" />
                    {t("continueWithMobile")}
                  </Button>
                )}

                {/* Show "Continue with Email" button when mobile is selected and email is enabled */}
                {!IsRegisterWithEmail && email_authentication === 1 && (
                  <Button
                    variant="outline"
                    size="big"
                    className="flex items-center justify-center py-4 text-base h-auto"
                    onClick={() => setIsRegisterWithEmail(true)}
                    disabled={showLoader}
                  >
                    <MdOutlineEmail className="!size-6" />
                    {t("continueWithEmail")}
                  </Button>
                )}
              </div>
            )}

            {/* Terms and Privacy Links */}
            {!isOTPScreen && (
              <TermsAndPrivacyLinks t={t} settings={settings} OnHide={OnHide} />
            )}
          </div>
          <div id="recaptcha-container" style={{ display: "none" }}></div>
        </DialogContent>
      </Dialog>
    </>
  );
};

export default RegisterModal;
