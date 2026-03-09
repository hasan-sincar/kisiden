import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

const FaqCard = ({ faq }) => {
  return (
    <Accordion
      type="single"
      collapsible
      className="border rounded-md overflow-hidden"
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
          <p className="text-base">{faq?.translated_answer || faq?.answer}</p>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  );
};

export default FaqCard;
