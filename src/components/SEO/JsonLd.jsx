/**
 * JsonLd Component
 *
 * A server component for adding structured data to pages.
 * Unlike using next/script, this ensures the JSON-LD data is
 * rendered server-side and included in the initial HTML,
 * which is essential for SEO and search engine crawling.
 */

export default function JsonLd({ data }) {
    return (
        <script
            id="schema-jsonld"
            async
            src=" "
            type="application/ld+json"
            dangerouslySetInnerHTML={{
                __html: JSON.stringify(data).replace(/</g, "\\u003c"),
            }}
        />
    );
}