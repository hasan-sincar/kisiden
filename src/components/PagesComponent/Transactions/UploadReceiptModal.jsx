import { t } from '@/utils';
import { updateBankTransferApi } from '@/utils/api';
import { Modal } from 'antd'
import { useCallback, useState } from 'react';
import { useDropzone } from 'react-dropzone';
import toast from 'react-hot-toast';
import { MdClose } from 'react-icons/md';


const UploadReceiptModal = ({ IsUploadRecipt, setIsUploadRecipt, transactionId, setData }) => {



    const [selectedFile, setSelectedFile] = useState(null);
    const [isUploading, setIsUploading] = useState(false);
    const [preview, setPreview] = useState(null);

    const onDrop = useCallback((acceptedFiles) => {
        const file = acceptedFiles[0];
        setSelectedFile(file);

        // Create preview URL
        const previewUrl = URL.createObjectURL(file);
        setPreview(previewUrl);
    }, []);

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop,
        accept: {
            'image/*': ['.png', '.jpg', '.jpeg']
        },
        maxFiles: 1,
        multiple: false
    });



    const CloseIcon = (
        <div className="close_icon_cont">
            <MdClose size={24} color="black" />
        </div>
    );


    const handleCloseModal = () => {
        setIsUploadRecipt(false)
    }

    const clearSelection = () => {
        if (preview) {
            URL.revokeObjectURL(preview);
        }
        setSelectedFile(null);
        setPreview(null);
    };


    const handleReceiptSubmit = async() => {
        try {
            setIsUploading(true)
            const res = await updateBankTransferApi.updateBankTransfer({
                payment_transection_id: transactionId,
                payment_receipt: selectedFile
            })

            if (res?.data?.error === false) {
                setData(prevData =>
                    prevData.map(item =>
                        item.id === transactionId ? res?.data?.data : item
                    )
                );
                toast.success(t('receiptUploaded'))
                setIsUploadRecipt(false)
            }
            else{
                toast.error(t('failedToUploadReceipt'))
            }
        } catch (error) {
            console.log('Failed To Upload Receipt', error)
        } finally{
            setIsUploading(false)
        }
    }



    return (

        <Modal
            centered
            open={IsUploadRecipt}
            closeIcon={CloseIcon}
            colorIconHover="transparent"
            className="ant_register_modal"
            onCancel={handleCloseModal}
            footer={null}
            maskClosable={false}
        >

            <h1 className="head_loc">{t('uploadPaymentReceipt')}</h1>
            <p className="bankDetDescription">
                {t('uploadReceiptDescription')}
            </p>

            <div className="receipt-upload-container">
                {!selectedFile ? (
                    <div
                        {...getRootProps()}
                        className={`receipt-dropzone ${isDragActive ? 'receipt-dropzone-active' : ''}`}
                    >
                        <input {...getInputProps()} />
                        {/* <FileImage className="receipt-icon" /> */}
                        <p className="receipt-upload-prompt">
                            {isDragActive ? t('dropYourReceiptHere') : t('dragAndDropReceipt')}
                        </p>
                        <p className="receipt-upload-alternative">
                            {t('clickToSelect')}
                        </p>
                    </div>
                ) : (
                    <div className="receipt-preview-wrapper">
                        <img
                            src={preview}
                            alt="Receipt preview"
                            className="receipt-image"
                        />
                        <button
                            className="receipt-remove-button"
                            onClick={clearSelection}
                        >
                            <MdClose size={24} />
                        </button>
                    </div>
                )}
                <button className='sv_chng_btn' onClick={handleReceiptSubmit} disabled={!selectedFile || isUploading}>{t('submit')}</button>
            </div>

        </Modal>

    )
}

export default UploadReceiptModal