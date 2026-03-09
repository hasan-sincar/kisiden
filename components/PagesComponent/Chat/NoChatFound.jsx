import { Button } from "@/components/ui/button";
import { t } from "@/utils";
import { MdArrowBack } from "react-icons/md";

const NoChatFound = ({ handleBack, isLargeScreen }) => {
  return (
    <div className="flex flex-col gap-3 text-center items-center justify-center">
      <h5 className="text-primary text-2xl font-medium">{t("noChatFound")}</h5>
      <p>{t("startConversation")}</p>

      {!isLargeScreen && (
        <Button className="w-fit" onClick={handleBack}>
          <MdArrowBack size={20} className="rtl:scale-x-[-1]" />
          {t("back")}
        </Button>
      )}
    </div>
  );
};

export default NoChatFound;
