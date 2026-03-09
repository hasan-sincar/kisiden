import {
  Dialog,
  DialogContent,
} from "@/components/ui/dialog";
import trueGif from "../../../public/assets/true.gif";
import CustomLink from "@/components/Common/CustomLink";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";

const AdEditSuccessModal = ({
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
        className="[&>button]:hidden lgmax-w-[100px]"
        onInteractOutside={(e) => {
          e.preventDefault();
        }}
      >
        <div className="flex flex-col items-center justify-center gap-4">
          <div className="flex flex-col justify-center items-center">
            <CustomImage
              src={trueGif}
              alt="success"
              height={176}
              width={176}
              className="h-44 w-44"
            />
            <h2 className="text-3xl font-semibold">{t("adEditedSuccess")}</h2>
          </div>
          <CustomLink
            href={`/my-listing/${createdAdSlug}`}
            className="py-3 px-6 bg-primary text-white rounded-md"
          >
            {t("viewAd")}
          </CustomLink>
          <CustomLink href="/" className="">
            {t("backToHome")}
          </CustomLink>
        </div>
      </DialogContent>
    </Dialog>
  );
};

export default AdEditSuccessModal;
