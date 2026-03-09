import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import trueGif from "../../../public/assets/true.gif";
import CustomLink from "@/components/Common/CustomLink";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";

const AdSuccessModal = ({
  openSuccessModal,
  setOpenSuccessModal,
  createdAdSlug,
}) => {
  const closeSuccessModal = () => {
    setOpenSuccessModal(false);
  };

  return (
    <Dialog open={openSuccessModal} onOpenChange={closeSuccessModal}>
      <DialogContent
        className="[&>button]:hidden !max-w-[520px] py-[50px] px-[30px] sm:px-[80px]"
        onInteractOutside={(e) => {
          e.preventDefault();
        }}
      >
        <DialogHeader className="flex flex-col gap-4 items-center">
          <CustomImage
            src={trueGif}
            alt="success"
            height={176}
            width={176}
            className="h-44 w-44"
          />
          <DialogTitle className="text-3xl font-semibold text-center !p-0 mt-0">
            {t("adPostedSuccess")}
          </DialogTitle>
          <CustomLink
            href={`/my-listing/${createdAdSlug}`}
            className="py-3 px-6 bg-primary text-white rounded-md"
          >
            {t("viewAd")}
          </CustomLink>
          <CustomLink href="/" className="">
            {t("backToHome")}
          </CustomLink>
        </DialogHeader>
      </DialogContent>
    </Dialog>
  );
};

export default AdSuccessModal;
