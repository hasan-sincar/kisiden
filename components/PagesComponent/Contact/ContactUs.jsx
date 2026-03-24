"use client";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { settingsData } from "@/redux/reducer/settingSlice";
import { t } from "@/utils";
import { useState } from "react";
import {
  FaInstagram,
  FaFacebook,
  FaLinkedin,
  FaPinterest,
} from "react-icons/fa";
import { GrLocation } from "react-icons/gr";
import { RiMailSendLine } from "react-icons/ri";
import { useSelector } from "react-redux";
import { TbPhoneCall } from "react-icons/tb";
import { FaSquareXTwitter } from "react-icons/fa6";
import { contactUsApi } from "@/utils/api";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import Layout from "@/components/Layout/Layout";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import parse from "html-react-parser";
import Link from "next/link";

const ContactUs = () => {
  const settings = useSelector(settingsData);
  const [IsLoading, setIsLoading] = useState(false);
  const contactUs = settings?.contact_us;

  const [formData, setFormData] = useState({
    name: "",
    email: "",
    subject: "",
    message: "",
  });

  const [errors, setErrors] = useState({
    name: "",
    email: "",
    subject: "",
    message: "",
  });

  const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData({
      ...formData,
      [name]: value,
    });
    // Clear error when user starts typing
    setErrors({
      ...errors,
      [name]: "",
    });
  };

  const validateForm = () => {
    let isValid = true;
    const newErrors = {};

    // Name validation
    if (!formData.name.trim()) {
      newErrors.name = t("nameRequired");
      isValid = false;
    }

    // Email validation
    if (!formData.email.trim()) {
      newErrors.email = t("emailRequired");
      isValid = false;
    } else if (!validateEmail(formData.email)) {
      newErrors.email = t("invalidEmail");
      isValid = false;
    }

    // Subject validation
    if (!formData.subject.trim()) {
      newErrors.subject = t("subjectRequired");
      isValid = false;
    }

    // Message validation
    if (!formData.message.trim()) {
      newErrors.message = t("messageRequired");
      isValid = false;
    }

    setErrors(newErrors);
    return isValid;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (validateForm()) {
      try {
        setIsLoading(true);
        const res = await contactUsApi.contactUs(formData);
        if (res?.data?.error === false) {
          toast.success(t("thankForContacting"));
          setFormData({
            name: "",
            email: "",
            subject: "",
            message: "",
          });
        } else {
          toast.error(t("errorOccurred"));
        }
      } catch (error) {
        toast.error(t("errorOccurred"));
        console.log(error);
      } finally {
        setIsLoading(false);
      }
    }
  };

  return (
    <Layout>
      <BreadCrumb title2={t("contactUs")} />
      <div className="container">
        <h1 className="sectionTitle mt-8">{t("contactUs")}</h1>
        <div className="grid grid-cols-1 lg:grid-cols-3 mt-6 border rounded-lg">
          {/* Contact Form */}
          <div className="lg:col-span-2 p-4 sm:p-6 rounded-lg">
            <h2 className="text-lg sm:text-xl font-medium mb-2">
              {t("sendMessage")}
            </h2>
            <p className="text-sm sm:text-base text-muted-foreground mb-6">
              {t("contactIntro")}
            </p>

            <form onSubmit={handleSubmit}>
              <div className="grid grid-cols-1 gap-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div className="labelInputCont">
                    <Label htmlFor="name" className="requiredInputLabel">
                      {t("name")}
                    </Label>
                    <Input
                      id="name"
                      name="name"
                      type="text"
                      placeholder={t("enterName")}
                      value={formData.name}
                      onChange={handleChange}
                      className={
                        errors.name
                          ? "border-red-500 focus-visible:ring-red-500"
                          : ""
                      }
                    />
                    {errors.name && (
                      <span className="text-red-500 text-sm">
                        {errors.name}
                      </span>
                    )}
                  </div>

                  <div className="labelInputCont">
                    <Label htmlFor="email" className="requiredInputLabel">
                      {t("email")}
                    </Label>
                    <Input
                      id="email"
                      name="email"
                      type="text"
                      placeholder={t("enterEmail")}
                      value={formData.email}
                      onChange={handleChange}
                      className={
                        errors.email
                          ? "border-red-500 focus-visible:ring-red-500"
                          : ""
                      }
                    />
                    {errors.email && (
                      <span className="text-red-500 text-sm">
                        {errors.email}
                      </span>
                    )}
                  </div>
                </div>

                <div className="labelInputCont">
                  <Label htmlFor="subject" className="requiredInputLabel">
                    {t("subject")}
                  </Label>
                  <Input
                    id="subject"
                    name="subject"
                    type="text"
                    placeholder={t("enterSubject")}
                    value={formData.subject}
                    onChange={handleChange}
                    className={
                      errors.subject
                        ? "border-red-500 focus-visible:ring-red-500"
                        : ""
                    }
                  />
                  {errors.subject && (
                    <span className="text-red-500 text-sm">
                      {errors.subject}
                    </span>
                  )}
                </div>

                <div className="labelInputCont">
                  <Label htmlFor="message" className="requiredInputLabel">
                    {t("message")}
                  </Label>
                  <Textarea
                    id="message"
                    name="message"
                    placeholder={t("enterMessage")}
                    value={formData.message}
                    onChange={handleChange}
                    className={
                      errors.message
                        ? "border-red-500 focus-visible:ring-red-500"
                        : ""
                    }
                  />
                  {errors.message && (
                    <span className="text-red-500 text-sm">
                      {errors.message}
                    </span>
                  )}
                </div>

                <div className="flex justify-end">
                  <Button type="submit" disabled={IsLoading}>
                    {IsLoading ? (
                      <>
                        <Loader2 className="animate-spin" />
                        {t("submitting")}
                      </>
                    ) : (
                      t("submit")
                    )}
                  </Button>
                </div>
              </div>
            </form>
          </div>

          {/* Contact Information */}
          <div className="bg-[#1a1a1a] text-white p-4 sm:p-6 rounded-lg">
            <h2 className="text-lg sm:text-xl font-medium mb-6">
              {t("contactInfo")}
            </h2>
            <div className="space-y-6">
              <div className="max-w-full prose lg:prose-lg prose-invert">
                {parse(contactUs || "")}
              </div>

              {settings?.company_address && (
                <div className="flex items-center gap-4">
                  <div className="footerSocialLinks">
                    <GrLocation size={24} />
                  </div>
                  <p className="text-sm text-white/65 hover:text-primary">
                    {settings?.company_address}
                  </p>
                </div>
              )}

              {settings?.company_email && (
                <div className="flex items-center gap-4">
                  <div className="footerSocialLinks">
                    <RiMailSendLine size={24} />
                  </div>
                  <Link
                    href={`mailto:${settings?.company_email}`}
                    className="text-sm text-white/65 hover:text-primary"
                  >
                    {settings?.company_email}
                  </Link>
                </div>
              )}

              {settings?.company_tel1 && settings?.company_tel2 && (
                <div className="flex items-center gap-4">
                  <div className="footerSocialLinks">
                    <TbPhoneCall size={24} />
                  </div>
                  <div className="flex flex-col gap-1">
                    <Link
                      href={`tel:${settings?.company_tel1}`}
                      className="text-sm text-white/65 hover:text-primary"
                    >
                      {settings?.company_tel1}
                    </Link>
                    <Link
                      href={`tel:${settings?.company_tel2}`}
                      className="text-sm text-white/65 hover:text-primary"
                    >
                      {settings?.company_tel2}
                    </Link>
                  </div>
                </div>
              )}

              <div>
                <h3 className="text-lg sm:text-xl font-medium mb-6">
                  {t("socialMedia")}
                </h3>
                <div className="flex flex-wrap gap-4">
                  {settings?.facebook_link && (
                    <Link
                      href={settings?.facebook_link}
                      className="footerSocialLinks"
                    >
                      <FaFacebook size={24} />
                    </Link>
                  )}
                  {settings?.instagram_link && (
                    <Link
                      href={settings?.instagram_link}
                      className="footerSocialLinks"
                    >
                      <FaInstagram size={22} />
                    </Link>
                  )}

                  {settings?.x_link && (
                    <Link
                      href={settings?.x_link}
                      className="footerSocialLinks"
                    >
                      <FaSquareXTwitter size={22} />
                    </Link>
                  )}
                  {settings?.linkedin_link && (
                    <Link
                      href={settings?.linkedin_link}
                      className="footerSocialLinks"
                    >
                      <FaLinkedin size={24} />
                    </Link>
                  )}
                  {settings?.pinterest_link && (
                    <Link
                      href={settings?.pinterest_link}
                      className="footerSocialLinks"
                    >
                      <FaPinterest size={24} />
                    </Link>
                  )}
                </div>
              </div>

              {settings?.google_map_iframe_link && (
                <iframe
                  src={settings?.google_map_iframe_link}
                  width="100%"
                  height="200"
                  className="aspect-[432/189] w-full rounded mt-6"
                />
              )}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
};

export default ContactUs;
