import { updateJobStatusApi } from "@/utils/api";
import Link from "next/link";
import { useState } from "react";
import toast from "react-hot-toast";
import { FaTimes } from "react-icons/fa";
import { FaCheck, FaDownload } from "react-icons/fa6";


const JobApplicationCard = ({ application, t, setApplications }) => {

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
                setApplications((prev) =>
                    prev.map((app) =>
                        app.id === application.id ? { ...app, status: newStatus } : app
                    )
                );
            } else {
                toast.error(res?.data?.message);
            }
        } catch (error) {
        } finally {
            setProcessing(false);
        }
    };

    return (
        <div className="application-card">
            <div className="application-header">
                <h3 className="applicant-name">{application.full_name}</h3>
                <span
                    className={`status-badge status-${application.status.toLowerCase()}`}
                >
                    {application.status}
                </span>
            </div>

            <div className="application-details">
                <div className="detail-row">
                    <label>{t("email")}:</label>
                    <span>{application.email}</span>
                </div>
                <div className="detail-row">
                    <label>{t("phone")}:</label>
                    <span>{application.mobile}</span>
                </div>
                <div className="detail-row">
                    <label>{t("appliedDate")}:</label>
                    <span>{new Date(application.created_at).toLocaleDateString()}</span>
                </div>
            </div>

            <div className="application-actions">
                {application.status === "pending" ? (
                    <>
                        <button
                            className="action-btn accept-btn"
                            onClick={() => handleStatusChange("accepted")}
                            disabled={processing}
                        >
                            <FaCheck />
                            <span>{t("accept")}</span>
                        </button>

                        <button
                            className="action-btn reject-btn"
                            onClick={() => handleStatusChange("rejected")}
                            disabled={processing}
                        >
                            <FaTimes />
                            <span>{t("reject")}</span>
                        </button>
                    </>
                ) : null}

                {application.resume && (
                    <Link
                        href={application.resume}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="resume-link"
                    >
                        <FaDownload /> <span>{t("viewResume")}</span>
                    </Link>
                )}
            </div>
        </div>
    )
}

export default JobApplicationCard