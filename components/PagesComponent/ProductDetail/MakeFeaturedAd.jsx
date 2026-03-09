import {  t } from "@/utils";
import adIcon from "@/public/assets/ad_icon.svg";
import { Button } from "@/components/ui/button";
import ReusableAlertDialog from "@/components/Common/ReusableAlertDialog";
import { createFeaturedItemApi, getLimitsApi } from "@/utils/api";
import { useState } from "react";
import { toast } from "sonner";
import CustomImage from "@/components/Common/CustomImage";
import { useNavigate } from "@/components/Common/useNavigate";

const MakeFeaturedAd = ({ item_id, setProductDetails }) => {
  const [isGettingLimits, setIsGettingLimits] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalConfig, setModalConfig] = useState({});
  const [isConfirmLoading, setIsConfirmLoading] = useState(false);
  const { navigate } = useNavigate();

  const handleCreateFeaturedAd = async () => {
    try {
      setIsGettingLimits(true);
      const res = await getLimitsApi.getLimits({
        package_type: "advertisement",
      });

      if (res?.data?.error === false) {
        // ✅ Limit granted → show confirmation modal
        setModalConfig({
          title: t("createFeaturedAd"),
          description: t("youWantToCreateFeaturedAd"),
          cancelText: t("cancel"),
          confirmText: t("yes"),
          onConfirm: createFeaturedAd,
        });
      } else {
        // ❌ No package → show subscribe modal
        setModalConfig({
          title: t("noPackage"),
          description: t("pleaseSubscribes"),
          cancelText: t("cancel"),
          confirmText: t("subscribe"),
          onConfirm: () => navigate("/user-subscription"),
        });
      }
      setIsModalOpen(true);
    } catch (error) {
      console.error(error);
    } finally {
      setIsGettingLimits(false);
    }
  };

  const createFeaturedAd = async () => {
    try {
      setIsConfirmLoading(true);
      const res = await createFeaturedItemApi.createFeaturedItem({
        item_id,
        positions: "home_screen",
      });
      if (res?.data?.error === false) {
        toast.success(t("featuredAdCreated"));
        setProductDetails((prev) => ({
          ...prev,
          is_feature: true,
        }));
        setIsModalOpen(false);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsConfirmLoading(false);
    }
  };

  return (
    <>
      <div className="border rounded-md p-4 flex flex-col md:flex-row items-center gap-3 justify-between">
        <div className="flex flex-col md:flex-row items-center gap-4">
          <div className="bg-muted py-4 px-5 rounded-md">
            <div className="w-[62px] h-[75px] relative">
              <CustomImage
                src={adIcon}
                alt="featured-ad"
                fill
              />
            </div>
          </div>
          <p className="text-xl font-medium text-center ltr:md:text-left rtl:md:text-right">
            {t("featureAdPrompt")}
          </p>
        </div>

        <Button onClick={handleCreateFeaturedAd} disabled={isGettingLimits}>
          {t("createFeaturedAd")}
        </Button>
      </div>
      <ReusableAlertDialog
        open={isModalOpen}
        onCancel={() => setIsModalOpen(false)}
        onConfirm={modalConfig.onConfirm}
        title={modalConfig.title}
        description={modalConfig.description}
        cancelText={modalConfig.cancelText}
        confirmText={modalConfig.confirmText}
        confirmDisabled={isConfirmLoading}
      />
    </>
  );
};

export default MakeFeaturedAd;
