"use client";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  CurrentLanguageData,
} from "@/redux/reducer/languageSlice";
import { settingsData } from "@/redux/reducer/settingSlice";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useSelector } from "react-redux";
import CustomImage from "./CustomImage";
import { setHasFetchedCategories, setHasFetchedSystemSettings } from "@/utils/getFetcherStatus";
import { updateStickyNoteTranslations } from "@/utils";
import { getIsFetchingLanguage } from "@/redux/reducer/globalStateSlice";

const LanguageDropdown = () => {
  const router = useRouter();
  const pathname = usePathname();
  const settings = useSelector(settingsData);
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const languages = settings && settings?.languages;
  const isRTL = CurrentLanguage.rtl;
  const isFetchingLanguage = useSelector(getIsFetchingLanguage)

  const searchParams = useSearchParams();
  const params = new URLSearchParams(searchParams.toString());


  const handleLanguageSelect = (id) => {
    const lang = languages?.find((item) => item.id === Number(id));
    if (CurrentLanguage.id === lang.id) {
      return;
    }
    params.set("lang", lang.code);
    setHasFetchedSystemSettings(false);
    setHasFetchedCategories(false);
    updateStickyNoteTranslations()
    router.push(`${pathname}?${params.toString()}`, { scroll: false });
  };
  return (
    <DropdownMenu>
      <DropdownMenuTrigger disabled={isFetchingLanguage} className="border rounded-full py-2 px-4">
        <div className="flex items-center gap-1">
          <CustomImage
            key={CurrentLanguage?.id}
            src={CurrentLanguage?.image}
            alt={CurrentLanguage?.name || "language"}
            width={20}
            height={20}
            className="rounded-full"
          />
          <span>{CurrentLanguage?.code}</span>
        </div>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        className="min-w-0 max-h-[250px] overflow-y-auto"
        align={isRTL ? "start" : "end"}
      >
        {languages &&
          languages.map((lang) => (
            <DropdownMenuItem
              key={lang?.id}
              onClick={() => handleLanguageSelect(lang.id)}
              className="cursor-pointer"
            >
              <CustomImage
                src={lang?.image}
                alt={lang.name || "english"}
                width={20}
                height={20}
                className="rounded-full"
              />
              <span>{lang.code}</span>
            </DropdownMenuItem>
          ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export default LanguageDropdown;
