"use client";
import {
  FacebookIcon,
  FacebookShareButton,
  TwitterShareButton,
  WhatsappIcon,
  WhatsappShareButton,
  XIcon,
} from "react-share";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { IoShareSocialOutline } from "react-icons/io5";
import { CiLink } from "react-icons/ci";
import { toast } from "sonner";
import { t } from "@/utils/index";
import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import { useSelector } from "react-redux";

const ShareDropdown = ({ url, title, headline, companyName, className }) => {
  const [open, setOpen] = useState(false);
  const searchParams = useSearchParams();
  const langCode = searchParams.get("lang");
  const isRTL = useSelector(getIsRtl);

  const handleCopyUrl = async () => {
    try {
      await navigator.clipboard.writeText(url + "?share=true&lang=" + langCode);
      toast.success(t("copyToClipboard"));
      setOpen(false);
    } catch (error) {
      console.error("Error copying to clipboard:", error);
    }
  };

  const handleShare = () => {
    setOpen(false);
  };

  return (
    <DropdownMenu open={open} onOpenChange={setOpen}>
      <DropdownMenuTrigger asChild>
        <button className={className}>
          <IoShareSocialOutline size={20} />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align={isRTL ? "start" : "end"}>
        <DropdownMenuItem>
          <FacebookShareButton
            className="w-full"
            url={url}
            hashtag={title}
            onClick={handleShare}
          >
            <div className="flex items-center gap-2">
              <FacebookIcon className="!size-6" round />
              <span>{t("facebook")}</span>
            </div>
          </FacebookShareButton>
        </DropdownMenuItem>
        <DropdownMenuItem>
          <TwitterShareButton
            className="w-full"
            url={url}
            title={headline}
            onClick={handleShare}
          >
            <div className="flex items-center gap-2">
              <XIcon className="!size-6" round />
              <span>X</span>
            </div>
          </TwitterShareButton>
        </DropdownMenuItem>
        <DropdownMenuItem>
          <WhatsappShareButton
            className="w-100"
            url={url}
            title={headline}
            hashtag={companyName}
            onClick={handleShare}
          >
            <div className="flex items-center gap-2">
              <WhatsappIcon className="!size-6" round />
              <span>{t("whatsapp")}</span>
            </div>
          </WhatsappShareButton>
        </DropdownMenuItem>
        <DropdownMenuItem>
          <button
            className="flex items-center gap-2 w-full"
            onClick={handleCopyUrl}
          >
            <CiLink className="!size-6" />
            <span>{t("copyLink")}</span>
          </button>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export default ShareDropdown;
