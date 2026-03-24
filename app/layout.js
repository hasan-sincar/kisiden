import { Manrope } from "next/font/google";
import "./globals.css";
import { Providers } from "@/redux/store/providers";
import { Toaster } from "@/components/ui/sonner";
import { cookies } from "next/headers";

const manrope = Manrope({
  weight: ["200", "300", "400", "500", "600", "700", "800"],
  subsets: ["latin"],
  display: "swap",
});

export const generateMetadata = () => {
  return {
    title: process.env.NEXT_PUBLIC_META_TITLE,
    description: process.env.NEXT_PUBLIC_META_DESCRIPTION,
    keywords: process.env.NEXT_PUBLIC_META_kEYWORDS,
    openGraph: {
      title: process.env.NEXT_PUBLIC_META_TITLE,
      description: process.env.NEXT_PUBLIC_META_DESCRIPTION,
      keywords: process.env.NEXT_PUBLIC_META_kEYWORDS,
    },
  };
};

export default async function RootLayout({ children }) {
  const cookieStore = await cookies();
  const lang = cookieStore.get("lang")?.value || "bg";

  return (
    <html
      lang={lang}
      web-version={process.env.NEXT_PUBLIC_WEB_VERSION}
      className="scroll-smooth"
    >
      <body className={`${manrope.className} !pointer-events-auto`}>
        <Providers>
          {children}
          <Toaster position="top-center" />
        </Providers>
        {/* <div id="recaptcha-container"></div> */}
      </body>
    </html>
  );
}
