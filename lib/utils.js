import { clsx } from "clsx";
import { twMerge } from "tailwind-merge"

export function cn(...inputs) {
  return twMerge(clsx(inputs));
}

export const createQueryString = (searchParams, paramsToUpdate) => {
  const params = new URLSearchParams(searchParams.toString());
  Object.entries(paramsToUpdate).forEach(([key, value]) => {
    if (value === null || value === undefined) {
      params.delete(key);
    } else {
      params.set(key, value);
    }
  });
  return params.toString();
};


