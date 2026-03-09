import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import { t } from "@/utils";
import { useSelector } from "react-redux";

const AdLanguageSelector = ({
  langId,
  setLangId,
  languages,
  setTranslations,
}) => {
  const isRTL = useSelector(getIsRtl);

  const handleLangChange = (newId) => {
    setLangId(newId);
    setTranslations((t) => ({
      ...t,
      [newId]: t[newId] || {},
    }));
  };

  return (
    <div className="flex items-center gap-2">
      <p className="whitespace-nowrap text-sm font-medium hidden lg:block">
        {t("selectLanguage")}
      </p>
      <Select value={langId} onValueChange={handleLangChange}>
        <SelectTrigger className="gap-2">
          <SelectValue placeholder="Select language" />
        </SelectTrigger>
        <SelectContent align={isRTL ? "start" : "end"}>
          <SelectGroup>
            {languages &&
              languages.length > 0 &&
              languages.map((lang) => (
                <SelectItem key={lang.id} value={lang.id}>
                  {lang.name}
                </SelectItem>
              ))}
          </SelectGroup>
        </SelectContent>
      </Select>
    </div>
  );
};

export default AdLanguageSelector;
