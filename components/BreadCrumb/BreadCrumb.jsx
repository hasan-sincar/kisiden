"use client";
import { Fragment } from "react";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { useSelector } from "react-redux";
import { t } from "@/utils";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import CustomLink from "@/components/Common/CustomLink";

const BreadCrumb = ({ title2 }) => {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const langCode = searchParams.get("lang")
  const BreadcrumbPath = useSelector(
    (state) => state.BreadcrumbPath.BreadcrumbPath
  );

  const items = [
    {
      title: t("home"),
      key: "home",
      href: "/",
      isLink: true,
    },
    ...(title2
      ? [
        {
          title: title2,
          key: "custom",
          isLink: false,
        },
      ]
      : BreadcrumbPath && BreadcrumbPath.length > 0
        ? BreadcrumbPath.map((crumb, index) => {
          const isLast = index === BreadcrumbPath.length - 1;
          return {
            title: crumb.name,
            key: index + 1,
            href: crumb?.slug,
            isLink: !isLast && !crumb.isCurrent,
            onClick: (e) => {
              e.preventDefault();
              if (crumb.isAllCategories) {
                // For "All Categories", preserve other URL parameters but remove category
                const newSearchParams = new URLSearchParams(searchParams);
                newSearchParams.delete("category");
                newSearchParams.set("lang", langCode);
                const newUrl = `/ads?${newSearchParams.toString()}`;
                if (pathname === '/ads') {
                  window.history.pushState(null, "", newUrl);
                } else {
                  router.push(newUrl);
                }
              } else {
                // ✅ ensure lang param is present
                const newSearchParams = new URLSearchParams(searchParams);
                newSearchParams.set("lang", langCode);

                // if crumb.slug already has query params, merge them
                let newUrl = crumb.slug.includes("?")
                  ? `${crumb.slug}&lang=${langCode}`
                  : `${crumb.slug}?lang=${langCode}`;
                const targetPath = newUrl.split('?')[0];
                if (pathname === targetPath) {
                  window.history.pushState(null, "", newUrl);
                } else {
                  router.push(newUrl);
                }
              }
            },
          };
        })
        : []),
  ];

  return (
    <div className="bg-muted">
      <div className="container py-5">
        <Breadcrumb>
          <BreadcrumbList>
            {items?.map((item, index) => {
              return (
                <Fragment key={index}>
                  <BreadcrumbItem>
                    {item.isLink && item.onClick ? (
                      <BreadcrumbLink
                        href="#"
                        className="text-black"
                        onClick={(e) => {
                          e.preventDefault();
                          item.onClick(e);
                        }}
                      >
                        {item.title}
                      </BreadcrumbLink>
                    ) : item.isLink ? (
                      <CustomLink href={item?.href} passHref>
                        <BreadcrumbLink asChild className="text-black">
                          <span>{item.title}</span>
                        </BreadcrumbLink>
                      </CustomLink>
                    ) : (
                      <p className="text-black">{item.title}</p>
                    )}
                  </BreadcrumbItem>
                  {index !== items?.length - 1 && <BreadcrumbSeparator />}
                </Fragment>
              );
            })}
          </BreadcrumbList>
        </Breadcrumb>
      </div>
    </div>
  );
};

export default BreadCrumb;
