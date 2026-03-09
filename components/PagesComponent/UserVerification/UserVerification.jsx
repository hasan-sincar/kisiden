"use client";
import BreadCrumb from "@/components/BreadCrumb/BreadCrumb";
import {
  handleKeyDown,
  inpNum,
  prefillVerificationDetails,
  prepareCustomFieldFiles,
  prepareCustomFieldTranslations,
  t,
  validateExtraDetails,
} from "@/utils";
import {
  getVerificationFiledsApi,
  getVerificationStatusApi,
  sendVerificationReqApi,
} from "@/utils/api";
import { useEffect, useState } from "react";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { toast } from "sonner";
import { MdOutlineAttachFile } from "react-icons/md";
import { HiOutlineUpload } from "react-icons/hi";
import CustomLink from "@/components/Common/CustomLink";
import Layout from "@/components/Layout/Layout";
import Checkauth from "@/HOC/Checkauth";
import AdLanguageSelector from "../AdsListing/AdLanguageSelector";
import {
  getDefaultLanguageCode,
  getLanguages,
} from "@/redux/reducer/settingSlice";
import { useSelector } from "react-redux";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import PageLoader from "@/components/Common/PageLoader";
import { getCurrentLangCode } from "@/redux/reducer/languageSlice";
import CustomImage from "@/components/Common/CustomImage";
import { useNavigate } from "@/components/Common/useNavigate";

