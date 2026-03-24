// middleware.js
import { NextResponse } from "next/server";

const supportedLangs =
    process.env.NEXT_PUBLIC_SUPPORTED_LANGS_CODE
        ?.split(",")
        .map(code => code.trim().toLowerCase()) || ['en'];

const defaultLangCode =
    process.env.NEXT_PUBLIC_DEFAULT_LANG_CODE?.trim().toLowerCase() || supportedLangs[0];

export function middleware(request) {
    const url = request.nextUrl.clone();
    const searchParams = url.searchParams;
    const langParam = searchParams.get("lang")?.toLowerCase();

    let finalLang = langParam;

    // ❌ Missing or invalid lang
    if (!langParam || !supportedLangs.includes(langParam)) {
        finalLang = defaultLangCode;
    }

    // 🔁 Redirect only if needed
    if (finalLang !== langParam) {
        searchParams.set("lang", finalLang);
        url.search = searchParams.toString();

        const response = NextResponse.redirect(url);
        response.cookies.set("lang", finalLang, { path: "/" });
        return response;
    }

    // ✅ Valid lang → continue
    const response = NextResponse.next();
    response.cookies.set("lang", finalLang, { path: "/" });
    return response;
}


export const config = {
    matcher: [
        '/',
        '/about-us',
        '/ad-details/:slug*',
        '/ad-listing',
        '/ads',
        '/blogs',
        '/blogs/:slug*',
        '/chat',
        '/contact-us',
        '/edit-listing/:id*',
        '/faqs',
        '/favorites',
        '/job-applications',
        '/landing',
        '/my-ads',
        '/my-listing/:slug*',
        '/notifications',
        '/privacy-policy',
        '/profile',
        '/refund-policy',
        '/reviews',
        '/seller/:id*',
        '/subscription',
        '/terms-and-condition',
        '/transactions',
        '/user-subscription',
        '/user-verification',
        // Exclude these
        '/((?!api|_next/static|_next/image|favicon.ico|firebase-messaging-sw.js).*)',
    ],
}