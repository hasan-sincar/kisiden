'use client'
import { t } from '@/utils';
import { Button, Drawer, Space } from 'antd'
import { usePathname } from 'next/navigation';
import { useEffect } from 'react';


const OpenInAppDrawer = ({ IsOpenInApp, OnHide, systemSettingsData }) => {

    const path = usePathname()

    const companyName = systemSettingsData?.data?.data?.company_name

    const scheme = systemSettingsData?.data?.data?.deep_link_scheme

    const primaryColor = getComputedStyle(document.documentElement).getPropertyValue('--primary-color');

    useEffect(() => {
        // Prevent body scrolling when drawer is open
        if (IsOpenInApp) {
            document.body.style.overflow = 'hidden';
            document.body.style.position = 'fixed';
            document.body.style.width = '100%';
        } else {
            document.body.style.overflow = 'auto';
            document.body.style.position = 'static';
            document.body.style.width = 'auto';
        }

        // Cleanup function
        return () => {
            document.body.style.overflow = 'auto';
            document.body.style.position = 'static';
            document.body.style.width = 'auto';
        };
    }, [IsOpenInApp]);


    function openInApp() {

        var appScheme = `${scheme}://${window.location.hostname}${path}`;
        var userAgent = navigator.userAgent || navigator.vendor || window.opera;
        var isAndroid = /android/i.test(userAgent);
        var isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;

        let applicationLink;
        if (isAndroid) {
            applicationLink = systemSettingsData?.data?.data?.play_store_link;
        } else if (isIOS) {
            applicationLink = systemSettingsData?.data?.data?.app_store_link;
        } else {
            // Fallback for desktop or other platforms
            applicationLink = systemSettingsData?.data?.data?.play_store_link ||
                systemSettingsData?.data?.data?.app_store_link;
        }

        if (!applicationLink) {
            toast.error(`${companyName} ${t('appStoreLinkNotAvailable')}`);
            return;
        }

        // Attempt to open the app
        window.location.href = appScheme;
        // Set a timeout to check if app opened
        setTimeout(function () {
            if (document.hidden || document.webkitHidden) {
                // App opened successfully
            } else {
                // App is not installed, ask user if they want to go to app store
                if (confirm(`${companyName} ${t('appIsNotInstalled')} ${isIOS ? t('appStore') : t('playStore')}?`)) {
                    window.location.href = applicationLink;
                }
            }
        }, 1000);
    }


    return (

        <Drawer
            title={`${t('viewIn')} ${companyName} ${t('app')}`}
            placement='bottom'
            width={500}
            onClose={OnHide}
            open={IsOpenInApp}
            styles={{
                body: { display: 'none' },
                wrapper: { height: 'auto', borderRadius: '150px' },
                content: { borderTopLeftRadius: '15px', borderTopRightRadius: '15px' }
            }}
            maskClosable={false}
            extra={
                <Space>
                    <Button style={{ backgroundColor: primaryColor, color: 'white' }} onClick={openInApp}>
                        {t('open')}
                    </Button>
                </Space>
            }
        >
        </Drawer>
    )
}

export default OpenInAppDrawer