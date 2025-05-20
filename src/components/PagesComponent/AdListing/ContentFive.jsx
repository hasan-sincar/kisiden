'use client'
import MapComponent from '@/components/MyListing/MapComponent';
import { getIsBrowserSupported } from '@/redux/reuducer/locationSlice';
import { t } from '@/utils';
import React, { useState } from 'react';
import { BiMapPin } from 'react-icons/bi';
import { GrLocation } from 'react-icons/gr';
import { MdOutlineMyLocation } from 'react-icons/md';
import { useSelector } from 'react-redux';
import AddAddressManuallyModal from './AddAddressManuallyModal';

const ContentFive = ({ getCurrentLocation, handleGoBack, Location, handleFullSubmission, getLocationWithMap, setAddress, Address, isAdPlaced, CountryStore, setCountryStore, handleCountryScroll, StateStore, setStateStore, handleStateScroll, setCityStore, CityStore, handleCityScroll, AreaStore, setAreaStore, handleAreaScroll, setLocation }) => {

    const IsBrowserSupported = useSelector(getIsBrowserSupported)
    const [IsManuallyAddress, setIsManuallyAddress] = useState(false)

    return (
        <>
            <div className="col-12">
                <div className='locationTabHead'>
                    <h2>{t('addLocation')}</h2>
                    {
                        IsBrowserSupported &&
                        <button className='locateMeBtnCont' onClick={getCurrentLocation}>
                            <MdOutlineMyLocation size={18} />
                            <span>{t('locateMe')}</span>
                        </button>
                    }
                </div>
            </div>
            <div className="col-12">
                <MapComponent getLocationWithMap={getLocationWithMap} Location={Location} />
            </div>

            <div className="col-12">
                <div className='locationAddressCont'>
                    <div className='LocationaddressIconCont'>
                        <BiMapPin size={36} color={getComputedStyle(document.documentElement).getPropertyValue('--primary-color').trim()} />
                    </div>
                    <div className='locAddressContent'>
                        <h6>{t('address')}</h6>
                        {
                            Location?.address ? <p>{Location?.address}</p> : t('addYourAddress')
                        }
                    </div>
                </div>
            </div>

            <div className="col-12">
                <div className="divider-container">
                    <div className="divider-line"></div>
                    <div className="divider-text">{t('or')}</div>
                </div>
            </div>

            <div className="col-12">
                <div className='locAddAddresBtnCont'>
                    <h5>{t('whatLocAdYouSelling')}</h5>
                    <button className='addAddressBtn' onClick={() => setIsManuallyAddress(true)}>
                        <GrLocation size={18} />
                        <span>{t('addLocation')}</span>
                    </button>
                </div>
            </div>
            <div className="col-12">
                <div className="formBtns">
                    <button className='backBtn' onClick={handleGoBack}>{t('back')}</button>
                    {
                        isAdPlaced ?
                            <button className='btn btn-secondary' disabled>{t('posting')}</button>
                            :
                            <button className='nextBtn' onClick={handleFullSubmission} disabled={isAdPlaced}> {t('postNow')}</button>
                    }
                </div>
            </div>
            <AddAddressManuallyModal isOpen={IsManuallyAddress} OnHide={() => setIsManuallyAddress(false)} setCountryStore={setCountryStore} CountryStore={CountryStore} handleCountryScroll={handleCountryScroll} StateStore={StateStore} setStateStore={setStateStore} handleStateScroll={handleStateScroll} CityStore={CityStore} setCityStore={setCityStore} handleCityScroll={handleCityScroll} AreaStore={AreaStore} setAreaStore={setAreaStore} handleAreaScroll={handleAreaScroll} setAddress={setAddress} Address={Address} setLocation={setLocation} />
        </>
    )
}

export default ContentFive
