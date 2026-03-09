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
import { HiOutlineUpload } from "react-icons/hi";
import { MdOutlineAttachFile } from "react-icons/md";
import CustomLink from "@/components/Common/CustomLink";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { handleKeyDown, inpNum, t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";

const EditComponentTwo = ({
  customFields,
  setExtraDetails,
  handleGoBack,
  filePreviews,
  setFilePreviews,
  submitExtraDetails,
  currentExtraDetails,
  langId,
  defaultLangId,
}) => {
  const write = (fieldId, value) =>
    setExtraDetails((prev) => ({
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
      setFilePreviews((prevPreviews) => ({
        ...prevPreviews,
        [id]: {
          url: fileUrl,
          isPdf: /\.pdf$/i.test(file.name),
        },
      }));
      write(id, file);
    }
  };

  const handleCheckboxChange = (id, value, checked) => {
    const list = currentExtraDetails[id] || [];
    const next = checked
      ? list.includes(value)
        ? list
        : [...list, value]
      : list.filter((v) => v !== value);
    write(id, next);
  };

  const handleChange = (id, value) => write(id, value ?? "");

  const renderCustomFields = (field) => {
    let {
      id,
      translated_name,
      name,
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
      value: currentExtraDetails[id] || "",
      ...(type === "number"
        ? { min: min_length, max: max_length }
        : { minLength: min_length, maxLength: max_length }),
    };

    switch (type) {
      case "number":
        return (
          <div className="flex flex-col">
            <Input
              type={type}
              inputMode="numeric"
              placeholder={`${t("enter")} ${translated_name || name}`}
              {...inputProps}
              onKeyDown={(e) => handleKeyDown(e, max_length)}
              onKeyPress={(e) => inpNum(e)}
            />
            {max_length && (
              <span className="self-end text-sm text-muted-foreground">
                {`${currentExtraDetails[id]?.length ?? 0}/${max_length}`}
              </span>
            )}
          </div>
        );
      case "textbox":
        return (
          <div className=" flex flex-col">
            <Textarea
              placeholder={`${t("enter")} ${translated_name || name}`}
              {...inputProps}
            />
            {max_length && (
              <span className="self-end text-sm text-muted-foreground">
                {`${currentExtraDetails[id]?.length ?? 0}/${max_length}`}
              </span>
            )}
          </div>
        );
      case "dropdown":
        return (
          <div className="w-full">
            <Select
              id={id}
              name={id}
              value={currentExtraDetails[id] || ""}
              onValueChange={(value) => handleChange(id, value)}
            >
              <SelectTrigger className="outline-none focus:outline-none">
                <SelectValue
                  className="font-medium"
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
                      className="font-medium"
                      key={option}
                      value={option}
                    >
                      {translated_value[index] || option}
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
              const uniqueId = `${id}-${value}-${index}`;
              return (
                <div key={uniqueId} className="flex gap-1 items-center">
                  <Checkbox
                    id={uniqueId}
                    value={value}
                    onCheckedChange={(checked) =>
                      handleCheckboxChange(id, value, checked)
                    }
                    checked={currentExtraDetails[id]?.includes(value)}
                  />
                  <label
                    htmlFor={uniqueId}
                    className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                  >
                    {translated_value[index] || value}
                  </label>
                </div>
              );
            })}
          </div>
        );
      case "radio":
        return (
          <RadioGroup
            value={currentExtraDetails[id] || ""}
            onValueChange={(value) => handleChange(id, value)}
            className="flex gap-2 flex-wrap"
          >
            {values?.map((option, index) => {
              const uniqueId = `${id}-${option}-${index}`;
              return (
                <div
                  key={uniqueId}
                  className="flex items-center gap-2 flex-wrap"
                >
                  <RadioGroupItem
                    value={option}
                    id={uniqueId}
                    className="sr-only peer "
                  />
                  <label
                    htmlFor={uniqueId}
                    className={`${currentExtraDetails[id] === option
                      ? "bg-primary text-white"
                      : ""
                      } border rounded-md px-4 py-2 cursor-pointer transition-colors`}
                  >
                    {translated_value[index] || option}
                  </label>
                </div>
              );
            })}
          </RadioGroup>
        );

      case "fileinput":
        const fileUrl = filePreviews[id]?.url;
        return (
          <>
            <label htmlFor={id} className="flex gap-2 items-center">
              <div className="cursor-pointer border px-2.5 py-1 rounded">
                <HiOutlineUpload size={24} fontWeight="400" />
              </div>
              {filePreviews[id] && (
                <div className="flex items-center gap-1 text-sm flex-nowrap break-words">
                  {filePreviews[id]?.isPdf ? (
                    <>
                      <MdOutlineAttachFile />
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
                      key={fileUrl}
                      src={fileUrl}
                      alt="Preview"
                      className="h-9 w-9"
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
              name={name}
              className="hidden"
              onChange={(e) => handleFileChange(id, e.target.files[0])}
              accept=".jpg,.jpeg,.png,.svg,.pdf"
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

  return (
    <div className="flex flex-col gap-8">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {customFields?.map((field) => {
          if (langId !== defaultLangId && field.type !== "textbox") return null;
          return (
            <div className="flex flex-col w-full gap-2" key={field?.id}>
              <div className="flex gap-2 items-center">
                <CustomImage
                  src={field?.image}
                  alt={field?.name}
                  height={28}
                  width={28}
                  className="h-7 w-7 rounded-sm"
                />
                <Label
                  className={`${field?.required === 1 && defaultLangId === langId
                    ? "requiredInputLabel"
                    : ""
                    }`}
                >
                  {field?.translated_name || field?.name}
                </Label>
              </div>
              {renderCustomFields(field)}
            </div>
          );
        })}
      </div>
      <div className="flex justify-end gap-3">
        <button
          className="bg-black text-white px-4 py-2 rounded-md text-xl font-light"
          onClick={handleGoBack}
        >
          {t("back")}
        </button>
        <button
          className="bg-primary text-white  px-4 py-2 rounded-md text-xl font-light"
          onClick={submitExtraDetails}
        >
          {t("next")}
        </button>
      </div>
    </div>
  );
};
export default EditComponentTwo;
