'use client'
import Image from 'next/image'
import Link from 'next/link'
import { FaArrowRight } from 'react-icons/fa6'
import { placeholderImage, t } from '@/utils'

const OurBlogCard = ({ data }) => {
    return (
        <div className='ourblog_card'>
            <Image src={data?.image} width={388} height={200} alt={data?.title} className='blog_card_img' onErrorCapture={placeholderImage} />
            <h5 className='ourblog_card_title'>
                {data?.title}
            </h5>
            <p className='ourblog_card_desc'>
                {data?.description && typeof data?.description === 'string'
                    ? data?.description.replace(/<[^>]*>/g, '')
                    : ''}
            </p>
            <Link href={`/blogs/${data?.slug}`} className='read_article' >
                <span>
                    {t('readArticle')}
                </span>
                <span> <FaArrowRight size={20} className='read_icon' /></span>
            </Link>
        </div>

    )
}

export default OurBlogCard