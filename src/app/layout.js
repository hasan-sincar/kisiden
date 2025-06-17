import { Providers } from "@/redux/store/providers";
import "../../public/css/style.css";
import "bootstrap/dist/css/bootstrap.css";
import { Toaster } from "react-hot-toast";
import 'react-loading-skeleton/dist/skeleton.css'
import Script from "next/script";


export const generateMetadata = async () => {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}${process.env.NEXT_PUBLIC_END_POINT}get-system-settings`,
      { next: { revalidate: 3600 } } // revalidate every 1 hour
    );
    const data = await res.json();
    const favicon = data?.data?.favicon_icon;
    return {
      icons: [
        {
          url: favicon,
        },
      ],
    };
  } catch (error) {
    console.error("Error fetching MetaData:", error);
    return null;
  }
};


export default async function RootLayout({ children }) {

  return (
    <html lang="en" web-version={process.env.NEXT_PUBLIC_WEB_VERSION}>
      <head>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-9ndCyUaIbzAi2FUVXJi0CjmCapSmO7SnpJef0486qhLnuZ2cdeRhO02iuK6FUUVM" crossOrigin="anonymous" />
      </head>
      <body>
        {/* <Script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-xxxxxxxxxxxx"
          crossOrigin="anonymous" strategy="afterInteractive" /> */}
        <Script src="https://js.paystack.co/v1/inline.js" strategy="beforeInteractive" />
        <Providers >
          <Toaster position="top-center" reverseOrder={false} />
          {children}
        </Providers>
      </body>
    </html>
  );
}

