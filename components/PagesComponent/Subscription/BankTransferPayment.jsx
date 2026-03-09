import { showBankDetails } from "@/redux/reducer/globalStateSlice";
import { FaAngleRight } from "react-icons/fa";
import { AiOutlineBank } from "react-icons/ai"
import { t } from "@/utils";


const BankTransferPayment = ({ closePaymentModal }) => {
  const handleBankTransfer = () => {
    closePaymentModal();
    showBankDetails();
  };

  return (
    <button onClick={handleBankTransfer} className="flex items-center gap-2 justify-between p-2">
      <div className="flex items-center gap-2">
        <AiOutlineBank size={30} />
        <span className="text-lg font-semibold">{t("bankTransfer")}</span>
      </div>
      <FaAngleRight size={18} className="rtl:scale-x-[-1]" />
    </button>
  );
};

export default BankTransferPayment;
