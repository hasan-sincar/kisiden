import { useEffect, useRef, useState } from "react";
import parse from "html-react-parser";
import { t } from "@/utils";
const ProductDescription = ({ productDetails }) => {
  const [showFullDescription, setShowFullDescription] = useState(false);
  const [isOverflowing, setIsOverflowing] = useState(false);
  const descriptionRef = useRef(null);

  const translated_item = productDetails?.translated_item;

  const fullDescription =
    translated_item?.description?.replace(/\n/g, "<br />") ||
    productDetails?.description?.replace(/\n/g, "<br />");

  useEffect(() => {
    const descriptionBody = descriptionRef.current;
    if (descriptionBody) {
      setIsOverflowing(
        descriptionBody.scrollHeight > descriptionBody.clientHeight
      );
    }
  }, [fullDescription]);

  const toggleDescription = () => {
    setShowFullDescription((prev) => !prev);
  };

  return (
    <div className="flex flex-col gap-4">
      <span className="text-2xl font-medium">{t("description")}</span>
      <div
        className={`${
          showFullDescription ? "h-[100%]" : "max-h-[72px]"
        } max-w-full prose lg:prose-lg overflow-hidden`}
        ref={descriptionRef}
      >
        {parse(fullDescription || "")}
      </div>
      {isOverflowing && (
        <div className=" flex justify-center items-center">
          <button
            onClick={toggleDescription}
            className="text-primary font-bold text-base"
          >
            {showFullDescription ? t("seeLess") : t("seeMore")}
          </button>
        </div>
      )}
    </div>
  );
};

export default ProductDescription;
