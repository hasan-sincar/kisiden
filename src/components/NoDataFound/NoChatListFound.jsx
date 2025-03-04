import { placeholderImage, t } from "@/utils";
import Image from "next/image";
import NoDataFound from '../../../public/assets/no_data_found_illustrator.svg'

const NoChatListFound = () => {
  return (
    <div className="col-12 text-center no_data_conatiner">
      <div>
        <Image
          loading="lazy"
          src={NoDataFound}
          alt="no_img"
          width={200}
          height={200}
          onError={placeholderImage}
        />
      </div>
      <div className="no_data_found_text">
        <h3>{t("noConversationsFound")}</h3>
        <span>{t("noChatsAvailable")}</span>
      </div>
    </div>
  );
};

export default NoChatListFound;
