import CustomLink from "@/components/Common/CustomLink";
import { BiHeart } from "react-icons/bi";
import { RxEyeOpen } from "react-icons/rx";
import { t } from "@/utils";
import CustomImage from "@/components/Common/CustomImage";
import GetMyAdStatus from "./GetMyAdStatus";
import {
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuTrigger,
} from "@/components/ui/context-menu";
import { Checkbox } from "@/components/ui/checkbox";
import { RotateCcw, Trash2, CheckSquare } from "lucide-react";

const MyAdsCard = ({
  data,
  isApprovedSort,
  isSelected = false,
  isSelectable = false,
  onSelectionToggle,
  onContextMenuAction,
}) => {
  const isJobCategory = Number(data?.category?.is_job_category) === 1;
  const isAdminEdited = Number(data?.is_edited_by_admin) === 1;
  const translated_item = data?.translated_item;

  const isHidePrice = isJobCategory
    ? !data?.formatted_salary_range
    : !data?.formatted_price;

  const status = data?.status;
  const isExpired = status === "expired";

  const price = isJobCategory
    ? data?.formatted_salary_range
    : data?.formatted_price;

  // Card content JSX to avoid duplication
  const cardContent = (
    <div
      className={`relative border flex flex-col gap-2 rounded-xl p-2 hover:shadow-md transition-all duration-200 ${
        isSelected ? "ring-2 ring-primary bg-primary/5" : ""
      }`}
    >
      {/* Selection checkbox - only show in selection mode */}
      {isSelectable && (
        <div className="absolute top-2 left-2 z-10">
          <Checkbox
            checked={isSelected}
            onCheckedChange={onSelectionToggle}
            className="bg-white shadow-sm border-2 border-primary data-[state=checked]:bg-primary data-[state=checked]:border-primary"
          />
        </div>
      )}

      {/* Main card content */}
      <CustomLink
        href={`/my-listing/${data?.slug}`}
        className="flex flex-col gap-2"
        onClick={(e) => {
          if (isSelectable) {
            e.preventDefault();
            onSelectionToggle();
          } else {
            // For navigation, ensure the event propagates properly
            // Don't prevent default or stop propagation for normal clicks
          }
        }}
      >
        <CustomImage
          src={data?.image}
          width={220}
          height={220}
          alt={data?.image}
          className="w-full h-auto aspect-square rounded-sm object-cover"
        />

        <div className="flex items-center gap-2 flex-wrap">
          {status && (
            <GetMyAdStatus
              status={status}
              isApprovedSort={isApprovedSort}
              isFeature={data?.is_feature}
              isJobCategory={isJobCategory}
            />
          )}

          {isAdminEdited && (
            <div className="py-1 px-2 bg-red-400/15 rounded-sm text-destructive text-sm">
              {t("adminEdited")}
            </div>
          )}
        </div>

        {!isHidePrice && (
          <p className="font-medium line-clamp-1">
            {translated_item?.name || data?.name}
          </p>
        )}

        <div className="space-between gap-1">
          {isHidePrice ? (
            <p className="font-medium line-clamp-1">
              {translated_item?.name || data?.name}
            </p>
          ) : (
            <p
              className="font-semibold text-lg text-balance break-all line-clamp-2"
              title={price}
            >
              {price}
            </p>
          )}
          <div className="flex items-center gap-1 text-xs">
            <div className="flex items-center gap-1">
              <RxEyeOpen size={14} className="text-black/60" />
              <span>{data?.clicks}</span>
            </div>
            <div className="flex items-center gap-1">
              <BiHeart size={14} className="text-black/60" />
              <span>{data?.total_likes}</span>
            </div>
          </div>
        </div>
      </CustomLink>
    </div>
  );

  return (
    <ContextMenu modal={false}>
      <ContextMenuTrigger asChild disabled={!isExpired}>
        {cardContent}
      </ContextMenuTrigger>
      <ContextMenuContent>
        <ContextMenuItem
          onClick={() => onContextMenuAction("select")}
          className="flex items-center gap-2 cursor-pointer"
        >
          <CheckSquare className="size-4" />
          {isSelected ? "Deselect" : "Select"}
        </ContextMenuItem>
        <ContextMenuItem
          onClick={() => onContextMenuAction("renew")}
          className="flex items-center gap-2 cursor-pointer"
        >
          <RotateCcw className="size-4 text-primary" />
          <span className="text-primary">{t("renew")}</span>
        </ContextMenuItem>
        <ContextMenuItem
          onClick={() => onContextMenuAction("delete")}
          className="flex items-center gap-2 text-destructive focus:text-destructive cursor-pointer"
        >
          <Trash2 className="size-4" />
          {t("remove")}
        </ContextMenuItem>
      </ContextMenuContent>
    </ContextMenu>
  );
};

export default MyAdsCard;
