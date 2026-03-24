import { IoInformationCircleOutline } from "react-icons/io5";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { useDropzone } from "react-dropzone";
import { HiOutlineUpload } from "react-icons/hi";
import { MdClose } from "react-icons/md";
import { toast } from "sonner";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";

const ComponentFour = ({
  uploadedImages,
  setUploadedImages,
  otherImages,
  setOtherImages,
  setStep,
  handleGoBack,
}) => {
  const onDrop = (acceptedFiles) => {
    if (acceptedFiles.length == 0) {
      toast.error(t("wrongFile"));
    } else {
      setUploadedImages(acceptedFiles);
    }
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      "image/jpeg": [".jpeg", ".jpg"],
      "image/png": [".png"],
    },
    multiple: false,
  });

  const files = () =>
    uploadedImages?.map((file, index) => (
      <div key={index} className="relative">
        <CustomImage
          width={591}
          height={350}
          className="rounded-2xl object-cover aspect-[591/350]"
          src={URL.createObjectURL(file)}
          alt={file.name}
        />
        <div className="absolute top-2 left-2 flex gap-2 items-center">
          <button
            className="bg-white p-1 rounded-full"
            onClick={() => removeImage(index)}
          >
            <MdClose size={14} color="black" />
          </button>
          <div className="text-white text-xs flex flex-col">
            <span>{file.name}</span>
            <span>{Math.round(file.size / 1024)} KB</span>
          </div>
        </div>
      </div>
    ));

  const removeImage = (index) => {
    setUploadedImages((prevImages) => prevImages.filter((_, i) => i !== index));
  };

  const onOtherDrop = (acceptedFiles) => {
    const currentFilesCount = otherImages.length; // Number of files already uploaded
    const remainingSlots = 5 - currentFilesCount; // How many more files can be uploaded

    if (remainingSlots === 0) {
      // Show error if the limit has been reached
      toast.error(t("imageLimitExceeded"));
      return;
    }

    if (acceptedFiles.length > remainingSlots) {
      // Show error if the number of new files exceeds the remaining slots
      toast.error(
        t("youCanUpload") + " " + remainingSlots + " " + t("moreImages")
      );
      return;
    }
    // Add the new files to the state
    setOtherImages((prevImages) => [...prevImages, ...acceptedFiles]);
  };

  const {
    getRootProps: getRootOtheProps,
    getInputProps: getInputOtherProps,
    isDragActive: isDragOtherActive,
  } = useDropzone({
    onDrop: onOtherDrop,
    accept: {
      "image/jpeg": [".jpeg", ".jpg"],
      "image/png": [".png"],
    },
    multiple: true,
  });

  const removeOtherImage = (index) => {
    setOtherImages((prevImages) => prevImages.filter((_, i) => i !== index));
  };

  const filesOther = () =>
    otherImages &&
    otherImages?.map((file, index) => (
      <div key={`${file.name}-${file.size}`} className="relative">
        <CustomImage
          width={591}
          height={350}
          className="rounded-2xl object-cover aspect-[591/350]"
          src={URL.createObjectURL(file)}
          alt={file.name}
        />
        <div className="absolute top-2 left-2 flex gap-2 items-center">
          <button
            className="bg-white p-1 rounded-full"
            onClick={() => removeOtherImage(index)}
          >
            <MdClose size={22} color="black" />
          </button>
          <div className="text-white text-xs flex flex-col">
            <span>{file.name}</span>
            <span>{Math.round(file.size / 1024)} KB</span>
          </div>
        </div>
      </div>
    ));

  return (
    <div className="flex flex-col gap-8">
      <div className="grid grid-col-1 md:grid-cols-2 gap-4">
        <div className="flex flex-col gap-3">
          <span className="requiredInputLabel text-sm font-semibold">
            {t("mainPicture")}
          </span>
          <div className="border-2 border-dashed rounded-lg p-2">
            <div
              {...getRootProps()}
              className="flex flex-col min-h-[175px] items-center justify-center cursor-pointer"
              style={{ display: uploadedImages.length > 0 ? "none" : "" }}
            >
              <input {...getInputProps()} />
              {isDragActive ? (
                <span className="text-primary font-medium">
                  {t("dropFiles")}
                </span>
              ) : (
                <div className="flex flex-col gap-2 items-center text-center">
                  <span className="text-muted-foreground">
                    {t("dragFiles")}
                  </span>
                  <span className="text-muted-foreground">{t("or")}</span>
                  <div className="flex items-center text-primary">
                    <HiOutlineUpload size={24} />
                    <span className="font-medium">{t("upload")}</span>
                  </div>
                </div>
              )}
            </div>
            <div>{files()}</div>
          </div>
        </div>
        <div className="flex flex-col gap-3">
          <span className="flex items-center gap-1 font-semibold text-sm">
            {t("otherPicture")}
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger asChild>
                  <span className="inline-flex">
                    <IoInformationCircleOutline size={22} />
                  </span>
                </TooltipTrigger>
                <TooltipContent
                  side="top"
                  align="center"
                  className="font-normal"
                >
                  <p>{t("maxOtherImages")}</p>
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
          </span>
          <div className="border-2 border-dashed rounded-lg p-2">
            <div
              {...getRootOtheProps()}
              className="flex flex-col items-center justify-center min-h-[175px] cursor-pointer"
              style={{ display: otherImages.length >= 5 ? "none" : "" }}
            >
              <input {...getInputOtherProps()} />
              {isDragOtherActive ? (
                <span className="text-primary font-medium">
                  {t("dropFiles")}
                </span>
              ) : (
                <div className="flex flex-col gap-2 items-center text-center">
                  <span className="text-muted-foreground">
                    {t("dragFiles")}
                  </span>
                  <span className="text-muted-foreground">{t("or")}</span>
                  <div className="flex items-center text-primary">
                    <HiOutlineUpload size={24} />
                    <span className="font-medium">{t("upload")}</span>
                  </div>
                </div>
              )}
            </div>
            <div className="flex flex-col gap-3">{filesOther()}</div>
          </div>
        </div>
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
          onClick={() => setStep(5)}
        >
          {t("next")}
        </button>
      </div>
    </div>
  );
};

export default ComponentFour;