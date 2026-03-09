import { useRef, useEffect } from "react";

const useAutoFocus = () => {
  const inputRef = useRef(null);

  useEffect(() => {
    setTimeout(() => {
      if (inputRef.current) {
        inputRef.current.focus();
      }
    }, 500);
  }, []);

  return inputRef;
};

export default useAutoFocus;
