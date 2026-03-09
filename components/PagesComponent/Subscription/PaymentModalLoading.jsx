

const PaymentModalLoading = () => {
    return (
        <div className="w-full p-2 animate-pulse">
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                    {/* Logo skeleton */}
                    <div className="w-8 h-8 bg-gray-200 rounded-md"></div>

                    {/* Text skeleton */}
                    <div className="h-7 bg-gray-200 rounded-md w-24"></div>
                </div>

                {/* Arrow skeleton */}
                <div className="w-4 h-4 bg-gray-200 rounded-md"></div>
            </div>
        </div>
    )
}

export default PaymentModalLoading