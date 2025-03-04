import { t } from "@/utils";

const NoChatFound = () => {
    return (
        <div className="col-12 text-center no_chat_wrapper">
            <div className="no_data_found_text">
                <h3>{t('noChatFound')}</h3>
                <span>{t('startConversation')}</span>
            </div>
        </div>
    );
};

export default NoChatFound;
