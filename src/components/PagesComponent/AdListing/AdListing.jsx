'use client'
import { useEffect, useState } from 'react'
import BreadcrumbComponent from '../../Breadcrumb/BreadcrumbComponent'
import ContentOne from './ContentOne'
import ContentTwo from './ContentTwo'
import ContentThree from './ContentThree'
import ContentFour from './ContentFour'
import ContentFive from './ContentFive'
import AdSuccessfulModal from './AdSuccessfulModal'
import { useSelector } from 'react-redux'
import { generateSlug, isLogin, isValidURL, t } from '@/utils'
import { addItemApi, categoryApi, getAreasApi, getCitiesApi, getCoutriesApi, getCustomFieldsApi, getStatesApi } from '@/utils/api'
import toast from 'react-hot-toast'
import axios from 'axios'
import { CurrentLanguageData } from '@/redux/reuducer/languageSlice';
import { settingsData } from '@/redux/reuducer/settingSlice'
import withRedirect from '@/components/Layout/withRedirect'

const AdListing = () => {

  const CurrentLanguage = useSelector(CurrentLanguageData)
  const systemSettingsData = useSelector(settingsData)
  const settings = systemSettingsData?.data
  const [currentPage, setCurrentPage] = useState()
  const [lastPage, setLastPage] = useState()
  const [activeTab, setActiveTab] = useState(1)
  const [IsAdSuccessfulModal, setIsAdSuccessfulModal] = useState(false)
  const [CurrenCategory, setCurrenCategory] = useState([])
  const [CurrentPath, setCurrentPath] = useState([])
  const [CustomFields, setCustomFields] = useState([])
  const [AdListingDetails, setAdListingDetails] = useState({
    title: '',
    slug: '',
    desc: '',
    price: '',
    phonenumber: '',
    link: '',
  })
  const [extraDetails, setExtraDetails] = useState({})
  const [uploadedImages, setUploadedImages] = useState([]);
  const [OtherImages, setOtherImages] = useState([]);
  const [Location, setLocation] = useState({})
  const [CountryStore, setCountryStore] = useState({
    Countries: [],
    SelectedCountry: {},
    CountrySearch: '',
    currentPage: 1,
    hasMore: false,
  })
  const [StateStore, setStateStore] = useState({
    States: [],
    SelectedState: {},
    StateSearch: '',
    currentPage: 1,
    hasMore: false,
  })
  const [CityStore, setCityStore] = useState({
    Cities: [],
    SelectedCity: {},
    CitySearch: '',
    currentPage: 1,
    hasMore: false,
  })
  const [AreaStore, setAreaStore] = useState({
    Areas: [],
    SelectedArea: {},
    AreaSearch: '',
    currentPage: 1,
    hasMore: false,
  })
  const [Address, setAddress] = useState('')
  const [isAdPlaced, setIsAdPlaced] = useState(false)
  const [CreatedAdSlug, setCreatedAdSlug] = useState('')
  const [DisabledTab, setDisabledTab] = useState({
    selectCategory: false,
    details: true,
    extraDet: true,
    img: true,
    loc: true
  })
  const [IsLoading, setIsLoading] = useState(false)
  const [IsLoadMoreCat, setIsLoadMoreCat] = useState(false)
  const [filePreviews, setFilePreviews] = useState({});


  const getCountriesData = async (search, page) => {
    try {
      // Fetch countries
      const params = {};
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getCoutriesApi.getCoutries(params);
      let allCountries
      if (page > 1) {
        allCountries = [...CountryStore?.Countries, ...res?.data?.data?.data]
      }
      else {
        allCountries = res?.data?.data?.data
      }
      setCountryStore(prev => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Countries: allCountries,
        hasMore: res?.data?.data?.current_page < res?.data?.data?.last_page ? true : false
      }))
    } catch (error) {
      console.error("Error fetching countries data:", error);
    }
  };

  const handleCountryScroll = (event) => {
    const { target } = event;
    if (target.scrollTop + target.offsetHeight >= target.scrollHeight && CountryStore?.hasMore) {
      getCountriesData('', CountryStore?.currentPage + 1)
    }
  }

  const getStatesData = async (search, page) => {
    try {

      const params = {
        country_id: CountryStore?.SelectedCountry?.id
      };
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getStatesApi.getStates(params);

      let allStates
      if (page > 1) {
        allStates = [...StateStore?.States, ...res?.data?.data?.data]
      }
      else {
        allStates = res?.data?.data?.data
      }

      setStateStore(prev => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        States: allStates,
        hasMore: res?.data?.data?.current_page < res?.data?.data?.last_page ? true : false
      }))

    } catch (error) {
      console.error("Error fetching states data:", error);
      return [];
    }
  };

  const handleStateScroll = (event) => {
    const { target } = event;
    if (target.scrollTop + target.offsetHeight >= target.scrollHeight && StateStore?.hasMore) {
      getStatesData('', StateStore?.currentPage + 1)
    }
  }
  const getCitiesData = async (search, page) => {
    try {
      const params = {
        state_id: StateStore?.SelectedState?.id
      };
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getCitiesApi.getCities(params);
      let allCities
      if (page > 1) {
        allCities = [...CityStore?.Cities, ...res?.data?.data?.data]
      }
      else {
        allCities = res?.data?.data?.data
      }
      setCityStore(prev => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Cities: allCities,
        hasMore: res?.data?.data?.current_page < res?.data?.data?.last_page ? true : false
      }))
    } catch (error) {
      console.error("Error fetching cities data:", error);
      return [];
    }
  };

  const handleCityScroll = (event) => {
    const { target } = event;
    if (target.scrollTop + target.offsetHeight >= target.scrollHeight && CityStore?.hasMore) {
      getCitiesData('', CityStore?.currentPage + 1)
    }
  }

  const getAreaData = async (search, page) => {
    const params = {
      city_id: CityStore?.SelectedCity?.id
    };
    if (search) {
      params.search = search; // Send only 'search' if provided
    } else {
      params.page = page; // Send only 'page' if no search
    }
    try {
      const res = await getAreasApi.getAreas(params);
      let allArea
      if (page > 1) {
        allArea = [...AreaStore?.Areas, ...res?.data?.data?.data]
      }
      else {
        allArea = res?.data?.data?.data
      }
      setAreaStore(prev => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Areas: allArea,
        hasMore: res?.data?.data?.current_page < res?.data?.data?.last_page ? true : false
      }))
    } catch (error) {
      console.error("Error fetching cities data:", error);
      return [];
    }
  };

  const handleAreaScroll = (event) => {
    const { target } = event;
    if (target.scrollTop + target.offsetHeight >= target.scrollHeight && AreaStore?.hasMore) {
      getAreaData('', AreaStore?.currentPage + 1)
    }
  }

  useEffect(() => {
    const timeout = setTimeout(() => {
      getCountriesData(CountryStore?.CountrySearch, 1);
    }, 500);
    return () => {
      clearTimeout(timeout);
    };
  }, [CountryStore?.CountrySearch])

  useEffect(() => {
    if (CountryStore?.SelectedCountry?.id) {
      const timeout = setTimeout(() => {
        getStatesData(StateStore?.StateSearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [CountryStore?.SelectedCountry?.id, StateStore?.StateSearch])

  useEffect(() => {
    if (StateStore?.SelectedState?.id) {
      const timeout = setTimeout(() => {
        getCitiesData(CityStore?.CitySearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [StateStore?.SelectedState?.id, CityStore?.CitySearch])

  useEffect(() => {
    if (CityStore?.SelectedCity?.id) {
      const timeout = setTimeout(() => {
        getAreaData(AreaStore?.AreaSearch);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [CityStore?.SelectedCity?.id, AreaStore?.AreaSearch])

  const getLocationWithMap = async (pos) => {
    try {
      const response = await axios.get(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.lat},${pos.lng}&key=${settings?.place_api_key}`);

      if (response.data.error_message) {
        toast.error(response.data.error_message)
        return
      }

      let city = '';
      let state = '';
      let country = '';
      let address = '';

      // Extract address components
      // Loop through all results
      response.data.results.forEach(result => {
        const addressComponents = result.address_components;
        const getAddressComponent = (type) => {
          const component = addressComponents.find(comp => comp.types.includes(type));
          return component ? component.long_name : '';
        };

        if (!city) city = getAddressComponent("locality");
        if (!state) state = getAddressComponent("administrative_area_level_1");
        if (!country) country = getAddressComponent("country");
        if (!address) address = result.formatted_address;
      });

      // Create location data object
      const locationData = {
        lat: pos.lat,
        long: pos.lng,
        city,
        state,
        country,
        address
      };

      // Set the location by map
      setLocation(locationData);
    } catch (error) {
      console.error('Error fetching location data:', error);
    }
  }

  const getCurrentLocation = async () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        async (position) => {
          try {
            const locationData = {
              latitude: position.coords.latitude,
              longitude: position.coords.longitude
            };

            const response = await axios.get(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${locationData.latitude},${locationData.longitude}&key=${settings?.place_api_key}`);


            if (response.data.error_message) {
              toast.error(response.data.error_message)
              return
            }

            // Loop through all results
            let city = '';
            let state = '';
            let country = '';
            let address = '';

            response.data.results.forEach(result => {
              const addressComponents = result.address_components;
              const getAddressComponent = (type) => {
                const component = addressComponents.find(comp => comp.types.includes(type));
                return component ? component.long_name : '';
              };

              if (!city) city = getAddressComponent("locality");
              if (!state) state = getAddressComponent("administrative_area_level_1");
              if (!country) country = getAddressComponent("country");
              if (!address) address = result.formatted_address;
            });

            const cityData = {
              lat: locationData.latitude,
              long: locationData.longitude,
              city,
              state,
              country,
              address
            };

            setLocation(cityData);
          } catch (error) {
            console.error('Error fetching location data:', error);
          }
        },
        (error) => {
          toast.error(t('locationNotGranted'));
        }
      );
    } else {
      toast.error(t('geoLocationNotSupported'));
    }
  };

  const allCategoryIdsString = CurrentPath.map(category => category.id).join(',');

  let lastItemId = CurrentPath[CurrentPath.length - 1]?.id;

  const getCategoriesData = async (type) => {
    try {
      setIsLoading(true)
      const res = await categoryApi.getCategory({ category_id: type ? type : lastItemId })
      const data = res?.data?.data?.data
      setCurrenCategory(data)
      setCurrentPage(res?.data?.data?.current_page); // Update the current page
      setLastPage(res?.data?.data?.last_page); // Update the current page
    } catch (error) {
      console.log(error)
    } finally {
      setIsLoading(false)
    }
  }
  const getCustomFieldsData = async (id) => {
    try {
      const res = await getCustomFieldsApi.getCustomFields({ category_ids: allCategoryIdsString })
      const data = res?.data?.data
      setCustomFields(data)
      const newExtraDetails = {};
      data.forEach(item => {
        switch (item.type) {
          case 'checkbox':
            newExtraDetails[item.id] = []; // Initialize with an empty array
            break;
          case 'dropdown':
            newExtraDetails[item.id] = ''; // Initialize with an empty string
            break;
          case 'radio':
            newExtraDetails[item.id] = []; // Initialize with an empty string
            break;
          case 'fileinput':
            newExtraDetails[item.id] = null; // Initialize with null
            break;
          case 'textbox':
            newExtraDetails[item.id] = ''; // Initialize with an empty string
            break;
          case 'number':
            newExtraDetails[item.id] = null; // Initialize with null
            break;
          case 'text':
            newExtraDetails[item.id] = ''; // Initialize with an empty string
            break;
          default:
            break;
        }
      });
      setExtraDetails(newExtraDetails);
    } catch (error) {
      console.log(error)
    }
  }

  useEffect(() => {
    getCategoriesData()
  }, [lastItemId, CurrentLanguage])

  const handleCategoryTabClick = async (category) => {
    setCurrentPath((prevPath) => [...prevPath, category]);
    if (category?.subcategories_count > 0) {
      if (category?.subcategories?.length > 0) {
        setCurrenCategory(category?.subcategories)
      } else {
        await getCategoriesData(category?.id)
      }
    }
    else {
      setActiveTab(2)
      setDisabledTab({
        selectCategory: true,
        details: false,
        extraDet: false,
        img: false,
        loc: false
      });
    }
  }

  useEffect(() => {
    if (activeTab === 2) {
      if (allCategoryIdsString) {
        getCustomFieldsData()
      }
    }
  }, [allCategoryIdsString])

  const handleGoBack = () => {
    setActiveTab((prev) => {
      if (CustomFields.length === 0 && activeTab === 4) {
        return prev - 2
      }
      else {
        return prev - 1;
      }
    })
  }

  const handleSelectedTabClick = (id) => {
    setCustomFields([])
    setAdListingDetails({
      title: '',
      slug: '',
      desc: '',
      price: '',
      phonenumber: '',
      link: '',
    })
    if (activeTab !== 1) {
      setActiveTab(1);
      setDisabledTab({
        selectCategory: false,
        details: true,
        extraDet: true,
        img: true,
        loc: true
      });
    }
    const index = CurrentPath.findIndex(item => item.id === id);
    if (index !== -1) {
      const newPath = CurrentPath.slice(0, index);
      setCurrentPath(newPath);
    }
    if (index === 0) {
      setCurrenCategory([])
      getCategoriesData("")
      setCurrentPath([])
      setCustomFields([])
    }
  };

  const handleAdListingChange = (e) => {
    const { name, value } = e.target;

    setAdListingDetails((prevDetails) => {
      const updatedDetails = {
        ...prevDetails,
        [name]: value,
      };
      if (name === 'title') {
        updatedDetails.slug = generateSlug(value);
      }
      return updatedDetails;
    });
  };

  const handleDetailsSubmit = () => {

    const isValidSlug = /^[a-z0-9-]+$/.test(AdListingDetails.slug.trim());

    if (AdListingDetails.title.trim() == "") {
      toast.error(t('titleRequired'))
      return;
    }
    else if (AdListingDetails.desc.trim() == "") {
      toast.error(t('descriptionRequired'))
      return;
    } else if (AdListingDetails.price == "") {
      toast.error(t('priceRequired'))
      return;
    } else if (AdListingDetails?.price < 0) {
      toast.error(t('enterValidPrice'));
      return
    }
    else if (AdListingDetails.phonenumber == "") {
      toast.error(t('phoneRequired'))
      return;
    } else if (AdListingDetails.slug.trim() && !isValidSlug) {
      toast.error(t('addValidSlug'));
      return;
    }


    if (CustomFields?.length === 0) {
      setActiveTab(4)
    }
    else {
      setActiveTab(3)
    }
  }

  const submitExtraDetails = (e) => {
    if (!validateExtraDetails(CustomFields, extraDetails)) {
      return;
    }
    setActiveTab(4)
  };

  const handleImageSubmit = () => {
    if (uploadedImages.length === 0) {
      toast.error(t('uploadMainPicture'))
      return
    }
    setActiveTab(5)
  }

  const validateExtraDetails = (CustomFields, extraDetails) => {
    for (const field of CustomFields) {

      const { name, type, required, id, min_length, } = field;

      if (required) {
        if (type !== 'checkbox' && type !== 'radio' && type !== 'fileinput' && !(type === 'textbox' ? extraDetails[id]?.trim() : extraDetails[id])) {
          toast.error(`${t('fillDetails')} ${name}.`);
          return false;
        }

        if (type === 'fileinput' && !extraDetails[id] && !filePreviews[id]) {
          toast.error(`${t('fillDetails')} ${name}.`);
          return false
        }

        if ((type === 'checkbox' || type === 'radio') && extraDetails[id].length === 0) {
          toast.error(`${t('selectAtleastOne')} ${name}.`);
          return false;
        }

        // Required field with min_length validation
        if (extraDetails[id] && type === 'textbox' && extraDetails[id].trim().length < min_length) {
          toast.error(`${name} ${t('mustBeAtleast')} ${min_length} ${t('charactersLong')}`);
          return false;
        }
        if (extraDetails[id] && type === 'number' && extraDetails[id].length < min_length) {
          toast.error(`${name} ${t('mustBeAtleast')} ${min_length} ${t('digitLong')}`);
          return false;
        }
      }

      // Non-required field with min_length validation
      if (!required && extraDetails[id] && type === 'textbox' && extraDetails[id].length < min_length) {
        toast.error(`${name} ${t('mustBeAtleast')} ${min_length} ${t('charactersLong')}`);
        return false;
      }

      if (!required && extraDetails[id] && type === 'number' && extraDetails[id].length < min_length) {
        toast.error(`${name} ${t('mustBeAtleast')} ${min_length} ${t('digitLong')}`);
        return false;
      }

    }
    return true;
  };

  
  const postAd = async () => {

    const cat = CurrentPath[CurrentPath.length - 1];
    const catId = cat.id;
    const transformedCustomFields = {};
    const customFieldFiles = [];
    Object.entries(extraDetails).forEach(([key, value]) => {
      if (value instanceof File || (Array.isArray(value) && value[0] instanceof File)) {
        customFieldFiles.push({ key, files: value });
      } else {
        transformedCustomFields[key] = Array.isArray(value) ? value : [value];
      }
    });

    const show_only_to_premium = 1;
    const allData = {
      name: AdListingDetails.title,
      slug: AdListingDetails.slug.trim(),
      description: AdListingDetails?.desc,
      category_id: catId,
      all_category_ids: allCategoryIdsString,
      price: AdListingDetails.price,
      contact: AdListingDetails.phonenumber,
      video_link: AdListingDetails?.link,
      custom_fields: transformedCustomFields,
      image: uploadedImages[0],
      gallery_images: OtherImages,
      address: Location?.address,
      latitude: Location?.lat,
      longitude: Location?.long,
      custom_field_files: customFieldFiles,
      show_only_to_premium: show_only_to_premium,
      country: Location?.country,
      state: Location?.state,
      city: Location?.city,
      ...(AreaStore?.SelectedArea?.id ? { area_id: Number(AreaStore.SelectedArea.id) } : {})
    }
    try {
      setIsAdPlaced(true)
      const res = await addItemApi.addItem(allData)
      if (res?.data?.error === false) {
        setIsAdSuccessfulModal(true)
        setCreatedAdSlug(res?.data?.data[0]?.slug)
      }
      else {
        toast.error(res?.data?.message)
      }
    } catch (error) {
      console.error(error)
    } finally {
      setIsAdPlaced(false)
    }
  }

  const handleFullSubmission = () => {

    if (!isLogin()) {
      toast.error(t('loginFirst'))
      return
    }

    const { title, desc, price, phonenumber, slug, link } = AdListingDetails;

    const isValidSlug = /^[a-z0-9-]+$/.test(slug.trim());

    const cat = CurrentPath[CurrentPath.length - 1];
    const catId = cat?.id;

    if (!catId) {
      toast.error(t('selectCategory'))
      return
    }

    if (!title.trim() || !desc.trim() || !price || !phonenumber) {
      toast.error(t('completeDetails'));
      setActiveTab(2);
      return;
    }


    // Additional validation logic (e.g., format checks) can be added here
    if (price < 0) {
      toast.error(t('enterValidPrice'));
      setActiveTab(2);
      return;
    }

    if (slug.trim() && !isValidSlug) {
      toast.error(t('addValidSlug'));
      setActiveTab(2);
      return;
    }

    if (link && !isValidURL(link)) {
      toast.error(t('enterValidUrl'));
      setActiveTab(2);
      return;
    }

    if (CustomFields.length !== 0 && !validateExtraDetails(CustomFields, extraDetails)) {
      setActiveTab(3);
      return;
    }
    if (uploadedImages.length === 0) {
      toast.error(t('uploadMainPicture'));
      setActiveTab(4);
      return
    }

    if (!Location?.country || !Location?.state || !Location?.city || !Location?.address) {
      toast.error(t('pleaseSelectCity'));
      return
    }
 
    postAd()
  }

  const fetchMoreCategory = async (id) => {
    setIsLoadMoreCat(true)
    try {
      if (currentPage < lastPage) {
        const response = await categoryApi.getCategory({ page: `${currentPage + 1}`, category_id: lastItemId });
        const { data } = response.data;
        if (data && Array.isArray(data.data)) {
          setCurrenCategory(prev => [...prev, ...data.data]);
          setCurrentPage(data?.data?.current_page); // Update the current page
          setLastPage(data?.data?.last_page); // Update the current page
        } else {
          console.error("Error: Data is not an array", data);
          // setIsLoading(false);
        }
      } else {
        return
      }
    } catch (error) {
      // setIsLoading(false)
      console.error("Error:", error);
    } finally {
      setIsLoadMoreCat(false)
    }
  }

  const handleTabClick = (tab) => {
    if (tab === 1 && !DisabledTab.selectCategory) {
      setActiveTab(1);
    } else if (tab === 2 && !DisabledTab.details) {
      setActiveTab(2);
    } else if (tab === 3 && !DisabledTab.extraDet) {
      setActiveTab(3);
    } else if (tab === 4 && !DisabledTab.img) {
      setActiveTab(4);
    } else if (tab === 5 && !DisabledTab.loc) {
      setActiveTab(5);
    }
  }

  const handleDeatilsBack = () => {
    setCustomFields([])
    setAdListingDetails({
      title: '',
      slug: '',
      desc: '',
      price: '',
      phonenumber: '',
      link: '',
    })
    if (activeTab !== 1) {
      setActiveTab(1);
      setDisabledTab({
        selectCategory: false,
        details: true,
        extraDet: true,
        img: true,
        loc: true
      });
    }
    if (CurrentPath.length > 0) {
      CurrentPath.pop();
    }
  }

  return (
    <>
      <BreadcrumbComponent title2={t('adListing')} />
      <section className='adListingSect container'>
        <div className="row">
          <div className="col-12">
            <span className='heading'>{t('adListing')}</span>
          </div>
        </div>
        <div className="row tabsWrapper">

          <div className="col-12">
            <div className="tabsHeader">
              <span className={`tab ${activeTab === 1 ? 'activeTab' : ''}${DisabledTab.selectCategory ? 'PagArrowdisabled' : ''}`} onClick={() => handleTabClick(1)}>{t('selectedCategory')}</span>
              <span className={`tab ${activeTab === 2 ? 'activeTab' : ''}${DisabledTab.details ? 'PagArrowdisabled' : ''}`} onClick={() => handleTabClick(2)}>{t('details')}</span>

              {
                CustomFields.length !== 0 &&
                <span className={`tab ${activeTab === 3 ? 'activeTab' : ''}${DisabledTab.extraDet ? 'PagArrowdisabled' : ''}`} onClick={() => handleTabClick(3)}>{t('extraDetails')}</span>
              }


              <span className={`tab ${activeTab === 4 ? 'activeTab' : ''}${DisabledTab.img ? 'PagArrowdisabled' : ''}`} onClick={() => handleTabClick(4)}>{t('images')}</span>
              <span className={`tab ${activeTab === 5 ? 'activeTab' : ''}${DisabledTab.loc ? 'PagArrowdisabled' : ''}`} onClick={() => handleTabClick(5)}>{t('location')}</span>
            </div>
          </div>
          {
            activeTab === 1 || activeTab === 2 ?
              CurrentPath.length > 0 &&
              <div className="col-12">
                <div className="tabBreadcrumb">
                  <span className='title1'>{t('selected')}</span>
                  <div className='selected_wrapper'>
                    {
                      CurrentPath.map((item, index) => (

                        <span className='title2' key={item.id} onClick={() => handleSelectedTabClick(item?.id)}>
                          {item.name}
                          {
                            index !== CurrentPath.length - 1 && CurrentPath.length > 1 ? ',' : ''
                          }
                        </span>
                      ))
                    }
                  </div>
                </div>
              </div> : null
          }
          <div className="col-12">
            <div className="contentWrapper">
              <div className='row'>
                {
                  activeTab === 1 &&
                  <ContentOne handleCategoryTabClick={handleCategoryTabClick} CurrenCategory={CurrenCategory} currentPage={currentPage} lastPage={lastPage} fetchMoreCategory={fetchMoreCategory} IsLoading={IsLoading} IsLoadMoreCat={IsLoadMoreCat} />
                }
                {
                  activeTab === 2 &&
                  <ContentTwo AdListingDetails={AdListingDetails} handleAdListingChange={handleAdListingChange} handleDetailsSubmit={handleDetailsSubmit} handleDeatilsBack={handleDeatilsBack} systemSettingsData={systemSettingsData} />
                }
                {
                  activeTab === 3 && CustomFields.length !== 0 &&
                  <ContentThree CustomFields={CustomFields} extraDetails={extraDetails} setExtraDetails={setExtraDetails} submitExtraDetails={submitExtraDetails} handleGoBack={handleGoBack} filePreviews={filePreviews} setFilePreviews={setFilePreviews} />
                }
                {
                  activeTab === 4 &&
                  <ContentFour setUploadedImages={setUploadedImages} uploadedImages={uploadedImages} OtherImages={OtherImages} setOtherImages={setOtherImages} handleImageSubmit={handleImageSubmit} handleGoBack={handleGoBack} />
                }
                {
                  activeTab === 5 &&
                  <ContentFive getCurrentLocation={getCurrentLocation} handleGoBack={handleGoBack} Location={Location} setLocation={setLocation} handleFullSubmission={handleFullSubmission} getLocationWithMap={getLocationWithMap} Address={Address} setAddress={setAddress} isAdPlaced={isAdPlaced} setCountryStore={setCountryStore} CountryStore={CountryStore} handleCountryScroll={handleCountryScroll} StateStore={StateStore} setStateStore={setStateStore} handleStateScroll={handleStateScroll} CityStore={CityStore} setCityStore={setCityStore} handleCityScroll={handleCityScroll} AreaStore={AreaStore} setAreaStore={setAreaStore} handleAreaScroll={handleAreaScroll} />
                }
              </div>
            </div>
          </div>
        </div>
      </section>
      <AdSuccessfulModal IsAdSuccessfulModal={IsAdSuccessfulModal} OnHide={() => setIsAdSuccessfulModal(false)} CreatedAdSlug={CreatedAdSlug} />
    </>
  )
}

export default withRedirect(AdListing)
