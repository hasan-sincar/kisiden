'use client'
import BreadcrumbComponent from '@/components/Breadcrumb/BreadcrumbComponent'
import ProfileSidebar from '@/components/Profile/ProfileSidebar'
import { getIsLoggedIn } from '@/redux/reuducer/authSlice'
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice'
import { t } from '@/utils'
import { getMyJobApplicationsList } from '@/utils/api'
import { useEffect, useState } from 'react'
import { useSelector } from 'react-redux'
import JobApplicationsTable from './JobApplicationsTable'


const JobApplications = () => {

    const CurrentLanguage = useSelector(CurrentLanguageData);
    const [jobApplications, setJobApplications] = useState([]);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalItems, setTotalItems] = useState(0);
    const [perPage, setPerPage] = useState(15);
    const [isLoading, setIsLoading] = useState(false);
    const isLoggedIn = useSelector(getIsLoggedIn);

    useEffect(() => {
        if (isLoggedIn) {
            fetchJobApplicationsData(currentPage);
        }
    }, [currentPage, isLoggedIn]);

    const fetchJobApplicationsData = async (page) => {
        try {
            setIsLoading(true);
            const response = await getMyJobApplicationsList.getMyJobApplications({
                page,
            });
            if (response.data.error === false) {
                setJobApplications(response?.data?.data?.data);
                setTotalItems(response?.data?.data?.total);
                setPerPage(response?.data?.data?.per_page);
            } else {
                toast.error(response.data.message);
            }
        } catch (error) {
            console.error("Error:", error);
        } finally {
            setIsLoading(false);
        }
    };

    const handleTableChange = (pagination) => {
        setCurrentPage(pagination.current);
    };

    return (
        <>
            <BreadcrumbComponent title2={t('jobApplications')} />
            <div className="container">
                <div className="row my_prop_title_spacing">
                    <h4 className="pop_cat_head">{t("myJobApplications")}</h4>
                </div>
                <div className="row profile_sidebar">
                    <ProfileSidebar />
                    <div className="col-lg-9 p-0">
                        <div className="notif_cont">
                            <JobApplicationsTable
                                jobApplications={jobApplications}
                                isLoading={isLoading}
                                currentPage={currentPage}
                                totalItems={totalItems}
                                perPage={perPage}
                                onTableChange={handleTableChange}
                            />
                        </div>
                    </div>
                </div>
            </div>
        </>
    )
}

export default JobApplications