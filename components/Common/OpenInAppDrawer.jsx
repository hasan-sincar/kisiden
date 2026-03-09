import { Button } from "@/components/ui/button"
import {
    Drawer,
    DrawerContent,
    DrawerDescription,
    DrawerFooter,
    DrawerHeader,
    DrawerTitle,
} from "@/components/ui/drawer"
import { settingsData } from "@/redux/reducer/settingSlice";
import { t } from "@/utils"
import { usePathname } from "next/navigation";
import { useSelector } from "react-redux";
import { toast } from "sonner";

const OpenInAppDrawer = ({ isOpenInApp, setIsOpenInApp }) => {

    const path = usePathname()
    const settings = useSelector(settingsData);
    const companyName = settings?.company_name;
    const scheme = settings?.deep_link_scheme;
    const playStoreLink = settings?.play_store_link;
    const appStoreLink = settings?.app_store_link;


    function handleOpenInApp() {

        var appScheme = `${scheme}://${window.location.hostname}${path}`;
        var userAgent = navigator.userAgent || navigator.vendor || window.opera;
        var isAndroid = /android/i.test(userAgent);
        var isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;

        let applicationLink;
        if (isAndroid) {
            applicationLink = playStoreLink;
        } else if (isIOS) {
            applicationLink = appStoreLink;
        } else {
            // Fallback for desktop or other platforms
            applicationLink = playStoreLink || appStoreLink;
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

                    if (!applicationLink) {
                        toast.error(`${companyName} ${isIOS ? t('appStore') : t('playStore')} ${t('linkNotAvailable')}`);
                        return;
                    }

                    window.location.href = applicationLink;
                }
            }
        }, 1000);
    }

    return (
        <Drawer open={isOpenInApp} onOpenChange={setIsOpenInApp}>
            <DrawerContent>
                <DrawerHeader>
                    <DrawerTitle>{`${t('viewIn')} ${companyName} ${t('app')}`}</DrawerTitle>
                    <DrawerDescription>
                        {t('getTheBestExperienceByOpeningThisInOurMobileApp')}
                    </DrawerDescription>
                </DrawerHeader>
                <DrawerFooter>
                    <Button onClick={handleOpenInApp}>
                        {t('openInApp')}
                    </Button>
                </DrawerFooter>
            </DrawerContent>
        </Drawer>
    )
}

export default OpenInAppDrawer 