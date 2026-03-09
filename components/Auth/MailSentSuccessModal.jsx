import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "../ui/dialog";
import mainSentImg from "../../public/assets/Mail Verification.svg";
import { t } from "@/utils";
import CustomImage from "../Common/CustomImage";

const MailSentSuccessModal = ({ IsMailSentSuccess, setIsMailSentSuccess }) => {
  return (
    <Dialog open={IsMailSentSuccess} onOpenChange={setIsMailSentSuccess}>
      <DialogContent onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle className="sr-only"></DialogTitle>
          <DialogDescription className="sr-only"></DialogDescription>
          <div className="flex flex-col gap-3 items-center justify-center">
            <CustomImage
              src={mainSentImg}
              alt="Verification Mail sent"
              width={300}
              height={195}
              className="aspect-[300/195] object-contain"
            />
            <h1 className="text-2xl font-medium">{t("youveGotMail")}</h1>
            <p className="opacity-65">{t("verifyAccount")}</p>
          </div>
        </DialogHeader>
      </DialogContent>
    </Dialog>
  );
};

export default MailSentSuccessModal;
