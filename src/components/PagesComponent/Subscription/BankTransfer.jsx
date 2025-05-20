import { showBankDetails } from "@/redux/reuducer/globalStateSlice"
import { t } from "@/utils"
import { AiOutlineBank } from "react-icons/ai"
import { FaAngleRight } from "react-icons/fa6"

const BankTransfer = ({ closePaymentModal }) => {

    const handleBankTransfer = () => {
        closePaymentModal()
        showBankDetails()
    }

    return (
        <div className="col-12">
            <button onClick={handleBankTransfer}>
                <div className="payment_details">
                    <AiOutlineBank size={30} />
                    <span>{t("bankTransfer")}</span>
                </div>
                <div className="payment_icon">
                    <FaAngleRight size={18} />
                </div>
            </button>
        </div>
    )
}

export default BankTransfer