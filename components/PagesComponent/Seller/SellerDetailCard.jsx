import { Badge } from "@/components/ui/badge";
import { MdOutlineMailOutline, MdVerifiedUser } from "react-icons/md";
import { IoMdStar } from "react-icons/io";
import { FiPhoneCall } from "react-icons/fi";
import { extractYear, t } from "@/utils";
import { usePathname } from "next/navigation";
import { useSelector } from "react-redux";
import { getCompanyName } from "@/redux/reducer/settingSlice";
import ShareDropdown from "@/components/Common/ShareDropdown";
import CustomLink from "@/components/Common/CustomLink";
import CustomImage from "@/components/Common/CustomImage";
import Link from "next/link";

const SellerDetailCard = ({ seller, ratings }) => {
  const pathname = usePathname();
  const memberSinceYear = seller?.created_at
    ? extractYear(seller.created_at)
    : "";
  const currentUrl = `${process.env.NEXT_PUBLIC_WEB_URL}${pathname}`;
  const CompanyName = useSelector(getCompanyName);
  const FbTitle = seller?.name + " | " + CompanyName;


  return (
    <div className="rounded-lg border overflow-hidden">
      <div className="flex justify-between items-center p-4 bg-muted">
        <h1 className="text-lg font-bold">{t("seller_info")}</h1>
        <ShareDropdown
          url={currentUrl}
          title={FbTitle}
          headline={FbTitle}
          companyName={CompanyName}
          className="rounded-md p-2 border bg-white"
        />
      </div>

      {(seller?.is_verified === 1 || memberSinceYear) && (
        <div className="border-t p-4">
          <div className="flex items-center">
            {seller?.is_verified === 1 && (
              <Badge className="p-1 bg-[#FA6E53] flex items-center gap-1 rounded-md text-white text-sm">
                <MdVerifiedUser size={22} />
                {t("verified")}
              </Badge>
            )}

            {memberSinceYear && (
              <div className="ltr:ml-auto rtl:mr-auto text-sm text-muted-foreground">
                {t("memberSince")}: {memberSinceYear}
              </div>
            )}
          </div>
        </div>
      )}

      <div className="border-t flex flex-col justify-center items-center p-4 gap-4">
        <CustomImage
          src={seller?.profile}
          alt="Seller Image"
          width={120}
          height={120}
          className="aspect-square rounded-xl object-cover"
        />

        <div className="text-center w-full">
          <h3 className="text-xl font-bold">{seller?.name}</h3>
          <div className="flex items-center justify-center gap-1 text-sm mt-1">
            <IoMdStar />
            <span>
              {Number(seller?.average_rating).toFixed(2)} |{" "}
              {ratings?.data?.length} {t("ratings")}
            </span>
          </div>
        </div>
      </div>

      {seller?.show_personal_details === 1 &&
        (seller?.email || seller?.mobile) && (
          <div className="border-t p-4 flex flex-col gap-4">
            {seller?.email && (
              <div className="flex items-center gap-2">
                <div className="p-3 bg-muted rounded-md border">
                  <MdOutlineMailOutline className="size-4" />
                </div>
                <CustomLink
                  href={`mailto:${seller?.email}`}
                  className="break-all"
                >
                  {seller?.email}
                </CustomLink>
              </div>
            )}

            {seller?.mobile && (
              <div className="flex items-center gap-2">
                <div className="p-3 bg-muted rounded-md border">
                  <FiPhoneCall className="size-4" />
                </div>

                <Link
                  href={`tel:${seller?.mobile}`}
                  className="break-all"
                >
                  {seller?.mobile}
                </Link>
              </div>
            )}
          </div>
        )}
    </div>
  );
};

export default SellerDetailCard;
