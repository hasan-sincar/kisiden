import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table";

const TransactionSkeleton = ({ count = 5 }) => {
    return (
        <div className="overflow-x-auto">
            <div className="min-w-full overflow-hidden border rounded-md">
                <Table>
                    <TableHeader className='bg-muted'>
                        <TableRow className='text-xs sm:text-sm'>
                            <TableHead>
                                <div className="h-5 w-[50%] bg-gray-200 rounded animate-pulse"></div>
                            </TableHead>
                            <TableHead>
                                <div className="h-5 w-[70%] bg-gray-200 rounded animate-pulse"></div>
                            </TableHead>
                            <TableHead>
                                <div className="h-5 w-[60%] bg-gray-200 rounded animate-pulse"></div>
                            </TableHead>
                            <TableHead>
                                <div className="h-5 w-[70%] bg-gray-200 rounded animate-pulse"></div>
                            </TableHead>
                            <TableHead>
                                <div className="h-5 w-[60%] bg-gray-200 rounded animate-pulse"></div>
                            </TableHead>
                            <TableHead>
                                <div className="h-5 w-[70%] bg-gray-200 rounded animate-pulse"></div>
                            </TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody className='text-xs sm:text-sm'>
                        {Array(count).fill(0).map((_, index) => (
                            <TableRow key={index} className="hover:bg-muted">
                                <TableCell>
                                    <div className="h-4 w-[80%] bg-gray-200 rounded animate-pulse"></div>
                                </TableCell>
                                <TableCell>
                                    <div className="h-4 w-[85%] bg-gray-200 rounded animate-pulse"></div>
                                </TableCell>
                                <TableCell>
                                    <div className="h-4 w-[90%] bg-gray-200 rounded animate-pulse"></div>
                                </TableCell>
                                <TableCell>
                                    <div className="h-4 w-[80%] bg-gray-200 rounded animate-pulse"></div>
                                </TableCell>
                                <TableCell>
                                    <div className="h-4 w-[70%] bg-gray-200 rounded animate-pulse"></div>
                                </TableCell>
                                <TableCell>
                                    <div className="h-6 w-[75%] bg-gray-200 rounded animate-pulse"></div>
                                </TableCell>
                            </TableRow>
                        ))}
                    </TableBody>
                </Table>
            </div>
        </div>
    );
};

export default TransactionSkeleton; 