"use client";

import { useSearchParams } from "next/navigation";

export const useLangFromSearchParams = () => {
    const searchParams = useSearchParams();
    return searchParams.get("lang")
};
