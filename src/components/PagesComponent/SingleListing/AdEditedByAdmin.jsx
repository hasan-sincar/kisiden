import { useRef, useState, useEffect } from 'react';
import { t } from '@/utils';
import { LiaUserEditSolid } from 'react-icons/lia';

const AdEditedByAdmin = ({ admin_edit_reason }) => {
    const textRef = useRef(null);
    const [isTextOverflowing, setIsTextOverflowing] = useState(false);
    const [isExpanded, setIsExpanded] = useState(false);

    useEffect(() => {
        const checkTextOverflow = () => {
            if (textRef.current && !isExpanded) {
                const element = textRef.current;
                const isOverflowing = element.scrollHeight > element.clientHeight;
                setIsTextOverflowing(isOverflowing);
            }
        };

        checkTextOverflow();
        window.addEventListener('resize', checkTextOverflow);

        return () => window.removeEventListener('resize', checkTextOverflow);
    }, [isExpanded]);

    return (
        <div className="ad-edited-admin-box">
            <div className="ad-edited-admin-icon">
                <LiaUserEditSolid className='admin-edited-icon' />
            </div>
            <div className="ad-edited-admin-content">
                <span className="ad-edited-admin-title">Ad Edited by <b>Admin</b></span>
                <div className="ad-edited-admin-desc">
                    <p ref={textRef} className={!isExpanded ? 'notficationDesc' : ''}>
                        {admin_edit_reason}
                    </p>
                </div>
                {isTextOverflowing && (
                    <button
                        className='admin-edited-viewmore'
                        onClick={() => setIsExpanded(!isExpanded)}
                    >
                        {isExpanded ? t('seeLess') : t('seeMore')}
                    </button>
                )}
            </div>
        </div>
    )
}

export default AdEditedByAdmin