"use client"
import { t } from "@/utils"
import { CheckCircle2 } from "lucide-react"

const FreeAdListingPlaceholder = () => {
    return (
        <div className="flex flex-col gap-3 items-center justify-center py-16 px-4 text-center bg-white rounded-2xl border-2 border-dashed shadow-sm mt-8">
            <div className="bg-primary/10 rounded-full">
                <CheckCircle2 className="size-12 text-primary animate-pulse" />
            </div>
            <h2 className="text-2xl md:text-3xl font-bold">
                {t("freeAdListingEnabled")}
            </h2>
            <p className="text-muted-foreground max-w-md text-lg leading-relaxed">
                {t("postFreeOfCost")}
            </p>
        </div>
    )
}

export default FreeAdListingPlaceholder
