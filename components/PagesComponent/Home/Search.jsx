"use client";
import { Check, ChevronsUpDown, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { useEffect, useState } from "react";
import { useInView } from "react-intersection-observer";
import { t } from "@/utils";
import { BiPlanet } from "react-icons/bi";
import { FaSearch } from "react-icons/fa";
import { usePathname } from "next/navigation";
import { useNavigate } from "@/components/Common/useNavigate";
import useGetCategories from "@/components/Layout/useGetCategories";

const Search = () => {
  const {
    cateData,
    getCategories,
    isCatLoadMore,
    catLastPage,
    catCurrentPage,
  } = useGetCategories();

  const pathname = usePathname();
  const { navigate } = useNavigate();
  const categoryList = [
    { slug: "all-categories", translated_name: t("allCategories") },
    ...cateData,
  ];
  const [open, setOpen] = useState(false);
  const [value, setValue] = useState("all-categories");
  const selectedItem = categoryList.find((item) => item.slug === value);
  const hasMore = catCurrentPage < catLastPage;
  const { ref, inView } = useInView();
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    if (open && inView && hasMore && !isCatLoadMore) {
      getCategories(catCurrentPage + 1);
    }
  }, [hasMore, inView, isCatLoadMore, open]);

  const handleSearchNav = (e) => {
    e.preventDefault();

    const query = encodeURIComponent(searchQuery);

    // Build the base URL with query and language
    const baseUrl = `/ads?query=${query}`;

    // Add category parameter if not "all-categories"
    const url =
      selectedItem?.slug === "all-categories"
        ? baseUrl
        : `/ads?category=${selectedItem?.slug}&query=${query}`;

    // Use consistent navigation method
    if (pathname === "/ads") {
      // If already on ads page, use history API to avoid full page reload
      window.history.pushState(null, "", url);
    } else {
      // If on different page, use router for navigation
      navigate(url);
    }
  };

  return (
    <>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            role="combobox"
            aria-expanded={open}
            className="min-w-[125px] max-w-[125px] sm:min-w-[156px] sm:max-w-[156px] py-1 px-1.5 sm:py-2 sm:px-3 justify-between border-none hover:bg-transparent font-normal"
          >
            <span className="truncate">
              {selectedItem?.translated_name || t("selectCat")}
            </span>
            <ChevronsUpDown className="opacity-50" />
          </Button>
        </PopoverTrigger>
        <PopoverContent align="start" className="w-[200px] p-0">
          <Command>
            <CommandInput placeholder={t("searchACategory")} />
            <CommandList>
              <CommandEmpty>{t("noCategoryFound")}</CommandEmpty>
              <CommandGroup>
                {categoryList.map((category, index) => {
                  const isLast = open && index === categoryList.length - 1;
                  return (
                    <CommandItem
                      key={category?.slug}
                      value={category?.slug}
                      onSelect={(currentValue) => {
                        setValue(currentValue);
                        setOpen(false);
                      }}
                      ref={isLast ? ref : null}
                    >
                      {category.translated_name || category?.name}
                      <Check
                        className={cn(
                          "ml-auto",
                          value === category.slug ? "opacity-100" : "opacity-0"
                        )}
                      />
                    </CommandItem>
                  );
                })}
              </CommandGroup>
              {isCatLoadMore && (
                <div className="flex justify-center items-center pb-2 text-muted-foreground">
                  <Loader2 className="animate-spin" />
                </div>
              )}
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>
      <form
        onSubmit={handleSearchNav}
        className="w-full flex items-center gap-2 ltr:border-l rtl:border-r py-1 px-1.5 sm:py-2 sm:px-3"
      >
        <BiPlanet color="#595B6C" className="min-w-4 min-h-4" />
        <input
          type="text"
          placeholder={t("searchAd")}
          className="text-sm outline-none w-full"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
        <button
          className="flex items-center gap-2 bg-primary text-white p-2 rounded"
          type="submit"
        >
          <FaSearch size={14} />
        </button>
      </form>
    </>
  );
};

export default Search;
