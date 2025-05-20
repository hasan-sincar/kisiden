'use client'
import NoData from "@/components/NoDataFound/NoDataFound";
import { getIsShowBankDetails, hideBankDetails } from "@/redux/reuducer/globalStateSlice"
import { t } from "@/utils";
import { createPaymentIntentApi } from "@/utils/api";
import { Modal } from "antd";
import { useRouter } from "next/navigation";
import { useState } from "react";
import toast from "react-hot-toast";
import { MdClose } from "react-icons/md";
import { useSelector } from "react-redux"

const BankDetailsModal = ({ priceData, bankDetails }) => {

    const router = useRouter()
    const IsShowBankDetails = useSelector(getIsShowBankDetails)
    const IsBankDetails = bankDetails && Object.keys(bankDetails).length > 0;
    const [IsConfirmingPayment, setIsConfirmingPayment] = useState(false)

    const CloseIcon = (
        <div className="close_icon_cont">
            <MdClose size={24} color="black" />
        </div>
    );

    const handleConfirmPayment = async () => {
        try {
            setIsConfirmingPayment(true)
            const res = await createPaymentIntentApi.createIntent({
                package_id: priceData.id,
                payment_method: "bankTransfer",
            });
            if (res?.data?.error === false) {
                toast.success(t('paymentConfirmed'))
                hideBankDetails()
                router.push('/transactions')
            }
            else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.log('Failed to confirm Payment', error)
        } finally {
            setIsConfirmingPayment(false)
        }
    }

    return (

        <Modal
            centered
            open={IsShowBankDetails}
            closeIcon={CloseIcon}
            colorIconHover="transparent"
            className="ant_register_modal"
            onCancel={hideBankDetails}
            footer={null}
            maskClosable={false}
        >

            {
                    IsBankDetails ?
                        <>
                            <h1 className="head_loc">{t('bankAccountDetails')}</h1>
                            <p className="bankDetDescription">
                                {t('pleaseTransferAmount')}
                            </p>
                            <div className="bankDetCont">
                                <div className="bankDetItem">
                                    <p className="bankItemLabel">{t('accountHolder')}</p>
                                    <p className="bankItemValue">{bankDetails?.account_holder_name}</p>
                                </div>
                                <div className="bankDetItem">
                                    <p className="bankItemLabel">{t('accountNumber')}</p>
                                    <p className="bankItemValue">{bankDetails?.account_number}</p>
                                </div>
                                <div className="bankDetItem">
                                    <p className="bankItemLabel">{t('bankName')}</p>
                                    <p className="bankItemValue">{bankDetails?.bank_name}</p>
                                </div>
                                <div className="bankDetItem">
                                    <p className="bankItemLabel">SWIFT/IFSC Code</p>
                                    <p className="bankItemValue">{bankDetails?.ifsc_swift_code}</p>
                                </div>
                            </div>
                            <div className='report_btns'>
                                <button className='cancel_button' onClick={hideBankDetails}>{t('cancel')}</button>
                                <button className='follow_button' disabled={IsConfirmingPayment} onClick={handleConfirmPayment} >
                                    {IsConfirmingPayment ? t('confirmingPayment') : t('confirmPayment')}
                                </button>
                            </div>

                        </>
                        :
                        <NoData name={t('bankAccountDetails')} />
            }
        </Modal>
    )
}

export default BankDetailsModal