const UserVerification = () => {
  const { navigate } = useNavigate();
  const [UserVeriFields, setUserVeriFields] = useState([]);
  const [filePreviews, setFilePreviews] = useState({});
  const [VerificationStatus, setVerificationStatus] = useState("");
  const [verificationLoading, setVerificationLoading] = useState(false);
  const [isVerifying, setIsVerifying] = useState(false);

  const langCode = useSelector(getCurrentLangCode);
  const languages = useSelector(getLanguages);
  const defaultLanguageCode = useSelector(getDefaultLanguageCode);
  const defaultLangId = languages?.find(
    (lang) => lang.code === defaultLanguageCode
  )?.id;
  const [langId, setLangId] = useState(defaultLangId);
  const [translations, setTranslations] = useState({
    [defaultLangId]: {},
  });

  const currentTranslation = translations[langId] || {};
  const hasTextbox = UserVeriFields.some((field) => field.type === "textbox");

  useEffect(() => {
    fetchVerificationData();
  }, [langCode]);

  const fetchVerificationData = async () => {
    try {
      setVerificationLoading(true);

      // Step 1: Fetch field definitions
      const fieldsRes = await getVerificationFiledsApi.getVerificationFileds();
      const fieldData = fieldsRes?.data?.data || [];
      setUserVeriFields(fieldData);

      // Step 2: Fetch verification values
      const statusRes = await getVerificationStatusApi.getVerificationStatus();
      const statusData = statusRes?.data?.data;
      const statusError = statusRes?.data?.error;

      if (statusError) {
        setVerificationStatus("not applied");
      } else {
        setVerificationStatus(statusData?.status);
      }

      const verification_fields = statusData?.verification_fields || [];

      // Step 3: Prepare translations
      const translationsToSet = prefillVerificationDetails({
        data: fieldData,
        languages,
        defaultLangId,
        extraFieldValue:
          statusData?.status === "not applied" ? [] : verification_fields,
        setFilePreviews,
      });

      setTranslations(translationsToSet);
    } catch (error) {
      console.log(error);
    } finally {
      setVerificationLoading(false);
    }
  };
  const renderCustomFields = (field) => {
    let {
      id,
      name,
      translated_name,
      type,
      translated_value,
      values,
      min_length,
      max_length,
    } = field;

    const inputProps = {
      id,
      name: id,
      onChange: (e) => handleChange(id, e.target.value),
      value: currentTranslation[id] || "",
      ...(type === "number"
        ? { min: min_length, max: max_length }
        : { minLength: min_length, maxLength: max_length }),
    };

    switch (type) {
      case "number":
        return (
          <div className="flex flex-col">
            <Input
              type="number"
              inputMode="numeric"
              placeholder={`${t("enter")} ${translated_name || name}`}
              {...inputProps}
              onKeyDown={(e) => handleKeyDown(e, max_length)}
              onKeyPress={(e) => inpNum(e)}
              className="border rounded-md px-4 py-2 outline-none"
            />
            {max_length && (
              <span className="flex justify-end text-muted-foreground text-sm">
                {`${currentTranslation[id]?.length ?? 0}/${max_length}`}
              </span>
            )}
          </div>
        );
      case "textbox": {
        return (
          <div className=" flex flex-col">
            <Textarea
              placeholder={`${t("enter")} ${translated_name || name}`}
              {...inputProps}
            />
            {max_length && (
              <span className=" flex justify-end text-muted-foreground text-sm">
                {`${currentTranslation[id]?.length ?? 0}/${max_length}`}
              </span>
            )}
          </div>
        );
      }

      case "dropdown":
        return (
          <div className="w-full">
            <Select
              value={currentTranslation[id] || ""}
              onValueChange={(value) => handleChange(id, value)}
              id={id}
              name={id}
            >
              <SelectTrigger className="outline-none focus:outline-none">
                <SelectValue
                  className="font-semibold"
                  placeholder={`${t("select")} ${translated_name || name}`}
                />
              </SelectTrigger>
              <SelectContent>
                <SelectGroup>
                  <SelectLabel value="">
                    {t("select")} {translated_name || name}
                  </SelectLabel>
                  {values?.map((option, index) => (
                    <SelectItem
                      id={option}
                      className="font-semibold"
                      key={index}
                      value={option}
                    >
                      {translated_value?.[index] || option}
                    </SelectItem>
                  ))}
                </SelectGroup>
              </SelectContent>
            </Select>
          </div>
        );
      case "checkbox":
        return (
          <div className="flex w-full flex-wrap gap-2">
            {values?.map((value, index) => {
              return (
                <div key={index} className="flex gap-1 items-center">
                  <Checkbox
                    id={id}
                    value={value}
                    onCheckedChange={(checked) =>
                      handleCheckboxChange(id, value, checked)
                    }
                    checked={currentTranslation[id]?.includes(value)}
                  />
                  <label
                    htmlFor="terms"
                    className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                  >
                    {translated_value?.[index] || value}
                  </label>
                </div>
              );
            })}
          </div>
        );
      case "radio":
        return (
          <RadioGroup
            value={currentTranslation[id] || ""}
            onValueChange={(value) => handleChange(id, value)}
            className="flex flex-wrap gap-3"
            id={id}
            name={id}
          >
            {values?.map((option, index) => (
              <div key={option} className="flex items-center">
                <RadioGroupItem
                  value={option}
                  id={option}
                  className="sr-only peer"
                />
                <label
                  htmlFor={option}
                  className={`${
                    currentTranslation[id] === option
                      ? "bg-primary text-white"
                      : "bg-white"
                  } border rounded-md px-4 py-2 cursor-pointer transition-colors flex items-center`}
                >
                  {translated_value?.[index] || option}
                </label>
              </div>
            ))}
          </RadioGroup>
        );
      case "fileinput":
        const fileUrl = filePreviews?.[langId]?.[id]?.url;
        const isPdf = filePreviews?.[langId]?.[id]?.isPdf;
        return (
          <>
            <label htmlFor={id} className="flex gap-2 items-center">
              <div className="flex items-center gap-1 cursor-pointer border border-gray-300 px-2.5 py-1 rounded w-fit">
                <HiOutlineUpload size={24} fontWeight="400" />
              </div>
              {fileUrl && (
                <div className="flex items-center gap-1 text-sm flex-nowrap break-words">
                  {isPdf ? (
                    <>
                      <MdOutlineAttachFile className="file_icon" />
                      <CustomLink
                        href={fileUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        {t("viewPdf")}
                      </CustomLink>
                    </>
                  ) : (
                    <CustomImage
                      src={fileUrl}
                      alt="Preview"
                      className="h-9 w-9 aspect-square"
                      height={36}
                      width={36}
                    />
                  )}
                </div>
              )}
            </label>
            <input
              type="file"
              id={id}
              name={id}
              className="hidden"
              onChange={(e) => handleFileChange(id, e.target.files[0])}
            />
            <span className="text-sm text-muted-foreground">
              {t("allowedFileType")}
            </span>
          </>
        );
      default:
        break;
    }
  };

  const write = (fieldId, value) =>
    setTranslations((prev) => ({
      ...prev,
      [langId]: {
        ...prev[langId],
        [fieldId]: value,
      },
    }));

  const handleFileChange = (id, file) => {
    if (file) {
      const allowedExtensions = /\.(jpg|jpeg|svg|png|pdf)$/i;
      if (!allowedExtensions.test(file.name)) {
        toast.error(t("notAllowedFile"));
        return;
      }
      const fileUrl = URL.createObjectURL(file);
      // Language-scoped preview
      setFilePreviews((prev) => ({
        ...prev,
        [langId]: {
          ...(prev[langId] || {}),
          [id]: {
            url: fileUrl,
            isPdf: /\.pdf$/i.test(file.name),
          },
        },
      }));
      write(id, file);
    }
  };

  const handleCheckboxChange = (id, value, checked) => {
    const list = currentTranslation[id] || [];
    const next = checked ? [...list, value] : list.filter((v) => v !== value);
    write(id, next);
  };

  const handleChange = (id, value) => write(id, value ?? "");

  const handleVerify = async () => {
    if (VerificationStatus === "approved") {
      toast.error(t("verificationDoneAlready"));
      return;
    }
    if (
      VerificationStatus === "resubmitted" ||
      VerificationStatus === "pending" ||
      VerificationStatus === "submitted"
    ) {
      toast.error(t("verificationAlreadyInReview"));
      return;
    }

    if (
      validateExtraDetails({
        languages,
        defaultLangId,
        extraDetails: translations,
        customFields: UserVeriFields,
        filePreviews,
      })
    ) {
      setIsVerifying(true);
      const verification_field_translations =
        prepareCustomFieldTranslations(translations);
      const verification_field_files = prepareCustomFieldFiles(
        translations,
        defaultLangId
      );
      try {
        const res = await sendVerificationReqApi.sendVerificationReq({
          verification_field_translations,
          verification_field_files,
        });
        if (res?.data?.error === false) {
          toast.success(res?.data?.message);
          navigate("/profile");
        }
      } catch (error) {
        console.log(error);
      } finally {
        setIsVerifying(false);
      }
    }
  };

  return (
    <Layout>
      <BreadCrumb title2={t("userVerification")} />

      {verificationLoading ? (
        <PageLoader />
      ) : (
        <div className="container mt-8">
          <div className="flex flex-col gap-6">
            <div className="flex items-center gap-3 justify-between">
              <h1 className="text-2xl font-semibold">
                {t("userVerification")}
              </h1>
              {hasTextbox && (
                <AdLanguageSelector
                  langId={langId}
                  setLangId={setLangId}
                  languages={languages}
                  setTranslations={setTranslations}
                />
              )}
            </div>
            <div className="grid grid-cols-1 md:grid-cols-12 gap-4 ">
              {UserVeriFields?.map((field) => {
                if (langId !== defaultLangId && field.type !== "textbox")
                  return null;

                return (
                  <div
                    className="col-span-1 md:col-span-6 flex flex-col gap-2"
                    key={field?.id}
                  >
                    <Label
                      className={`${
                        field?.is_required === 1 && defaultLangId === langId
                          ? "requiredInputLabel"
                          : ""
                      }`}
                      htmlFor={field?.id}
                    >
                      {field?.translated_name || field?.name}
                    </Label>
                    {renderCustomFields(field)}
                  </div>
                );
              })}
            </div>
            <div className="flex justify-end">
              <button
                className="px-4 py-2 bg-black text-white text-xl rounded-md disabled:opacity-60"
                disabled={isVerifying}
                onClick={handleVerify}
              >
                {isVerifying ? t("loading") : t("verify")}
              </button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
};

export default Checkauth(UserVerification);
