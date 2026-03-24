"use client";
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { t } from "@/utils";
import { Button } from "@/components/ui/button";
import { useEffect, useState } from "react";
import { getFollowersApi, getFollowingApi, unfollowUserApi } from "@/utils/api";
import { useInView } from "react-intersection-observer";
import { Loader2 } from "lucide-react";
import { Skeleton } from "../ui/skeleton";
import EmptyMessage from "../EmptyStates/EmptyMessage";
import CustomImage from "../Common/CustomImage";
import CustomLink from "../Common/CustomLink";
import { toast } from "sonner";
import { useSelector } from "react-redux";
import { getIsRtl } from "@/redux/reducer/languageSlice";

const FollowersFollowingModal = ({
    isOpen,
    onClose,
    initialTab,
    followersCount,
    followingCount,
    userId,
    updateFollowingCount,
    isSellerPage
}) => {

    const isRTL = useSelector(getIsRtl);
    const [activeTab, setActiveTab] = useState(initialTab);

    // Followers State
    const [followers, setFollowers] = useState([]);
    const [followersPage, setFollowersPage] = useState(1);
    const [followersLastPage, setFollowersLastPage] = useState(1);
    const [followersLoading, setFollowersLoading] = useState(false);

    // Following State
    const [following, setFollowing] = useState([]);
    const [followingPage, setFollowingPage] = useState(1);
    const [followingLastPage, setFollowingLastPage] = useState(1);
    const [followingLoading, setFollowingLoading] = useState(false);

    const { ref: followersRef, inView: followersInView } = useInView();
    const { ref: followingRef, inView: followingInView } = useInView();

    const [isUnFollowingUserId, setIsUnFollowingUserId] = useState(null)


    // Fetch Followers
    const fetchFollowers = async (page = 1) => {
        if (page === 1) setFollowersLoading(true);
        try {
            const res = await getFollowersApi.getFollowers({
                user_id: userId,
                page,
            });
            if (res?.data?.error === false) {
                const data = res.data.data;
                setFollowers((prev) =>
                    page === 1 ? data.data : [...prev, ...data.data]
                );
                setFollowersPage(data.current_page);
                setFollowersLastPage(data.last_page);
            }
        } catch (error) {
            console.error("Followers error:", error);
        } finally {
            setFollowersLoading(false);
        }
    };

    // Fetch Following
    const fetchFollowing = async (page = 1) => {
        if (page === 1) setFollowingLoading(true);
        try {
            const res = await getFollowingApi.getFollowing({
                user_id: userId,
                page,
            });

            if (res?.data?.error === false) {
                const data = res.data.data;

                setFollowing((prev) =>
                    page === 1 ? data.data : [...prev, ...data.data]
                );
                setFollowingPage(data.current_page);
                setFollowingLastPage(data.last_page);
            }
        } catch (error) {
            console.error("Following error:", error);
        } finally {
            setFollowingLoading(false);
        }
    };

    // Initial Load
    useEffect(() => {
        if (isOpen && userId) {
            fetchFollowers(1);
            fetchFollowing(1);
        }
    }, [isOpen, userId]);

    // Infinite Scroll - Followers
    useEffect(() => {
        if (
            followersInView &&
            followersPage < followersLastPage &&
            !followersLoading
        ) {
            fetchFollowers(followersPage + 1);
        }
    }, [followersInView]);

    // Infinite Scroll - Following
    useEffect(() => {
        if (
            followingInView &&
            followingPage < followingLastPage &&
            !followingLoading
        ) {
            fetchFollowing(followingPage + 1);
        }
    }, [followingInView]);

    const handleUnfollow = async (userIdToUnfollow) => {
        try {
            setIsUnFollowingUserId(userIdToUnfollow)
            const res = await unfollowUserApi.unfollowUser({ user_id: userIdToUnfollow })
            if (res?.data?.error === false) {
                toast.success(res?.data?.message)
                setFollowing((prev) => prev.filter((user) => user.id !== userIdToUnfollow));
                updateFollowingCount()
            } else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.log(error)
        } finally {
            setIsUnFollowingUserId(null)
        }
    }

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent className="p-0 [&>button]:hidden">
                <DialogHeader className="sr-only">
                    <DialogTitle>{t(activeTab)}</DialogTitle>
                </DialogHeader>

                <Tabs
                    defaultValue={initialTab}
                    onValueChange={setActiveTab}
                    className="w-full"
                    dir={isRTL ? "rtl" : "ltr"}
                >
                    <TabsList className="w-full bg-white p-0 border-b">
                        <TabsTrigger value="followers" className="flex-1 py-3 rounded-none border-b-2 border-transparent text-muted-foreground data-[state=active]:border-primary data-[state=active]:text-primary data-[state=active]:bg-transparent">
                            {t("followers")} ({followersCount})
                        </TabsTrigger>
                        <TabsTrigger value="following" className="flex-1 py-3 rounded-none border-b-2 border-transparent text-muted-foreground data-[state=active]:border-primary data-[state=active]:text-primary data-[state=active]:bg-transparent">
                            {t("following")} ({followingCount})
                        </TabsTrigger>
                    </TabsList>

                    {/* Followers Tab */}
                    <TabsContent
                        value="followers"
                        className="max-h-[450px] overflow-y-auto px-4 py-2"
                    >
                        {followersLoading ? (
                            <UserListSkeleton />
                        ) : followers.length === 0 ? (
                            <EmptyMessage message={t("noFollowersFound")} />
                        ) : (
                            <>
                                {followers.map((user) => (
                                    <div key={user.id} className="flex items-center justify-between py-4">
                                        <div className="flex items-center gap-3">
                                            <CustomLink href={`/seller/${user?.id}`}>
                                                <CustomImage
                                                    src={user?.profile}
                                                    alt={user?.name}
                                                    width={48}
                                                    height={48}
                                                    className="rounded-full object-cover aspect-square"
                                                />
                                            </CustomLink>
                                            <CustomLink href={`/seller/${user?.id}`} className="font-medium">{user?.name}</CustomLink>
                                        </div>
                                    </div>
                                ))}

                                {followersPage < followersLastPage && (
                                    <div
                                        ref={followersRef}
                                        className="flex justify-center py-3"
                                    >
                                        <Loader2 className="animate-spin" />
                                    </div>
                                )}
                            </>
                        )}
                    </TabsContent>

                    {/* Following Tab */}
                    <TabsContent
                        value="following"
                        className="max-h-[450px] overflow-y-auto py-2"
                    >
                        {followingLoading && following.length === 0 ? (
                            <UserListSkeleton />
                        ) : following.length === 0 ? (
                            <EmptyMessage message={t("notFollowingAnyoneYet")} />
                        ) : (
                            <>
                                {following.map((user) => (
                                    <div key={user.id} className="flex items-center justify-between py-4">
                                        <div className="flex items-center gap-3">
                                            <CustomLink href={`/seller/${user?.id}`}>
                                                <CustomImage
                                                    src={user?.profile}
                                                    alt={user?.name}
                                                    width={48}
                                                    height={48}
                                                    className="rounded-full object-cover aspect-square"
                                                />
                                            </CustomLink>
                                            <CustomLink href={`/seller/${user?.id}`} className="font-medium">{user?.name}</CustomLink>
                                        </div>
                                        {!isSellerPage && <Button className='text-destructive bg-[#fff6f6]' disabled={isUnFollowingUserId === user?.id} onClick={() => handleUnfollow(user?.id)} >
                                            {isUnFollowingUserId === user?.id ? t('loading') : t("unfollow")}
                                        </Button>}
                                    </div>
                                ))}

                                {followingPage < followingLastPage && (
                                    <div
                                        ref={followingRef}
                                        className="flex justify-center py-3"
                                    >
                                        <Loader2 className="animate-spin" />
                                    </div>
                                )}
                            </>
                        )}
                    </TabsContent>
                </Tabs>
            </DialogContent>
        </Dialog>
    );
};

export default FollowersFollowingModal;

const UserListSkeleton = () => {
    return (
        <div className="flex flex-col">
            {Array.from({ length: 5 }).map((_, index) => (
                <div key={index} className="flex items-center gap-3 py-4">
                    <Skeleton className="h-12 w-12 rounded-full" />
                    <div className="flex flex-col gap-2 flex-1">
                        <Skeleton className="h-4 w-32 rounded-md" />
                        <Skeleton className="h-3 w-20 rounded-md" />
                    </div>
                </div>
            ))}
        </div>
    );
};
