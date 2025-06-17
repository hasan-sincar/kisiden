import { formatDateMonth, t } from "@/utils";
import { Skeleton, Table } from "antd";
import Link from "next/link";


const JobApplicationsTable = ({
    jobApplications,
    isLoading,
    currentPage,
    totalItems,
    perPage,
    onTableChange
}) => {


    const columns = [
        {
            title: t("jobTitle"),
            dataIndex: "item_name",
            key: "item_name",
        },
        {
            title: t("recruiter"),
            dataIndex: "recruiter_name",
            key: "recruiter_name",
        },
        {
            title: t("status"),
            dataIndex: "status",
            key: "status",
            render: (status) => (
                <span className={`status-badge status-${status.toLowerCase()}`}>
                    {status.toUpperCase()}
                </span>
            ),
        },
        {
            title: t("appliedDate"),
            dataIndex: "applied_date",
            key: "applied_date",
        },
        {
            title: t("resume"),
            dataIndex: "resume",
            key: "resume",
            render: (resume) => {
                return resume && resume !== "" ? (
                    <Link
                        href={resume}
                        target="_blank"
                        className="resume-link"
                    >
                        {t("viewResume")}
                    </Link>
                ) : (
                    <span className="resume-placeholder">
                        {t("notAvailable")}
                    </span>
                );
            },
        },
    ];


    const skeletonColumns = [

        {
            title: t("jobTitle"),
            dataIndex: "item_name",
            key: "item_name",
            render: () => (
                <Skeleton.Input active size="small" style={{ width: 120 }} />
            ),
        },
        {
            title: t("recruiter"),
            dataIndex: "recruiter_name",
            key: "recruiter_name",
            render: () => (
                <Skeleton.Input active size="small" style={{ width: 100 }} />
            ),
        },
        {
            title: t("status"),
            dataIndex: "status",
            key: "status",
            render: () => (
                <Skeleton.Input active size="small" style={{ width: 80 }} />
            ),
        },
        {
            title: t("appliedDate"),
            dataIndex: "applied_date",
            key: "applied_date",
            render: () => (
                <Skeleton.Input active size="small" style={{ width: 80 }} />
            ),
        },
        {
            title: t("resume"),
            dataIndex: "resume",
            key: "resume",
            render: () => (
                <Skeleton.Input active size="small" style={{ width: 100 }} />
            ),
        },
    ];



    return (
        isLoading ?
            <Table
                columns={skeletonColumns}
                dataSource={Array.from({ length: 10 }, (_, index) => ({
                    key: index,
                }))}
                className="notif_table"
                pagination={false}
            />
            :
            <Table
                columns={columns}
                dataSource={jobApplications.map((application, index) => ({
                    key: index + 1,
                    item_name: application.item?.name || "-",
                    recruiter_name: application.recruiter?.name || "-",
                    status: application.status || "Pending",
                    applied_date: application.created_at
                        ? formatDateMonth(application.created_at)
                        : "-",
                    resume: application.resume || "",
                }))}
                className="notif_table"
                pagination={
                    totalItems > perPage
                        ? {
                            current: currentPage,
                            pageSize: perPage,
                            total: totalItems,
                            showTotal: (total, range) =>
                                `${t("showing")} ${range[0]}-${range[1]} ${t(
                                    "of"
                                )} ${total}`,
                            onChange: (page) => onTableChange(page),
                            showSizeChanger: false,
                            disabled: isLoading
                        }
                        : false
                }
                locale={{ emptyText: t("noJobApplications") }}
            />
    )

}

export default JobApplicationsTable