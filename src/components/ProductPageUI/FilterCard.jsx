'use client'
import { Checkbox, Collapse, Radio, Slider } from 'antd';
import React, { useState } from 'react';
import { DownOutlined } from '@ant-design/icons';
import FilterTree from '../Category/FilterTree';
import LocationTree from '../Category/LocationTree';
import { t } from '@/utils';
import { useSelector } from 'react-redux';
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice';
import { FaAngleDown } from 'react-icons/fa6';

const { Panel } = Collapse;

const formatter = (value) => `${value}KM`;

const FilterCard = ({ slug, setMinMaxPrice, setIsFetchSingleCatItem, setCountry, setState, setCity, selectedLocationKey, setSelectedLocationKey, setIsShowBudget, DatePosted, setDatePosted, setArea, setKmRange, setCategoryIds, CustomFields, setExtraDetails, ExtraDetails, setIsShowExtraDet, setIsShowKmRange, treeData }) => {


    const CurrentLanguage = useSelector(CurrentLanguageData)
    const [IsShowKmTooltip, setIsShowKmTooltip] = useState(false)
    const [tempRange, setTempRange] = useState(0)
    const [minPrice, setMinPrice] = useState('')
    const [maxPrice, setMaxPrice] = useState('')


    const handleMinPrice = (e) => {
        setMinPrice(e.target.value)
    }
    const handleMaxPrice = (e) => {
        setMaxPrice(e.target.value)
    }

    const handleApply = (e) => {
        e.preventDefault()
        setMinMaxPrice({
            min_price: minPrice,
            max_price: maxPrice
        })
        setIsFetchSingleCatItem((prev) => !prev)
        setIsShowBudget(true)
        setMinPrice('')
        setMaxPrice('')
    }

    const applyExtraDetails = () => {
        setIsFetchSingleCatItem((prev) => !prev)
        setIsShowExtraDet(true)
    }

    const handleDatePosted = (value) => {
        if (DatePosted === value) {
            setDatePosted('');
            setIsFetchSingleCatItem((prev) => !prev)
        } else {
            setDatePosted(value);
            setIsFetchSingleCatItem((prev) => !prev)
        }
    }

    const IsApplyDisabled = !minPrice || !maxPrice || Number(minPrice) >= Number(maxPrice)

    const handleRange = (range) => {
        setTempRange(range)
    }

    const handleCollapseChange = (prop) => {
        const isOpen = prop.includes('5')
        if (isOpen) {
            setIsShowKmTooltip(true)
        }
        else {
            setIsShowKmTooltip(false)
        }
    }

    const handleInputChange = (id, value) => {
        setExtraDetails((prevDetails) => ({ ...prevDetails, [id]: value !== null ? value : '' }));
        setIsShowExtraDet(false)
    };

    const handleCheckboxChange = (e, fieldId, value) => {
        const isChecked = e.target.checked;
        setIsShowExtraDet(false)
        setExtraDetails((prevDetails) => {
            const currentValues = prevDetails[fieldId] || [];
            let updatedValues;

            if (isChecked) {
                updatedValues = [...currentValues, value];
            } else {
                updatedValues = currentValues.filter((v) => v !== value);
            }

            return { ...prevDetails, [fieldId]: updatedValues.length ? updatedValues : '' };
        });
    };

    const IsFilterApplyDisabled = ExtraDetails && Object?.values(ExtraDetails)?.every(value => value === '' || value?.length === 0);


    const handleApplyRange = () => {
        setIsShowKmRange(true)
        setKmRange(tempRange)
        setSelectedLocationKey([])
        setIsFetchSingleCatItem((prev) => !prev)
    }

    return (
        <div className="filter_card card">
            <div className="card-header">
                <span>{t('filters')}</span>
            </div>
            <div className="card-body">
                <Collapse
                    className="all_filters"
                    expandIconPosition="right"
                    expandIcon={({ isActive }) => (
                        <DownOutlined rotate={isActive ? 180 : 0} size={24} />
                    )}
                    defaultActiveKey={['1']}
                    onChange={handleCollapseChange}
                >
                    <Panel header={t("category")} key="1">
                        <FilterTree slug={slug} setCategoryIds={setCategoryIds} treeData={treeData} />
                    </Panel>
                    <Panel header={t("location")} key="2" id='loc'>
                        <LocationTree setCountry={setCountry} setState={setState} setCity={setCity} setArea={setArea} setIsFetchSingleCatItem={setIsFetchSingleCatItem} selectedLocationKey={selectedLocationKey} setSelectedLocationKey={setSelectedLocationKey} setKmRange={setKmRange} setIsShowKmRange={setIsShowKmRange} />
                    </Panel>
                    <Panel header={t("budget")} key="3">
                        <form className="budget_div" onSubmit={handleApply}>
                            <div className="max_min">
                                <input type='number' required value={minPrice} onChange={handleMinPrice} placeholder={t('from')} />
                                <input type='number' required value={maxPrice} onChange={handleMaxPrice} placeholder={t('to')} />
                            </div>
                            <div className="apply_budget">
                                <button type='submit' disabled={IsApplyDisabled} className={`${IsApplyDisabled ? 'not_allowed' : 'apply_btn_transparent'}`} >{t('apply')}</button>
                            </div>
                        </form>
                    </Panel>

                    <Panel header={t("datePosted")} key="4">
                        <div className='date_posted_checkbox'>
                            <Checkbox
                                onChange={() => handleDatePosted('all-time')}
                                checked={DatePosted === 'all-time'}
                            >
                                {t('allTime')}
                            </Checkbox>
                            <Checkbox
                                onChange={() => handleDatePosted('today')}
                                checked={DatePosted === 'today'}
                            >
                                {t('today')}
                            </Checkbox>
                            <Checkbox
                                onChange={() => handleDatePosted('within-1-week')}
                                checked={DatePosted === 'within-1-week'}
                            >
                                {t('within1Week')}
                            </Checkbox>
                            <Checkbox
                                onChange={() => handleDatePosted('within-2-week')}
                                checked={DatePosted === 'within-2-week'}
                            >
                                {t('within2Weeks')}
                            </Checkbox>
                            <Checkbox
                                onChange={() => handleDatePosted('within-1-month')}
                                checked={DatePosted === 'within-1-month'}
                            >
                                {t('within1Month')}
                            </Checkbox>
                            <Checkbox
                                onChange={() => handleDatePosted('within-3-month')}
                                checked={DatePosted === 'within-3-month'}
                            >
                                {t('within3Months')}
                            </Checkbox>
                        </div>
                    </Panel>

                    <Panel header={t("nearByKmRange")} key="5">
                        <div className='kmRange_cont'>
                            <Slider className='kmRange_slider' value={tempRange} tooltip={{ formatter, ...(IsShowKmTooltip && tempRange !== 0 ? { open: true } : { open: false }) }} onChange={handleRange} />
                            <div className="apply_budget">
                                <button className={`${tempRange === 0 ? 'not_allowed' : 'apply_btn_transparent'}`} disabled={tempRange === 0} onClick={handleApplyRange}>{t('applyRange')}</button>
                            </div>
                        </div>
                    </Panel>

                    {
                        CustomFields && CustomFields.length > 0 && CustomFields.some(field =>
                            field.type === 'checkbox' || field.type === 'radio' || field.type === 'dropdown'
                        ) &&
                        < Panel header={t('extradetails')} key="6">

                            <div className='extra_Det_wrapper'>
                                {
                                    CustomFields.map((field, index) => (
                                        <React.Fragment key={field.id}>
                                            {field.type === 'checkbox' && (

                                                <div className='auth_in_cont' key={field.id}>
                                                    <label className='auth_pers_label' htmlFor={field.id}>{field.name}</label>
                                                    <div className='date_posted_checkbox' id={field.id}>
                                                        {field.values.map((value) => (
                                                            <Checkbox key={value} onChange={(e) => handleCheckboxChange(e, field.id, value)}
                                                                checked={ExtraDetails[field.id]?.includes(value)}>
                                                                {value}
                                                            </Checkbox>
                                                        ))}
                                                    </div>
                                                </div>

                                            )}
                                            {field.type === 'radio' && (

                                                <div className='auth_in_cont' key={field.id}>
                                                    <label className='auth_pers_label' htmlFor={field.id}>{field.name}</label>
                                                    <div className='radio_group mt-0' id={field.id}>
                                                        <Radio.Group className='customfilter_radio' value={ExtraDetails[field.id]} onChange={(e) => handleInputChange(field.id, e.target.value)}>
                                                            {field.values.map((value) => (
                                                                <Radio key={value} value={value}>
                                                                    {value}
                                                                </Radio>
                                                            ))}
                                                        </Radio.Group>
                                                    </div>
                                                </div>
                                            )}

                                            {
                                                field.type === 'dropdown' && (

                                                    <div className='auth_in_cont' key={field.id}>
                                                        <label className='auth_pers_label' htmlFor={field.id}>{field.name}</label>
                                                        <div className='cat_select_wrapper'>
                                                            <select id={field.id} className='auth_input flter_dropdown' value={ExtraDetails[field.id] || ''} onChange={(e) => handleInputChange(field.id, e.target.value)}>
                                                                <option value="">{t('select')} {field.name}</option>
                                                                {field.values.map((value) => (
                                                                    <option key={value} value={value}>
                                                                        {value}
                                                                    </option>
                                                                ))}
                                                            </select>
                                                            <FaAngleDown className='cat_select_arrow' />
                                                        </div>
                                                    </div>
                                                )
                                            }
                                        </React.Fragment>
                                    ))}
                                <div className="apply_budget">
                                    <button onClick={applyExtraDetails} disabled={IsFilterApplyDisabled} className={`${IsFilterApplyDisabled ? 'not_allowed' : 'apply_btn_transparent'}`} >{t('apply')}</button>
                                </div>
                            </div >
                        </Panel>
                    }
                </Collapse>
            </div>

        </div >
    );
};


export default FilterCard;
