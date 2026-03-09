import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table";

const NotificationSkeleton = () => {
    return (
        <div className="overflow-hidden border rounded-md">
            <Table>
                <TableHeader className='bg-muted'>
                    <TableRow className='text-xs sm:text-sm'>
                        <TableHead>
                            <div className="h-5 w-2/4 bg-gray-200 rounded animate-pulse"></div>
                        </TableHead>
                        <TableHead className="text-center">
                            <div className="h-5 w-2/4 bg-gray-200 rounded animate-pulse mx-auto"></div>
                        </TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody className='text-xs sm:text-sm'>
                    {Array.from({ length: 15 }).map((_, index) => (
                        <TableRow key={index} className="hover:bg-muted">
                            <TableCell>
                                <div className="flex items-center gap-3">
                                    <div className="w-[48px] h-[48px] rounded bg-gray-200 animate-pulse"></div>
                                    <div className="flex flex-col gap-2 flex-1">
                                        <div className="h-4 bg-gray-200 rounded animate-pulse w-2/4"></div>
                                        <div className="h-3 bg-gray-200 rounded animate-pulse w-3/4"></div>
                                    </div>
                                </div>
                            </TableCell>
                            <TableCell className="text-center">
                                <div className="h-4 bg-gray-200 rounded animate-pulse w-full mx-auto"></div>
                            </TableCell>
                        </TableRow>
                    ))}
                </TableBody>
            </Table>
        </div>
    );
};

export default NotificationSkeleton; 