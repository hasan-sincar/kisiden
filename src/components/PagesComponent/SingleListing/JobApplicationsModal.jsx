import { getAdJobApplicationsApi } from "@/utils/api";
import { Modal } from "antd";
import { useEffect, useState } from "react";
import { MdClose } from "react-icons/md";
import JobApplicationCard from "./JobApplicationCard";

const JobApplicationsModal = ({ isOpen, onClose, listingId, t }) => {
    const [applications, setApplications] = useState([]);
    const [isLoading, setIsLoading] = useState(false);
    const [isLoadingMore, setIsLoadingMore] = useState(false);
    const [currentPage, setCurrentPage] = useState(1);
    const [hasMore, setHasMore] = useState(false);

    // Modal close icon
    const CloseIcon = (
        <div className="close_icon_cont">
            <MdClose size={24} color="black" />
        </div>
    );


    useEffect(() => {
        if (isOpen) {
            fetchApplications(currentPage);
        }
    }, [isOpen]);

    // Fetch job applications
    const fetchApplications = async (page) => {
        try {
            if (page === 1) {
                setIsLoading(true);
            } else {
                setIsLoadingMore(true);
            }
            const res = await getAdJobApplicationsApi.getAdJobApplications({
                page,
                item_id: listingId,
            });
            if (res?.data?.error === false) {
                if (page === 1) {
                    setApplications(res?.data?.data?.data || []);
                } else {
                    setApplications(prev => [...prev, ...(res?.data?.data?.data || [])]);
                }
                setCurrentPage(res?.data?.data?.current_page);
                setHasMore(res?.data?.data?.last_page > res?.data?.data?.current_page);
            }
        } catch (error) {
            console.log(error);
        } finally {
            setIsLoading(false);
            setIsLoadingMore(false);
        }
    };

    const loadMore = () => {
        fetchApplications(currentPage + 1);
    };


    return (
        <Modal
            centered
            open={isOpen}
            closeIcon={CloseIcon}
            colorIconHover="transparent"
            onCancel={onClose}
            footer={null}
            className="ant_register_modal"
            maskClosable={false}
        >
            <div className="location_modal">
                <h5 className="head_loc">{t("jobApplications")}</h5>
                {isLoading ? (
                    <div className="applications-loading">
                        <div className="skeleton-loader"></div>
                        <div className="skeleton-loader"></div>
                    </div>
                ) : applications.length > 0 ? (
                    <div className="applications-list">
                        {applications.map((application) => (
                            <JobApplicationCard
                                key={application.id}
                                application={application}
                                setApplications={setApplications}
                                t={t}
                            />
                        ))}

                        {hasMore === true && (
                            <div className="loadMore">
                                <button
                                    className="loadMoreBtn"
                                    onClick={loadMore}
                                    disabled={isLoadingMore}
                                >
                                    {isLoadingMore ? t("loading") : t("loadMore")}
                                </button>
                            </div>
                        )}
                    </div>
                ) : (
                    <div className="no-applications">
                        <p>{t("noApplicationsYet")}</p>
                    </div>
                )}
            </div>
        </Modal>
    )
}

export default JobApplicationsModal