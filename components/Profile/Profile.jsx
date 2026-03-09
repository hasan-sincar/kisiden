"use client";
import { getDefaultCountryCode, t } from "@/utils";
import { MdAddPhotoAlternate, MdVerifiedUser } from "react-icons/md";
import { Label } from "../ui/label";
import { Input } from "../ui/input";
import { useEffect, useState } from "react";
import { useSelector } from "react-redux";
import { loadUpdateUserData, userSignUpData } from "@/redux/reducer/authSlice";
import { Switch } from "../ui/switch";
import { Textarea } from "../ui/textarea";
import { Button, buttonVariants } from "../ui/button";
import { Fcmtoken, settingsData } from "@/redux/reducer/settingSlice";
import {
  getUserInfoApi,
  getVerificationStatusApi,
  updateProfileApi,
} from "@/utils/api";
import { toast } from "sonner";
import CustomLink from "@/components/Common/CustomLink";
import Image from "next/image";
import PhoneInput from "react-phone-input-2";
import "react-phone-input-2/lib/style.css";
import { isValidPhoneNumber } from "libphonenumber-js/max";
import { Loader2 } from "lucide-react";

const Profile = () => {
  const UserData = useSelector(userSignUpData);
  const IsLoggedIn = UserData !== undefined && UserData !== null;
  const settings = useSelector(settingsData);
  const placeholder_image = settings?.placeholder_image;
  const [profileImage, setProfileImage] = useState("");
  const [profileFile, setProfileFile] = useState(null);
  const fetchFCM = useSelector(Fcmtoken);
  const [formData, setFormData] = useState({
    name: "",
    email: "",
    phone: "",
    address: "",
    notification: 1,
    show_personal_details: 0,
    region_code: "",
    country_code: "",
  });
  const [isLoading, setIsLoading] = useState(false);
  const [isPending, setIsPending] = useState(false);
  const [VerificationStatus, setVerificationStatus] = useState("");
  const [RejectionReason, setRejectionReason] = useState("");
  const getVerificationProgress = async () => {
    try {
      const res = await getVerificationStatusApi.getVerificationStatus();
      if (res?.data?.error === true) {
        setVerificationStatus("not applied");
      } else {
        const status = res?.data?.data?.status;
        const rejectReason = res?.data?.data?.rejection_reason;
        setVerificationStatus(status);
        setRejectionReason(rejectReason);
      }
    } catch (error) {
      console.log(error);
    }
  };

  const getUserDetails = async () => {
    try {
      const res = await getUserInfoApi.getUserInfo();
      if (res?.data?.error === false) {
        const region = (
          res?.data?.data?.region_code ||
          process.env.NEXT_PUBLIC_DEFAULT_COUNTRY ||
          "in"
        ).toLowerCase();

        const countryCode =
          res?.data?.data?.country_code?.replace("+", "") || getDefaultCountryCode();

        setFormData({
          name: res?.data?.data?.name || "",
          email: res?.data?.data?.email || "",
          phone: res?.data?.data?.mobile || "",
          address: res?.data?.data?.address || "",
          notification: res?.data?.data?.notification,
          show_personal_details: Number(res?.data?.data?.show_personal_details),
          region_code: region,
          country_code: countryCode,
        });
        setProfileImage(res?.data?.data?.profile || placeholder_image);
        const currentFcmId = UserData?.fcm_id;
        if (!res?.data?.data?.fcm_id && currentFcmId) {
          const updatedData = { ...res?.data?.data, fcm_id: currentFcmId };
          loadUpdateUserData(updatedData);
        } else {
          loadUpdateUserData(res?.data?.data);
        }
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log("Error fetching user details:", error);
    }
  };

  useEffect(() => {
    if (IsLoggedIn) {
      const fetchData = async () => {
        setIsPending(true);
        try {
          await Promise.all([getVerificationProgress(), getUserDetails()]);
        } catch (error) {
          console.log("Error in parallel API calls:", error);
        } finally {
          setIsPending(false);
        }
      };
      fetchData();
    }
  }, []);

  const handleChange = (e) => {
    const { id, value } = e.target;
    setFormData((prevData) => ({
      ...prevData,
      [id]: value,
    }));
  };

  const handlePhoneChange = (value, data) => {
    const dial = data?.dialCode || "";
    const iso2 = data?.countryCode || ""; // region code (in, us, ae)

    setFormData((prev) => {
      const pureMobile = value.startsWith(dial)
        ? value.slice(dial.length)
        : value;
      return {
        ...prev,
        phone: pureMobile,
        country_code: dial,
        region_code: iso2,
      };
    });
  };

  const handleSwitchChange = (id) => {
    setFormData((prevData) => ({
      ...prevData,
      [id]: prevData[id] === 1 ? 0 : 1,
    }));
  };

  const handleImageChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setProfileFile(file);
      const reader = new FileReader();
      reader.onload = () => {
        setProfileImage(reader.result);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (!formData?.name.trim() || !formData?.address.trim()) {
        toast.error(t("emptyFieldNotAllowed"));
        return;
      }
      const mobileNumber = formData.phone || "";

      // ✅ Validate phone number ONLY if user entered one as it is optional
      if (
        Boolean(mobileNumber) &&
        !isValidPhoneNumber(`+${formData.country_code}${mobileNumber}`)
      ) {
        toast.error(t("invalidPhoneNumber"));
        return;
      }
      setIsLoading(true);
      const response = await updateProfileApi.updateProfile({
        name: formData.name,
        email: formData.email,
        mobile: mobileNumber,
        address: formData.address,
        profile: profileFile,
        fcm_id: fetchFCM ? fetchFCM : "",
        notification: formData.notification,
        country_code: formData.country_code,
        show_personal_details: formData?.show_personal_details,
        region_code: formData.region_code.toUpperCase(),
      });

      const data = response.data;
      if (data.error !== true) {
        const currentFcmId = UserData?.fcm_id;
        if (!data?.data?.fcm_id && currentFcmId) {
          const updatedData = { ...data?.data, fcm_id: currentFcmId };
          loadUpdateUserData(updatedData);
        } else {
          loadUpdateUserData(data?.data);
        }
        toast.success(data.message);
      } else {
        toast.error(data.message);
      }
    } catch (error) {
      console.error("Error:", error);
    } finally {
      setIsLoading(false);
    }
  };

  // Show loader when pending is true
  if (isPending) {
    return (
      <div className="flex justify-center items-center h-full">
        <div className="relative w-12 h-12">
          <div className="absolute w-12 h-12 bg-primary rounded-full animate-ping"></div>
          <div className="absolute w-12 h-12 bg-primary rounded-full animate-ping delay-1000"></div>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-6">
      <div className="flex flex-col md:flex-row md:items-center sm:justify-between gap-4 md:border md:py-6 md:px-4 md:rounded">
        <div className="flex flex-col md:flex-row items-center gap-4 flex-1">
          <div className="relative">
            {/* use next js image directly here */}
            {profileImage && (
              <Image
                src={profileImage}
                alt="User profile"
                width={120}
                height={120}
                className="w-[120px] h-auto aspect-square rounded-full border-muted border-4"
              />
            )}

            <div className="flex items-center justify-center p-1 absolute size-10 rounded-full top-20 right-0 bg-primary border-4 border-[#efefef] text-white cursor-pointer">
              <input
                type="file"
                id="profileImageUpload"
                className="hidden"
                accept="image/*"
                onChange={handleImageChange}
              />
              <label htmlFor="profileImageUpload" className="cursor-pointer">
                <MdAddPhotoAlternate size={22} />
              </label>
            </div>
          </div>
          <div className="flex flex-col gap-2 flex-1">
            <h1
              className="text-xl text-center ltr:md:text-left rtl:md:text-right font-medium break-words line-clamp-2"
              title={UserData?.name}
            >
              {UserData?.name}
            </h1>
            <p className="break-all text-center ltr:md:text-left rtl:md:text-right">
              {UserData?.email}
            </p>
          </div>
        </div>
        <div className="md:max-w-[50%] flex justify-center md:justify-end">
          {(() => {
            switch (VerificationStatus) {
              case "approved":
                return (
                  <div className="flex items-center gap-1 rounded text-white bg-[#fa6e53] py-1 px-2 text-sm">
                    <MdVerifiedUser size={14} />
                    <span>{t("verified")}</span>
                  </div>
                );

              case "not applied":
                return (
                  <div className="flex justify-end">
                    <CustomLink
                      href="/user-verification"
                      className={buttonVariants()}
                    >
                      {t("verfiyNow")}
                    </CustomLink>
                  </div>
                );

              case "rejected":
                return (
                  <div className="flex flex-col gap-4 items-center md:items-end">
                    {RejectionReason && (
                      <p className="text-sm text-center md:text-right capitalize">
                        {RejectionReason}
                      </p>
                    )}

                    <CustomLink
                      href="/user-verification"
                      className={buttonVariants() + " w-fit"}
                    >
                      {t("applyAgain")}
                    </CustomLink>
                  </div>
                );

              case "pending":
              case "resubmitted":
                return (
                  <Button type="button" className="cursor-auto">
                    {t("inReview")}
                  </Button>
                );
              default:
                return null;
            }
          })()}
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 md:border md:py-6 md:px-4 md:rounded">
        <h1 className="col-span-full text-xl font-medium">
          {t("personalInfo")}
        </h1>

        <div className="labelInputCont">
          <Label htmlFor="name" className="requiredInputLabel">
            {t("name")}
          </Label>
          <Input
            type="text"
            id="name"
            placeholder={t("enterName")}
            value={formData.name}
            onChange={handleChange}
          />
        </div>

        <div className="flex flex-colgap-1">
          <div className="w-1/2 flex flex-col justify-between gap-3">
            <Label className="font-semibold" htmlFor="notification-mode">
              {t("notification")}
            </Label>
            <Switch
              className="rtl:[direction:rtl]"
              id="notification-mode"
              checked={Number(formData.notification) === 1}
              onCheckedChange={() => handleSwitchChange("notification")}
            />
          </div>
          <div className="w-1/2 flex flex-col justify-between gap-3">
            <Label className="font-semibold" htmlFor="showPersonal-mode">
              {t("showContactInfo")}
            </Label>
            <Switch
              id="showPersonal-mode"
              checked={Number(formData.show_personal_details) === 1}
              onCheckedChange={() =>
                handleSwitchChange("show_personal_details")
              }
            />
          </div>
        </div>

        <div className="labelInputCont">
          <Label htmlFor="email" className="requiredInputLabel">
            {t("email")}
          </Label>
          <Input
            type="email"
            id="email"
            placeholder={t("enterEmail")}
            value={formData.email}
            onChange={handleChange}
            readOnly={
              UserData?.type === "email" || UserData?.type === "google"
                ? true
                : false
            }
          />
        </div>
        <div className="labelInputCont">
          <Label htmlFor="phone" className="font-semibold">
            {t("phoneNumber")}
          </Label>
          <PhoneInput
            country={process.env.NEXT_PUBLIC_DEFAULT_COUNTRY}
            value={`${formData.country_code}${formData.phone}`}
            onChange={(phone, data) => handlePhoneChange(phone, data)}
            inputProps={{
              name: "phone",
            }}
            enableLongNumbers
            disabled={UserData?.type === "phone"}
          />
        </div>
      </div>
      <div className="md:border md:py-6 md:px-4 md:rounded">
        <h1 className="col-span-full mb-6 text-xl font-medium">
          {t("address")}
        </h1>
        <div className="labelInputCont">
          <Label htmlFor="address" className="requiredInputLabel">
            {t("address")}
          </Label>
          <Textarea
            id="address"
            name="address"
            value={formData.address}
            onChange={handleChange}
          />
        </div>
      </div>

      <Button disabled={isLoading} className="ltr:ml-auto rtl:mr-auto w-fit">
        {isLoading ?
          <>
            <Loader2 className="size-4 animate-spin" />
            {t("savingChanges")}
          </>
          :
          t("saveChanges")}
      </Button>
    </form>
  );
};

export default Profile;
