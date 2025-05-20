import { Modal } from "antd"
import Link from "next/link"
import { MdClose } from "react-icons/md"
import { FcGoogle } from "react-icons/fc";
import { useEffect, useRef, useState } from "react";
import { FaRegEye, FaRegEyeSlash } from "react-icons/fa6";
import { GoogleAuthProvider, RecaptchaVerifier, createUserWithEmailAndPassword, getAuth, sendEmailVerification, signInWithPhoneNumber, signInWithPopup } from "firebase/auth";
import toast from "react-hot-toast";
import { handleFirebaseAuthError, t } from "@/utils";
import { getOtpApi, userSignUpApi, verifyOtpApi } from "@/utils/api";
import { useSelector } from "react-redux";
import { Fcmtoken, settingsData } from "@/redux/reuducer/settingSlice";
import { loadUpdateData } from "../../redux/reuducer/authSlice";
import PhoneInput from 'react-phone-input-2';
import 'react-phone-input-2/lib/style.css';
import { isValidPhoneNumber } from 'libphonenumber-js';
import { useRouter } from "next/navigation";



const RegisterModal = ({ IsRegisterModalOpen, CloseRegisterModal, setIsLoginModalOpen, setIsMailSentOpen }) => {


    const router = useRouter()
    const auth = getAuth();
    const emailInputRef = useRef(null);
    const usernameInputRef = useRef(null);
    const otpInputRef = useRef(null);
    const fetchFCM = useSelector(Fcmtoken);
    const systemSettingsData = useSelector(settingsData)
    const settings = systemSettingsData?.data
    const otp_service_provider = settings?.otp_service_provider;
    const mobile_authentication = Number(settings?.mobile_authentication)
    const google_authentication = Number(settings?.google_authentication)
    const email_authentication = Number(settings?.email_authentication)
    const isDemoMode = settings?.demo_mode
    const [IsLoginScreen, setIsLoginScreen] = useState(true);
    const [IsPasswordScreen, setIsPasswordScreen] = useState(false);
    const [IsOTPScreen, setIsOTPScreen] = useState(false);
    const [inputValue, setInputValue] = useState("");
    const [email, setEmail] = useState("");
    const [password, setPassword] = useState("");
    const [number, setNumber] = useState("");
    const [inputType, setInputType] = useState("");
    const [countryCode, setCountryCode] = useState("");
    const [otp, setOtp] = useState("");
    const [confirmationResult, setConfirmationResult] = useState(null);
    const [showLoader, setShowLoader] = useState(false);
    const [resendOtpLoader, setResendOtpLoader] = useState(false)
    const [IsPasswordVisible, setIsPasswordVisible] = useState(false)
    const [username, setUsername] = useState('')
    const [resendTimer, setResendTimer] = useState(0);

    const OnHide = async () => {
        setIsLoginScreen(true);
        setIsPasswordScreen(false);
        setIsOTPScreen(false);
        setEmail("");
        setPassword("");
        setInputValue("");
        setUsername('')
        setInputType("");
        setNumber("");
        setOtp("");
        setResendTimer(0);
        CloseRegisterModal()
        await recaptchaClear()
    };

    // Remove any non-digit characters from the country code
    const countryCodeDigitsOnly = countryCode.replace(/\D/g, '');

    // Check if the entered number starts with the selected country code
    const startsWithCountryCode = number.startsWith(countryCodeDigitsOnly);

    // If the number starts with the country code, remove it
    const formattedNumber = startsWithCountryCode ? number.substring(countryCodeDigitsOnly.length) : number;


    useEffect(() => {
        if (IsRegisterModalOpen) {
            requestAnimationFrame(() => {
                if (!IsPasswordScreen && emailInputRef.current) {
                    emailInputRef.current.focus();
                } else if (IsPasswordScreen && usernameInputRef.current) {
                    usernameInputRef.current.focus();
                } else if (IsOTPScreen && otpInputRef.current) {
                    otpInputRef.current.focus();
                }
            });
        }
    }, [IsPasswordScreen, IsRegisterModalOpen, IsOTPScreen]);

    // Timer countdown effect
    useEffect(() => {
        let intervalId;
        if (resendTimer > 0) {
            intervalId = setInterval(() => {
                setResendTimer(prevTimer => prevTimer - 1);
            }, 1000);
        }

        return () => {
            if (intervalId) clearInterval(intervalId);
        };
    }, [resendTimer]);

    const handleInputChange = (value, data) => {
        const emailRegexPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        const containsOnlyDigits = /^\d+$/.test(value);
        setInputValue(value);
        if (emailRegexPattern.test(value)) {
            setInputType("email");
            setEmail(value);
            setNumber("");
            setCountryCode("");
        } else if (containsOnlyDigits) {
            setInputType("number");
            setNumber(value);
            setCountryCode("+" + (data?.dialCode || ""));
        } else {
            setInputType("");
        }
    };
    const Signin = async (e) => {
        e.preventDefault();

        if (!email) {
            toast.error(t("emailRequired"))
            return
        } else if (!/\S+@\S+\.\S+/.test(email)) {
            toast.error(t("emailInvalid"))
            return
        }
        if (username?.trim() === '') {
            toast.error(t("usernameRequired"))
            return
        }
        if (!password) {
            toast.error(t("passwordRequired"))
            return
        } else if (password.length < 6) {
            toast.error(t("passwordTooShort"))
            return
        }
        try {
            setShowLoader(true)
            const userCredential = await createUserWithEmailAndPassword(auth, email, password);
            const user = userCredential.user;
            await sendEmailVerification(user);
            try {
                await userSignUpApi.userSignup({
                    name: username ? username : "",
                    email: email ? email : "",
                    firebase_id: user?.uid,
                    type: "email",
                    registration: true
                });
                OnHide()
                setIsMailSentOpen(true)
            } catch (error) {
                console.log("error", error);
            }
        } catch (error) {
            const errorCode = error.code;
            handleFirebaseAuthError(errorCode);
        } finally {
            setShowLoader(false)
        }
    };

    const generateRecaptcha = () => {
        // Ensure auth object is properly initialized
        const auth = getAuth();

        if (!window.recaptchaVerifier) {
            // Check if container element exists
            const recaptchaContainer = document.getElementById("recaptcha-container");
            if (!recaptchaContainer) {
                console.error("Container element 'recaptcha-container' not found.");
                return null; // Return null if container element not found
            }

            try {
                // Clear any existing reCAPTCHA instance
                recaptchaContainer.innerHTML = '';

                // Initialize RecaptchaVerifier
                window.recaptchaVerifier = new RecaptchaVerifier(auth, "recaptcha-container", {
                    size: "invisible",
                });
                return window.recaptchaVerifier;
            } catch (error) {
                console.error("Error initializing RecaptchaVerifier:", error.message);
                return null; // Return null if error occurs during initialization
            }
        }
        return window.recaptchaVerifier;
    };

    useEffect(() => {
        generateRecaptcha();

        return () => {
            // Clean up recaptcha container and verifier when component unmounts
            const recaptchaContainer = document.getElementById("recaptcha-container");
            if (recaptchaContainer) {
                recaptchaContainer.innerHTML = "";
            }
            if (window.recaptchaVerifier) {
                window.recaptchaVerifier.clear();
                window.recaptchaVerifier = null; // Clear the recaptchaVerifier reference
            }
        };
    }, []); // Empty dependency array ensures this effect runs only once after mount


    const sendOTP = async () => {
        setShowLoader(true)
        const PhoneNumber = `${countryCode}${formattedNumber}`;
        if (otp_service_provider === 'twilio') {
            try {
                const response = await getOtpApi.getOtp({ number: PhoneNumber });
                if (response?.data?.error === false) {
                    toast.success(t("otpSentSuccess"));
                    setResendTimer(60); // Start the 60-second timer
                } else {
                    toast.error(t("failedToSendOtp"));
                }
            } catch (error) {
                console.error('error', error)
            } finally {
                setShowLoader(false);
            }
        }
        else {
            try {
                const appVerifier = generateRecaptcha();
                const confirmation = await signInWithPhoneNumber(auth, PhoneNumber, appVerifier);
                setConfirmationResult(confirmation);
                toast.success(t("otpSentSuccess"));
                setResendTimer(60); // Start the 60-second timer
                if (isDemoMode) {
                    setOtp("123456")
                }
            } catch (error) {
                console.log(error)
                const errorCode = error.code;
                handleFirebaseAuthError(errorCode);

            } finally {
                setShowLoader(false);
                if (otpInputRef.current) {
                    otpInputRef.current.focus()
                }
            }
        }
    };

    const resendOtp = async (e) => {
        e.preventDefault()
        if (resendTimer > 0) return; // Prevent resend if timer is still active

        setResendOtpLoader(true)
        const PhoneNumber = `${countryCode}${formattedNumber}`;
        if (otp_service_provider === 'twilio') {
            try {
                const response = await getOtpApi.getOtp({ number: PhoneNumber });
                if (response?.data?.error === false) {
                    toast.success(t("otpSentSuccess"));
                    setResendTimer(60); // Restart the 60-second timer
                } else {
                    toast.error(t("failedToSendOtp"));
                }
            } catch (error) {
                console.error('error', error)
            } finally {
                setResendOtpLoader(false);
                otpInputRef?.current?.focus();
            }
        }
        else {
            try {
                const appVerifier = generateRecaptcha();
                const confirmation = await signInWithPhoneNumber(auth, PhoneNumber, appVerifier);
                setConfirmationResult(confirmation);
                toast.success(t("otpSentSuccess"));
                setResendTimer(60); // Restart the 60-second timer
            } catch (error) {
                console.log(error)
                const errorCode = error.code;
                handleFirebaseAuthError(errorCode);
            } finally {
                setResendOtpLoader(false)
                if (otpInputRef.current) {
                    otpInputRef.current.focus()
                }
            }
        }
    }

    const verifyOTP = async (e) => {
        e.preventDefault();
        if (otp === '') {
            toast.error(t('otpmissing'))
            return
        }
        setShowLoader(true)
        if (otp_service_provider === 'twilio') {
            const PhoneNumber = `${countryCode}${formattedNumber}`;
            try {
                const response = await verifyOtpApi.verifyOtp({ number: PhoneNumber, otp: otp });
                if (response?.data?.error === false) {
                    loadUpdateData(response?.data);
                    toast.success(response?.data?.message);
                    if (response?.data?.data?.email === "" || response?.data?.data?.name === "") {
                        router.push("/profile/edit-profile");
                    }
                    OnHide();
                } else {
                    toast.error(response?.data?.message);
                }
            } catch (error) {
                console.error('error', error)
            } finally {
                setShowLoader(false);
            }
        }
        else {
            try {
                const result = await confirmationResult.confirm(otp);
                const user = result.user;
                const response = await userSignUpApi.userSignup({
                    mobile: formattedNumber,
                    firebase_id: user.uid, // Accessing UID directly from the user object
                    fcm_id: fetchFCM ? fetchFCM : "",
                    country_code: countryCode,
                    type: "phone"
                });
                const data = response.data;
                loadUpdateData(data)
                toast.success(data.message);
                if (data?.data?.email === "" || response?.data?.name === "") {
                    router.push('/profile/edit-profile')
                }
                OnHide();
            } catch (error) {
                console.error("Error:", error);
                const errorCode = error?.code;
                handleFirebaseAuthError(errorCode);
            } finally {
                setShowLoader(false)
            }
        }
    };


    const handleLoginSubmit = (e) => {
        setShowLoader(true)
        e.preventDefault();
        if (inputType === "email") {
            setIsPasswordScreen(true);
            setIsLoginScreen(false);
            setShowLoader(false)
        } else if (inputType === "number") {
            // Perform phone number validation on the formatted number
            if (isValidPhoneNumber(`${countryCode}${formattedNumber}`)) {
                sendOTP();
                setIsOTPScreen(true);
                setIsLoginScreen(false);
            } else {
                // Show an error message indicating that the phone number is not valid
                toast.error(t("invalidPhoneNumber"));
                setShowLoader(false)
            }
        } else {
            setShowLoader(false)
            if (email_authentication === 0 && mobile_authentication === 1) {
                toast.error(t("invalidPhoneNumber"));
            } else {
                toast.error(t("invalidPhoneNumberOrEmail"));
            }

        }
    };

    useEffect(() => {
    }, [inputValue, inputType, IsPasswordScreen, IsOTPScreen, email, password, number])

    useEffect(() => {
        if (inputValue === "" && email_authentication === 1) {
            setInputType("email")
            setNumber("")
        }
    }, [inputValue, inputType])

    const togglePasswordVisible = () => {
        setIsPasswordVisible((prev) => !prev)
    }

    const handleShowLoginPassword = () => {
        setIsPasswordScreen(false)
        setIsOTPScreen(false)
        setIsLoginScreen(true)
    }
    const CloseIcon = <div className="close_icon_cont"><MdClose size={24} color="black" /></div>
    const recaptchaClear = async () => {
        const recaptchaContainer = document.getElementById('recaptcha-container')
        if (recaptchaContainer) {
            recaptchaContainer.innerHTML = ''
        }
        if (window.recaptchaVerifier) {
            window?.recaptchaVerifier?.recaptcha?.reset()
        }
    }

    const handleGoogleSignup = async () => {
        const provider = new GoogleAuthProvider();
        try {
            const response = await signInWithPopup(auth, provider);
            const user = response.user
            try {
                const response = await userSignUpApi.userSignup({
                    name: user.displayName ? user.displayName : "",
                    email: user?.email,
                    firebase_id: user.uid, // Accessing UID directly from the user object
                    fcm_id: fetchFCM ? fetchFCM : "",
                    type: "google"
                });

                const data = response.data;
                loadUpdateData(data)
                if (data.error === true) {
                    toast.error(data.message);
                }
                else {
                    toast.success(data.message);
                }
                OnHide();

            } catch (error) {
                console.error("Error:", error);
            }
        } catch (error) {
            const errorCode = error.code;
            handleFirebaseAuthError(errorCode);
        }
    };


    const handleLoginClick = () => {
        CloseRegisterModal()
        setIsLoginModalOpen(true)
    }


    return (
        <>
            <Modal
                centered
                open={IsRegisterModalOpen}
                closeIcon={CloseIcon}
                colorIconHover="transparent"
                className="ant_register_modal"
                onCancel={OnHide}
                footer={null}
                maskClosable={false}
            >
                {IsLoginScreen && (
                    <div className="register_modal">
                        <div className="reg_modal_header">
                            <h1 className="reg_modal_title">
                                {t('welcomeTo')}
                                <span className="brand_name"> {settings?.company_name}</span>
                            </h1>
                            <p className="signin_redirect">{t('haveAccount')} <span className="main_signin_redirect" onClick={handleLoginClick}>{t('logIn')}</span>
                            </p>
                        </div>

                        {
                            !(mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1) &&
                            <form className="auth_form" onSubmit={handleLoginSubmit}>
                                <div className="auth_in_cont">
                                    {
                                        mobile_authentication === 1 && email_authentication === 1 && (
                                            <>
                                                <label htmlFor="email" className="auth_label">
                                                    {t('emailOrPhoneNumber')}
                                                </label>
                                                {inputType === "number" ? (
                                                    <PhoneInput
                                                        country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
                                                        value={number}
                                                        onChange={(phone, data) => handleInputChange(phone, data)}
                                                        onCountryChange={(code) => setCountryCode(code)}
                                                        inputProps={{
                                                            name: "phone",
                                                            required: true,
                                                            autoFocus: true,
                                                        }}
                                                        enableLongNumbers
                                                    />
                                                ) : (
                                                    <input
                                                        type="text"
                                                        className="auth_input"
                                                        placeholder={t("enterEmailPhone")}
                                                        value={inputValue}
                                                        onChange={(e) => handleInputChange(e.target.value, {})}
                                                        required
                                                        ref={emailInputRef}
                                                    />
                                                )}
                                            </>
                                        )
                                    }

                                    {email_authentication === 1 && mobile_authentication === 0 && (
                                        <>
                                            <label htmlFor="email" className="auth_label">
                                                {t('email')}
                                            </label>
                                            <input
                                                type="email"
                                                className="auth_input"
                                                placeholder={t("enterEmail")}
                                                value={inputValue}
                                                onChange={(e) => handleInputChange(e.target.value)}
                                                required
                                            />
                                        </>
                                    )}

                                    {mobile_authentication === 1 && email_authentication === 0 && (
                                        <>
                                            <label htmlFor="phone" className="auth_label">
                                                {t('phoneNumber')}
                                            </label>
                                            <PhoneInput
                                                country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
                                                value={number}
                                                onChange={(phone, data) => handleInputChange(phone, data)}
                                                onCountryChange={(code) => setCountryCode(code)}
                                                inputProps={{
                                                    name: "phone",
                                                    required: true,
                                                    autoFocus: true,
                                                }}
                                            />
                                        </>
                                    )}
                                </div>

                                {
                                    !(mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1) &&
                                    <button type="submit" className="verf_email_add_btn">
                                        {showLoader ? (
                                            <div className="loader-container-otp">
                                                <div className="loader-otp"></div>
                                            </div>
                                        ) : (
                                            <span>{t('continue')}</span>
                                        )}
                                    </button>
                                }
                            </form>
                        }



                        {
                            !(mobile_authentication === 0 && email_authentication === 0 && google_authentication === 1) && google_authentication === 1 &&
                            <div className="signup_with_cont">
                                <hr />
                                <p>{t('orSignInWith')}</p>
                                <hr />
                            </div>
                        }

                        {
                            google_authentication === 1 &&
                            <button className="reg_with_google_btn" onClick={handleGoogleSignup}>
                                <FcGoogle size={24} />
                                {t('google')}
                            </button>
                        }

                        <div className="auth_modal_footer">
                            {t('agreeSignIn')} {settings?.company_name} <br />
                            <Link href="/terms-and-condition" className="link_brand_name" onClick={OnHide}>
                                {t('termsService')}
                            </Link>{" "}
                            {t('and')}{" "}
                            <Link href="/privacy-policy" className="link_brand_name" onClick={OnHide}>
                                {t('privacyPolicy')}
                            </Link>
                        </div>
                    </div>
                )}


                {IsPasswordScreen && (
                    <div className="register_modal">
                        <div className="reg_modal_header">
                            <h1 className="reg_modal_title">{t('signUpWithEmail')}</h1>
                            <p className="signin_redirect">
                                {email}{" "}
                                <span className="main_signin_redirect" onClick={handleShowLoginPassword}>
                                    {t('change')}
                                </span>
                            </p>
                        </div>
                        <form className="auth_form" onSubmit={Signin}>

                            <div className="auth_in_cont">
                                <label htmlFor="username" className="auth_label">{t('username')}</label>
                                <input type="text" ref={usernameInputRef} placeholder={t("typeUsername")} className="auth_input" name="username" required onChange={(e) => setUsername(e.target.value)} value={username} />
                            </div>

                            <div className="auth_in_cont">
                                <label htmlFor="password" className="auth_label">
                                    {t('password')}
                                </label>
                                <div className="password_cont">
                                    <input
                                        type={IsPasswordVisible ? "text" : "password"}
                                        className="auth_input"
                                        placeholder={t("enterPassword")}
                                        id="password"
                                        name="password"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                    />
                                    <div className="pass_eye" onClick={togglePasswordVisible}>
                                        {IsPasswordVisible ? <FaRegEye size={20} /> : <FaRegEyeSlash size={20} />}
                                    </div>
                                </div>
                            </div>

                            <button type="submit" className="verf_email_add_btn">
                                {showLoader ?
                                    <div className="loader-container-otp">
                                        <div className="loader-otp"></div>
                                    </div>
                                    :
                                    <span>{t('verifyEmail')}</span>
                                }
                            </button>
                        </form>
                    </div>
                )}
                {IsOTPScreen && (
                    <>
                        <div className="register_modal">
                            <div className="reg_modal_header">
                                <h1 className="reg_modal_title">{t('verifyOtp')}</h1>
                                <p className="signin_redirect">
                                    {t('sentTo')} {`+${number}`}{" "}
                                    <span className="main_signin_redirect" onClick={handleShowLoginPassword}>
                                        {t('change')}
                                    </span>
                                </p>
                            </div>
                            <form className="auth_form">
                                <div className="auth_in_cont">
                                    <label htmlFor="otp" className="auth_label">
                                        {t('otp')}
                                    </label>
                                    <input
                                        type="text"
                                        className="auth_input"
                                        placeholder={t("enterOtp")}
                                        id="otp"
                                        name="otp"
                                        value={otp}
                                        maxLength="6"
                                        onChange={(e) => setOtp(e.target.value)}
                                        ref={otpInputRef}
                                    />
                                </div>
                                <>
                                    <button type="submit" className="verf_email_add_btn" onClick={verifyOTP}>
                                        {showLoader ?
                                            <div className="loader-container-otp">
                                                <div className="loader-otp"></div>
                                            </div>
                                            :
                                            t('verify')
                                        }
                                    </button>



                                    <button
                                        type="submit"
                                        className="resend_otp_btn"
                                        onClick={resendOtp}
                                        disabled={resendTimer > 0}
                                        style={{ opacity: resendTimer > 0 ? 0.7 : 1, cursor: resendTimer > 0 ? 'not-allowed' : 'pointer' }}
                                    >
                                        {
                                            resendOtpLoader ?
                                                <div className="loader-container-otp">
                                                    <div className="loader-otp"></div>
                                                </div>
                                                :
                                                resendTimer > 0 ?
                                                    `${t('resendOtp')} (${resendTimer}s)` :
                                                    t('resendOtp')
                                        }
                                    </button>
                                </>
                            </form>
                        </div>
                    </>
                )}
            </Modal>
            <div id="recaptcha-container"></div>
        </>
    )
}

export default RegisterModal