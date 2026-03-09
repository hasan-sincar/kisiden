"use client";
import { formatDateMonthYear, t } from "@/utils";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useSelector } from "react-redux";
import { useEffect, useState } from "react";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import NoData from "@/components/EmptyStates/NoData";
import { Badge } from "@/components/ui/badge";
import TransactionSkeleton from "@/components/Skeletons/TransactionSkeleton";
import { paymentTransactionApi } from "@/utils/api";
import { toast } from "sonner";
import Pagination from "@/components/Common/Pagination";
import UploadReceiptModal from "./UploadReceiptModal";

const Transactions = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [transactions, setTransactions] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(null);
  const [transactionId, setTransactionId] = useState("");
  const [IsUploadRecipt, setIsUploadRecipt] = useState(false);

  const handleUploadReceipt = (id) => {
    setTransactionId(id);
    setIsUploadRecipt(true);
  };

  const fetchTransactions = async () => {
    try {
      setIsLoading(true);
      const res = await paymentTransactionApi.transaction({
        page: currentPage,
      });
      setTotalPages(res.data.data.last_page);
      setCurrentPage(res.data.data.current_page);
      if (res?.data?.error === false) {
        setTransactions(res?.data?.data?.data);
      } else {
        toast.error(res?.data?.message);
      }
    } catch (error) {
      console.log(error);
    } finally {
      setIsLoading(false);
    }
  };

  const handlePageChange = (page) => {
    setCurrentPage(page);
  };

  useEffect(() => {
    fetchTransactions();
  }, [currentPage]);

  const getStatusBadge = (status) => {
    switch (status) {
      case "succeed":
        return <Badge className="bg-green-500">{t("completed")}</Badge>;
      case "pending":
        return <Badge className="bg-yellow-500">{t("pending")}</Badge>;
      case "failed":
        return <Badge className="bg-red-500">{t("failed")}</Badge>;
      case "under review":
        return <Badge className="bg-blue-500">{t("underReview")}</Badge>;
      default:
        return <Badge>{status}</Badge>;
    }
  };

  return (
    <>
      {isLoading ? (
        <TransactionSkeleton />
      ) : transactions.length > 0 ? (
        <>
          <div className="overflow-hidden border rounded-md">
            <Table>
              <TableHeader className="bg-muted">
                <TableRow className="text-xs sm:text-sm">
                  <TableHead>{t("id")}</TableHead>
                  <TableHead>{t("paymentMethod")}</TableHead>
                  <TableHead>{t("transactionId")}</TableHead>
                  <TableHead>{t("date")}</TableHead>
                  <TableHead>{t("price")}</TableHead>
                  <TableHead>{t("status")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody className="text-xs sm:text-sm">
                {transactions.map((transaction) => (
                  <TableRow
                    key={transaction?.id}
                    className="hover:bg-muted text-center"
                  >
                    <TableCell>{transaction?.id}</TableCell>
                    <TableCell>{transaction?.payment_gateway}</TableCell>
                    <TableCell>{transaction?.order_id}</TableCell>
                    <TableCell>
                      {formatDateMonthYear(transaction?.created_at)}
                    </TableCell>
                    <TableCell>{transaction?.amount}</TableCell>
                    <TableCell>
                      {transaction?.payment_status === "pending" &&
                      transaction?.payment_gateway === "BankTransfer" ? (
                        <button
                          onClick={() => handleUploadReceipt(transaction?.id)}
                          className="py-2 px-4 rounded whitespace-nowrap text-white bg-primary"
                        >
                          {t("uploadReceipt")}
                        </button>
                      ) : (
                        getStatusBadge(transaction?.payment_status)
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            <div className="flex justify-end items-center mb-2">
              <Pagination
                className="mt-7"
                currentPage={currentPage}
                totalPages={totalPages}
                onPageChange={handlePageChange}
              />
            </div>
          </div>
        </>
      ) : (
        <NoData name={t("transaction")} />
      )}
      <UploadReceiptModal
        key={IsUploadRecipt}
        IsUploadRecipt={IsUploadRecipt}
        setIsUploadRecipt={setIsUploadRecipt}
        transactionId={transactionId}
        setData={setTransactions}
      />
    </>
  );
};
export default Transactions;
