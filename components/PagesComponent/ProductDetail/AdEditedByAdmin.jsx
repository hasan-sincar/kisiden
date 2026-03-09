import { t } from "@/utils";
import { useEffect, useRef, useState } from "react";
import { LiaUserEditSolid } from "react-icons/lia";

const AdEditedByAdmin = ({ admin_edit_reason }) => {
  const textRef = useRef(null);
  const [isTextOverflowing, setIsTextOverflowing] = useState(false);
  const [isExpanded, setIsExpanded] = useState(false);

  useEffect(() => {
    const checkTextOverflow = () => {
      if (textRef.current && !isExpanded) {
        const element = textRef.current;
        const isOverflowing = element.scrollHeight > element.clientHeight;
        setIsTextOverflowing(isOverflowing);
      }
    };

    checkTextOverflow();
    window.addEventListener("resize", checkTextOverflow);

    return () => window.removeEventListener("resize", checkTextOverflow);
  }, [isExpanded]);

  return (
    <div className="flex items-start gap-3 border border-[#ffb3b3] bg-[#fff6f6] rounded-lg px-4 py-5 text-destructive">
      <LiaUserEditSolid className="size-12 text-destructive flex-shrink-0" />
      <div className="flex flex-col gap-1">
        <span className="font-medium text-[#d32f2f]">
          {t("adEditedBy")} <b>{t("admin")}</b>
        </span>
        <div className="text-sm text-destructive">
          <p ref={textRef} className={!isExpanded ? "line-clamp-2" : ""}>
            {admin_edit_reason}
          </p>
        </div>
        {isTextOverflowing && (
          <button
            className="text-sm font-medium text-destructive"
            onClick={() => setIsExpanded(!isExpanded)}
          >
            {isExpanded ? t("seeLess") : t("seeMore")}
          </button>
        )}
      </div>
    </div>
  );
};

export default AdEditedByAdmin;
