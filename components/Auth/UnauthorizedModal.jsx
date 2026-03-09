import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { getIsUnauthorized, setIsUnauthorized } from "@/redux/reducer/globalStateSlice";
import { useDispatch, useSelector } from "react-redux";

const UnauthorizedModal = () => {
  const dispatch = useDispatch();
  const open = useSelector(getIsUnauthorized);

  const handleOk = () => {
    dispatch(setIsUnauthorized(false));
  };

  return (
    <AlertDialog open={open}>
      <AlertDialogContent onInteractOutside={(e) => e.preventDefault()}>
        <AlertDialogHeader>
          <AlertDialogTitle>Unauthorized</AlertDialogTitle>
          <AlertDialogDescription>
            You do not have permission to access this resource. Please log in or
            contact the administrator.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogAction onClick={handleOk}>OK</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
};

export default UnauthorizedModal;
