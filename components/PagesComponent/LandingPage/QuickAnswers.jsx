"use client";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { CurrentLanguageData } from "@/redux/reducer/languageSlice";
import { t } from "@/utils";
import { getFaqApi } from "@/utils/api";
import { useEffect, useState } from "react";
import { useSelector } from "react-redux";

const QuickAnswers = () => {
  const CurrentLanguage = useSelector(CurrentLanguageData);
  const [Faqs, setFaqs] = useState([]);

  const getFaqData = async () => {
    try {
      const res = await getFaqApi.getFaq();
      setFaqs(res?.data?.data);
    } catch (error) {
      console.log(error);
    }
  };

  useEffect(() => {
    getFaqData();
  }, [CurrentLanguage.id]);

  return (
    <section className="py-28" id="faq">
      <div className="container">
        <div className="flex items-center flex-col gap-6">
          <p className="outlinedSecHead">{t("navigating")}</p>
          <h1 className="landingSecHeader">{t("quickAnswers")}</h1>
        </div>
        <div className="flex flex-col gap-4 md:gap-8 mt-20">
          {Faqs &&
            Faqs.length > 0 &&
            Faqs.map((faq) => (
              <Accordion
                type="single"
                collapsible
                className="border rounded-md overflow-hidden"
                key={faq?.id}
              >
                <AccordionItem value={faq?.id} className="border-none group">
                  <AccordionTrigger
                    className="text-start font-bold text-base px-4 hover:no-underline bg-transparent 
                    group-data-[state=open]:bg-muted group-data-[state=open]:text-primary
                    group-data-[state=open]:border-b"
                  >
                    {faq?.translated_question || faq?.question}
                  </AccordionTrigger>
                  <AccordionContent className="bg-muted p-4">
                    <p className="text-base">
                      {faq?.translated_answer || faq?.answer}
                    </p>
                  </AccordionContent>
                </AccordionItem>
              </Accordion>
            ))}
        </div>
      </div>
    </section>
  );
};

export default QuickAnswers;
