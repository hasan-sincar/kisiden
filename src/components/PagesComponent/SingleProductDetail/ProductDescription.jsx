'use client';
import React, { useState, useRef, useEffect } from 'react';
import parse, { domToReact } from 'html-react-parser';
import Link from 'next/link';

function ProductDescription({ productData, t }) {
    const [showFullDescription, setShowFullDescription] = useState(false);
    const [isOverflowing, setIsOverflowing] = useState(false);
    const descriptionRef = useRef(null);
    const fullDescription = productData?.description?.replace(/\n/g, '<br />');

    useEffect(() => {
        const descriptionBody = descriptionRef.current;
        if (descriptionBody) {
            setIsOverflowing(descriptionBody.scrollHeight > descriptionBody.clientHeight);
        }
    }, [fullDescription]);

    const toggleDescription = () => {
        setShowFullDescription((prev) => !prev); // Keep this to manage the state.
    };

    const options = {
        replace: (domNode) => {
            // Check if the node is an anchor tag <a>
            if (domNode.name === 'a' && domNode.attribs && domNode.attribs.href) {
                const { href, ...otherAttribs } = domNode.attribs;

                return (
                    <Link href={href} {...otherAttribs} className="blog_link">
                        {domToReact(domNode.children)}
                    </Link>
                );
            }
        },
    };

    return (
        <div className="description_card card">
            {fullDescription && (
                <>
                    <div className="card-header">
                        <span>{t('description')}</span>
                    </div>
                    <div className={`card-body ${showFullDescription ? 'show-full' : 'truncate'}`} ref={descriptionRef}>
                        {parse(fullDescription || '', options)}
                    </div>
                    {isOverflowing && (
                        <div className="card-footer">
                            <button onClick={toggleDescription}>
                                {showFullDescription ? t('seeLess') : t('seeMore')}
                            </button>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}
export default ProductDescription;
