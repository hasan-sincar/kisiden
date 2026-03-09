import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import { Check, X, Download } from "lucide-react";
import CustomLink from "@/components/Common/CustomLink";
import { formatDateMonthYear, t } from "@/utils";
import { toast } from "sonner";
import { useState } from "react";
import { updateJobStatusApi } from "@/utils/api";

const JobApplicationCard = ({
  application,
  setReceivedApplications,
  isJobFilled,
}) => {
  const [processing, setProcessing] = useState(false);

  const handleStatusChange = async (newStatus) => {
    try {
      setProcessing(true);
      const res = await updateJobStatusApi.updateJobStatus({
        job_id: application.id,
        status: newStatus,
      });
      if (res?.data?.error === false) {
        toast.success(res?.data?.message);
        setReceivedApplications((prev) => ({
          ...prev,
          data: prev.data.map((app) =>
            app.id === application.id ? { ...app, status: newStatus } : app
          ),
        }));
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setProcessing(false);
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case "accepted":
        return <Badge className="bg-green-600">{t("accepted")}</Badge>;
      case "rejected":
        return <Badge className="bg-red-500">{t("rejected")}</Badge>;
      case "pending":
        return <Badge className="bg-yellow-500">{t("pending")}</Badge>;
      default:
        return <Badge className="bg-yellow-500">{t("pending")}</Badge>;
    }
  };

  return (
    <Card className="hover:shadow-md transition-shadow duration-200">
      <CardHeader>
        <div className="flex items-center justify-between ltr:flex-row rtl:flex-row-reverse">
          <h3 className="font-semibold">{application.full_name}</h3>
          {getStatusBadge(application.status)}
        </div>
      </CardHeader>

      <CardContent>
        <div className="space-y-3">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div className="flex flex-col ltr:text-left rtl:text-right">
              <span className="text-muted-foreground font-medium text-xs uppercase tracking-wide">
                {t("email")}
              </span>
              <span>{application.email}</span>
            </div>

            <div className="flex flex-col ltr:text-left rtl:text-right">
              <span className="text-muted-foreground font-medium text-xs uppercase tracking-wide">
                {t("phone")}
              </span>
              <span>{application.mobile}</span>
            </div>

            <div className="flex flex-col sm:col-span-2 ltr:text-left rtl:text-right">
              <span className="text-muted-foreground font-medium text-xs uppercase tracking-wide">
                {t("appliedDate")}
              </span>
              <span>
                {formatDateMonthYear(application.created_at)}
              </span>
            </div>
          </div>

          {(application.status === "pending" || application.resume) && (
            <>
              <Separator className="my-3" />
              <div className="flex flex-wrap gap-2 ltr:flex-row rtl:flex-row-reverse">
                {application.status === "pending" && !isJobFilled && (
                  <>
                    <Button
                      size="sm"
                      className="bg-primary text-white"
                      onClick={() => handleStatusChange("accepted")}
                      disabled={processing}
                    >
                      <Check className="size-4" />
                      {t("accept")}
                    </Button>

                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={() => handleStatusChange("rejected")}
                      disabled={processing}
                    >
                      <X className="size-4" />
                      {t("reject")}
                    </Button>
                  </>
                )}

                {application.resume && (
                  <Button size="sm" variant="outline" asChild>
                    <CustomLink
                      href={application.resume}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      <Download className="size-4" />
                      {t("viewResume")}
                    </CustomLink>
                  </Button>
                )}
              </div>
            </>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

export default JobApplicationCard;
