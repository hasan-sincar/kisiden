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
import { Button } from "@/components/ui/button";
import { followUserApi, unfollowUserApi } from "@/utils/api";
import { useState } from "react";
import { toast } from "sonner";
import FollowersFollowingModal from "@/components/Profile/FollowersFollowingModal";

const SellerDetailCard = ({ seller, ratingCount, setSeller }) => {
  const pathname = usePathname();
  const memberSinceYear = seller?.created_at
    ? extractYear(seller.created_at)
    : "";
  const currentUrl = `${process.env.NEXT_PUBLIC_WEB_URL}${pathname}`;
  const CompanyName = useSelector(getCompanyName);
  const FbTitle = seller?.name + " | " + CompanyName;
  const [showFollowersModal, setShowFollowersModal] = useState(false);
  const [modalInitialTab, setModalInitialTab] = useState("followers");

  const [isFollowing, setIsFollowing] = useState(false)
  const [isUnFollowing, setIsUnFollowing] = useState(false)

  const handleFollow = async () => {
    try {
      setIsFollowing(true)
      const res = await followUserApi.followUser({ user_id: seller?.id })
      if (res?.data?.error === false) {
        toast.success(res?.data?.message)
        // Update the seller state to reflect follow
        setSeller(prev => ({
          ...prev,
          is_following: 1,
          followers_count: (Number(prev?.followers_count) || 0) + 1
        }))
      } else {
        toast.error(res?.data?.message)
      }
    } catch (error) {
      console.log(error)
    } finally {
      setIsFollowing(false)
    }
  }

  const handleUnfollow = async () => {
    try {
      setIsUnFollowing(true)
      const res = await unfollowUserApi.unfollowUser({ user_id: seller?.id })
      if (res?.data?.error === false) {
        toast.success(res?.data?.message)
        // Update the seller state to reflect unfollow
        setSeller(prev => ({
          ...prev,
          is_following: 0,
          followers_count: Math.max(0, (Number(prev?.followers_count) || 0) - 1)
        }))
      } else {
        toast.error(res?.data?.message)
      }
    } catch (error) {
      console.log(error)
    } finally {
      setIsUnFollowing(false)
    }
  }

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

        <div className="flex flex-col gap-3 text-center w-full">
          <h3 className="text-xl font-bold">{seller?.name}</h3>
          <div className="flex items-center gap-3 justify-center">
            <button
              type="button"
              className="hover:underline"
              onClick={() => {
                setModalInitialTab("followers");
                setShowFollowersModal(true);
              }}
            >
              {seller?.followers_count} {t("followers")}
            </button>
            <div className="w-0.5 h-4 bg-border" />
            <button
              type="button"
              className="hover:underline"
              onClick={() => {
                setModalInitialTab("following");
                setShowFollowersModal(true);
              }}
            >
              {seller?.following_count} {t("following")}
            </button>
          </div>
          <div className="flex items-center justify-center gap-1 text-sm">
            <IoMdStar />
            <span>
              {Number(seller?.average_rating).toFixed(2)} |{" "}
              {ratingCount} {t("ratings")}
            </span>
          </div>
        </div>
      </div>
      <FollowersFollowingModal
        isOpen={showFollowersModal}
        onClose={() => setShowFollowersModal(false)}
        initialTab={modalInitialTab}
        followersCount={seller?.followers_count}
        followingCount={seller?.following_count}
        userId={seller?.id}
        isSellerPage={true}
      />

      {seller?.show_personal_details == 1 &&
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

      <div className="border-t p-4 flex items-center gap-4">
        <Button disabled={isUnFollowing || isFollowing} variant="outline" className='p-4 flex-1 border-primary text-primary hover:text-primary' onClick={seller?.is_following == 1 ? handleUnfollow : handleFollow} >
          {
            isUnFollowing || isFollowing ?
              t("loading")
              :
              seller?.is_following == 1 ?
                t('unfollow')
                :
                t('follow')
          }
        </Button>
      </div>
    </div>
  );
};

export default SellerDetailCard;
