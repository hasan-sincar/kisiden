import Skeleton, { SkeletonTheme } from "react-loading-skeleton";

const PaymentModalSkeleton = () => {
  return (
    <SkeletonTheme baseColor="lightgray" highlightColor="#e0e0e0">
      <div className="card">
        <div className="card-header">
            <Skeleton width="40%" />
        </div>
        <div className="card-body">
          <div className="row">
            <div className="col-12">
              <Skeleton width="100%" />
            </div>
            <div className="col-12">
              <Skeleton width="70%" />
            </div>
            <div className="col-12">
              <Skeleton width="100%" />
            </div>
            <div className="col-12">
              <Skeleton width="70%" />
            </div>
            <div className="col-12">
              <Skeleton width="100%" />
            </div>
            <div className="col-12">
              <Skeleton width="70%" />
            </div>
          </div>
        </div>
      </div>
    </SkeletonTheme>
  );
};

export default PaymentModalSkeleton;
