import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useEffect, useState } from "react";
import { t } from "@/utils";
import { getAdJobApplicationsApi } from "@/utils/api";
import NoData from "@/components/EmptyStates/NoData";
import JobApplicationCard from "./JobApplicationCard";
import JobApplicationCardSkeleton from "./JobApplicationCardSkeleton";

const JobApplicationModal = ({
  IsShowJobApplications,
  setIsShowJobApplications,
  listingId,
  isJobFilled,
}) => {
  const [receivedApplications, setReceivedApplications] = useState({
    data: [],
    isLoading: true,
    isLoadingMore: false,
    currentPage: 1,
    hasMore: false,
  });

  useEffect(() => {
    if (IsShowJobApplications) {
      fetchApplications(receivedApplications?.currentPage);
    }
  }, [IsShowJobApplications]);

  const fetchApplications = async (page) => {
    try {
      if (page === 1) {
        setReceivedApplications((prev) => ({
          ...prev,
          isLoading: true,
        }));
      } else {
        setReceivedApplications((prev) => ({
          ...prev,
          isLoadingMore: true,
        }));
      }
      const res = await getAdJobApplicationsApi.getAdJobApplications({
        page,
        item_id: listingId,
      });
      if (res?.data?.error === false) {
        if (page === 1) {
          setReceivedApplications((prev) => ({
            ...prev,
            data: res?.data?.data?.data || [],
            currentPage: res?.data?.data?.current_page,
            hasMore: res?.data?.data?.last_page > res?.data?.data?.current_page,
          }));
        } else {
          setReceivedApplications((prev) => ({
            ...prev,
            data: [...prev.data, ...(res?.data?.data?.data || [])],
            currentPage: res?.data?.data?.current_page,
            hasMore: res?.data?.data?.last_page > res?.data?.data?.current_page,
          }));
        }
      }
    } catch (error) {
      console.log(error);
    } finally {
      setReceivedApplications((prev) => ({
        ...prev,
        isLoading: false,
        isLoadingMore: false,
      }));
    }
  };
  const loadMore = () => {
    fetchApplications(receivedApplications.currentPage + 1);
  };

  return (
    <Dialog
      open={IsShowJobApplications}
      onOpenChange={setIsShowJobApplications}
    >
      <DialogContent
        className="max-w-2xl max-h-[80vh]"
        onInteractOutside={(e) => e.preventDefault()}
      >
        <DialogHeader>
          <DialogTitle className="text-xl font-semibold">
            {t("jobApplications")}
          </DialogTitle>
          <DialogDescription className="!text-base">
            {t("jobApplicationsDescription")}
          </DialogDescription>
        </DialogHeader>
        <ScrollArea className="h-[60vh] pr-4">
          <div className="space-y-4">
            {receivedApplications.isLoading ? (
              // Show skeleton loading state
              Array.from({ length: 3 }).map((_, index) => (
                <JobApplicationCardSkeleton key={index} />
              ))
            ) : receivedApplications?.data?.length > 0 ? (
              receivedApplications?.data?.map((application) => (
                <JobApplicationCard
                  key={application?.id}
                  application={application}
                  setReceivedApplications={setReceivedApplications}
                  isJobFilled={isJobFilled}
                />
              ))
            ) : (
              <NoData name={t("jobApplications")} />
            )}
          </div>

          {receivedApplications.hasMore && (
            <div className="text-center my-6">
              <Button
                variant="outline"
                onClick={loadMore}
                disabled={receivedApplications.isLoadingMore}
                className="text-sm sm:text-base text-primary w-[256px]"
              >
                {receivedApplications.isLoadingMore
                  ? t("loading")
                  : t("loadMore")}
              </Button>
            </div>
          )}
        </ScrollArea>
      </DialogContent>
    </Dialog>
  );
};

export default JobApplicationModal;
