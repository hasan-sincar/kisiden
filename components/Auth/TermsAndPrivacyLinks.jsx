import CustomLink from "@/components/Common/CustomLink";

const TermsAndPrivacyLinks = ({ t, settings, OnHide }) => {
  return (
    <div className="text-center">
      {t("agreeSignIn")} {settings?.company_name} <br />
      <CustomLink
        href="/terms-and-condition"
        className="text-primary underline"
        onClick={OnHide}
      >
        {t("termsService")}
      </CustomLink>{" "}
      {t("and")}{" "}
      <CustomLink
        href="/privacy-policy"
        className="text-primary underline"
        onClick={OnHide}
      >
        {t("privacyPolicy")}
      </CustomLink>
    </div>
  );
};

export default TermsAndPrivacyLinks;
