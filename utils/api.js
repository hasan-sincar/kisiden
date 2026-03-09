"use client";
import Api from "@/api/AxiosInterceptors";
export const GET_SETTINGS = "get-system-settings";
export const GET_SEO_SETTINGS = "seo-settings";
export const GET_SLIDER = "get-slider";
export const GET_CATEGORIES = "get-categories";
export const GET_PARENT_CATEGORIES = "get-parent-categories";
export const GET_ITEM = "get-item";
export const GET_PACKAGE = "get-package";
export const GET_BLOGS = "blogs";
export const GET_BLOG_TAGS = "blog-tags";
export const GET_FEATURED_SECTION = "get-featured-section";
export const GET_FAQ = "faq";
export const GET_COUNTRIES = "countries";
export const GET_STATES = "states";
export const GET_CITIES = "cities";
export const GET_AREA = "areas";
export const GET_LANGUAGE = "get-languages";
export const GET_CUSTOM_FIELDS = "get-customfields";
export const MANAGE_FAVOURITE = "manage-favourite";
export const GET_FAVOURITE_ITEMS = "get-favourite-item";
export const GET_MY_ITEMS = "my-items";
export const GET_LIMITS = "get-limits";
export const DELETE_ITEM = "delete-item";
export const UPDATE_ITEM_STATUS = "update-item-status";
export const CREATE_FEATURED_ITEM = "make-item-featured";
export const CONTACT_US = "contact-us";
export const UPDATE_LISTING = "update-item";
export const USER_SIGNUP = "user-signup";
export const USER_EXISTS = "user-exists";
export const UPDATE_PROFILE = "update-profile";
export const DELETE_USER = "delete-user";
export const GET_REPORT_REASONS = "get-report-reasons";
export const ADD_REPORT = "add-reports";
export const GET_NOTIFICATION_LIST = "get-notification-list";
export const CHAT_LIST = "chat-list";
export const CHAT_MESSAGES = "chat-messages";
export const SEND_MESSAGE = "send-message";
export const BLOCK_USER = "block-user";
export const UNBLOCK_USER = "unblock-user";
export const BLOCKED_USERS = "blocked-users";
export const ASSIGN_FREE_PACKAGE = "assign-free-package";
export const GET_PAYMENT_SETTINGS = "get-payment-settings";
export const PAYMENT_INTENT = "payment-intent";
export const PAYMENT_TRANSACTIONS = "payment-transactions";
export const TIPS = "tips";
export const ITEM_OFFER = "item-offer";
export const ADD_ITEM = "add-item";
export const GET_SELLER = "get-seller";
export const ITEM_BUYER_LIST = "item-buyer-list";
export const AD_ITEM_REVIEW = "add-item-review";
export const GET_VERIFICATION_FIELDS = "verification-fields";
export const SEND_VERIFICATION_REQUEST = "send-verification-request";
export const GET_VERIFICATION_STATUS = "verification-request";
export const MY_REVIEWS = "my-review";
export const RENEW_ITEM = "renew-item";
export const ADD_REPORT_REVIEW = "add-review-report";
export const BANK_TRANSFER_UPDATE = "bank-transfer-update";
export const JOB_APPLY = "job-apply";
export const MY_JOB_APPLICATIONS = "my-job-applications";
export const GET_JOB_APPLICATIONS = "get-job-applications";
export const UPDATE_JOB_STATUS = "update-job-applications-status";
export const GET_OTP = "get-otp";
export const VERIFY_OTP = "verify-otp";
export const GET_LOCATION = "get-location";
export const GET_USER_INFO = "get-user-info";
export const LOGOUT = "logout";
export const SET_ITEM_TOTAL_CLICK = "set-item-total-click";
export const RESET_PASSWORD = "reset-password";
export const GET_CURRENCIES = "get-currencies";

// 1. SETTINGS API
export const settingsApi = {
  getSettings: ({ type } = {}) => {
    return Api.get(GET_SETTINGS, {
      params: { type },
    });
  },
};

// 2. SLIDER API
export const sliderApi = {
  getSlider: ({ country, state, city } = {}) => {
    return Api.get(GET_SLIDER, { params: { country, state, city } });
  },
};

// 3. CATEGORY API
export const categoryApi = {
  getCategory: ({ category_id, page, listing } = {}) => {
    return Api.get(GET_CATEGORIES, {
      params: { category_id, page, listing },
    });
  },
};
// 3. MY ITEMS API
export const getMyItemsApi = {
  getMyItems: ({ sort_by, page, status, id, category_id, slug } = {}) => {
    return Api.get(GET_MY_ITEMS, {
      params: { page, sort_by, status, id, category_id, slug },
    });
  },
};
export const getLimitsApi = {
  getLimits: ({ package_type } = {}) => {
    return Api.get(GET_LIMITS, {
      params: { package_type },
    });
  },
};
export const getSellerApi = {
  getSeller: ({ id, page } = {}) => {
    return Api.get(GET_SELLER, {
      params: { id, page },
    });
  },
};
export const getVerificationStatusApi = {
  getVerificationStatus: () => {
    return Api.get(GET_VERIFICATION_STATUS, {});
  },
};
export const getItemBuyerListApi = {
  getItemBuyerList: ({ item_id } = {}) => {
    return Api.get(ITEM_BUYER_LIST, {
      params: { item_id },
    });
  },
};
export const getVerificationFiledsApi = {
  getVerificationFileds: () => {
    return Api.get(GET_VERIFICATION_FIELDS, {});
  },
};

// 4. ITEM API
export const allItemApi = {
  getItems: ({
    id,
    custom_fields,
    category_id,
    min_price,
    max_price,
    sort_by,
    posted_since,
    featured_section_id,
    status,
    page,
    search,
    country,
    state,
    city,
    slug,
    category_slug,
    featured_section_slug,
    area_id,
    latitude,
    longitude,
    radius,
    user_id,
    popular_items,
    limit,
    current_page,
  } = {}) => {
    return Api.get(GET_ITEM, {
      params: {
        id,
        custom_fields,
        category_id,
        min_price,
        max_price,
        sort_by,
        posted_since,
        featured_section_id,
        status,
        page,
        search,
        country,
        state,
        city,
        slug,
        category_slug,
        featured_section_slug,
        area_id,
        latitude,
        longitude,
        radius,
        user_id,
        popular_items,
        limit,
        current_page,
      },
    });
  },
};

// PACKAGE API

export const getPackageApi = {
  getPackage: ({ type } = {}) => {
    return Api.get(GET_PACKAGE, {
      params: {
        type,
      },
    });
  },
};

// BLOGS API
export const getBlogsApi = {
  getBlogs: ({ slug, category_id, sort_by, tag, page, views } = {}) => {
    return Api.get(GET_BLOGS, {
      params: {
        slug,
        category_id,
        sort_by,
        tag,
        page,
        views,
      },
    });
  },
};
// BLOGS API
export const getBlogTagsApi = {
  getBlogs: ({ } = {}) => {
    return Api.get(GET_BLOG_TAGS, {
      params: {},
    });
  },
};
export const getMyReviewsApi = {
  getMyReviews: ({ page } = {}) => {
    return Api.get(MY_REVIEWS, {
      params: {
        page,
      },
    });
  },
};

// 5. GET_FEATURED_SECTION
export const FeaturedSectionApi = {
  getFeaturedSections: ({
    city,
    state,
    country,
    slug,
    latitude,
    longitude,
    radius,
    area_id,
  } = {}) => {
    return Api.get(GET_FEATURED_SECTION, {
      params: {
        city,
        state,
        country,
        slug,
        latitude,
        longitude,
        radius,
        area_id,
      },
    });
  },
};
// FAQ API

export const getFaqApi = {
  getFaq: () => {
    return Api.get(GET_FAQ, {
      params: {},
    });
  },
};

// COUNTRY API

export const getCoutriesApi = {
  getCoutries: ({ search, page } = {}) => {
    return Api.get(GET_COUNTRIES, {
      params: {
        search,
        page,
      },
    });
  },
};

// STATES API

export const getStatesApi = {
  getStates: ({ country_id, search, page } = {}) => {
    return Api.get(GET_STATES, {
      params: {
        country_id,
        search,
        page,
      },
    });
  },
};

// CITIES API

export const getCitiesApi = {
  getCities: ({ state_id, search, page } = {}) => {
    return Api.get(GET_CITIES, {
      params: {
        state_id,
        search,
        page,
      },
    });
  },
};
export const getAreasApi = {
  getAreas: ({ city_id, search, page } = {}) => {
    return Api.get(GET_AREA, {
      params: {
        city_id,
        search,
        page,
      },
    });
  },
};

// language api

export const getLanguageApi = {
  getLanguage: ({ language_code, type } = {}) => {
    return Api.get(GET_LANGUAGE, {
      params: {
        language_code,
        type,
      },
    });
  },
};

export const userSignUpApi = {
  userSignup: ({
    password,
    name,
    email,
    mobile,
    fcm_id,
    firebase_id,
    type,
    profile,
    country_code,
    registration,
    region_code,
    is_login,
  } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (name) formData.append("name", name);
    if (email) formData.append("email", email);
    if (mobile) formData.append("mobile", mobile);
    if (fcm_id) formData.append("fcm_id", fcm_id);
    if (firebase_id) formData.append("firebase_id", firebase_id);
    if (type) formData.append("type", type);
    if (region_code) formData.append("region_code", region_code);

    // Assuming `profile` is a file object. If it's a URL or other type, handle accordingly.
    if (profile) {
      formData.append("profile", profile);
    }
    if (country_code) formData.append("country_code", country_code);
    if (registration) formData.append("registration", registration);
    if (is_login) formData.append("is_login", is_login);
    if (password) formData.append("password", password);

    return Api.post(USER_SIGNUP, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
export const logoutApi = {
  logoutApi: ({ fcm_token } = {}) => {
    const formData = new FormData();
    if (fcm_token) formData.append("fcm_token", fcm_token);
    return Api.post(LOGOUT, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const sendVerificationReqApi = {
  sendVerificationReq: ({
    verification_field_translations,
    verification_field_files,
  } = {}) => {
    const formData = new FormData();

    if (verification_field_translations)
      formData.append(
        "verification_field_translations",
        verification_field_translations
      );

    verification_field_files.forEach(({ key, files }) => {
      const file = Array.isArray(files) ? files[0] : files;
      if (file) {
        formData.append(`verification_field_files[${key}]`, file);
      }
    });

    return Api.post(SEND_VERIFICATION_REQUEST, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
export const updateProfileApi = {
  updateProfile: ({
    name,
    email,
    mobile,
    fcm_id,
    address,
    profile,
    notification,
    show_personal_details,
    country_code,
    region_code,
  } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (name) formData.append("name", name);
    if (email) formData.append("email", email);
    formData.append("mobile", mobile);
    if (fcm_id) formData.append("fcm_id", fcm_id);
    if (address) formData.append("address", address);
    if (country_code) formData.append("country_code", country_code);

    // Assuming `profile` is a file object. If it's a URL or other type, handle accordingly.
    if (profile) {
      formData.append("profile", profile);
    }
    formData.append("notification", notification);
    formData.append("show_personal_details", show_personal_details);
    formData.append("region_code", region_code);

    return Api.post(UPDATE_PROFILE, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

// GET NOTIFICATION API

export const getNotificationList = {
  getNotification: ({ page } = {}) => {
    return Api.get(GET_NOTIFICATION_LIST, {
      params: {
        page: page,
      },
    });
  },
};

// ASSIGN FREE PACKAGE
export const assigFreePackageApi = {
  assignFreePackage: ({ package_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (package_id) formData.append("package_id", package_id);

    return Api.post(ASSIGN_FREE_PACKAGE, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const addItemReviewApi = {
  addItemReview: ({ review, ratings, item_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (review) formData.append("review", review);
    if (ratings) formData.append("ratings", ratings);
    if (item_id) formData.append("item_id", item_id);

    return Api.post(AD_ITEM_REVIEW, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
export const renewItemApi = {
  renewItem: ({ item_ids, package_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_ids) formData.append("item_ids", item_ids);
    if (package_id) formData.append("package_id", package_id);

    return Api.post(RENEW_ITEM, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

// DELETE ITEM API

export const deleteItemApi = {
  deleteItem: ({ item_id, item_ids } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);
    if (item_ids) formData.append("item_ids", item_ids);
    return Api.post(DELETE_ITEM, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const chanegItemStatusApi = {
  changeItemStatus: ({ item_id, status, sold_to } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);
    if (status) formData.append("status", status);
    if (sold_to) formData.append("sold_to", sold_to);

    return Api.post(UPDATE_ITEM_STATUS, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
export const createFeaturedItemApi = {
  createFeaturedItem: ({ item_id, positions } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);
    if (positions) formData.append("positions", positions);

    return Api.post(CREATE_FEATURED_ITEM, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
// getPackageSettingsApi
export const getPaymentSettingsApi = {
  getPaymentSettings: () => {
    return Api.get(GET_PAYMENT_SETTINGS, {
      params: {},
    });
  },
};
// createPaymentIntentApi
export const createPaymentIntentApi = {
  createIntent: ({ package_id, payment_method, platform_type } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (package_id) formData.append("package_id", package_id);
    if (payment_method) formData.append("payment_method", payment_method);
    if (platform_type) formData.append("platform_type", platform_type);

    return Api.post(PAYMENT_INTENT, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
// deleteUserApi
export const deleteUserApi = {
  deleteUser: () => {
    return Api.delete(DELETE_USER, {
      params: {},
    });
  },
};
// paymentTransactionApi
export const paymentTransactionApi = {
  transaction: ({ page }) => {
    return Api.get(PAYMENT_TRANSACTIONS, {
      params: {
        page: page,
      },
    });
  },
};

// custom field api

export const getCustomFieldsApi = {
  getCustomFields: ({ category_ids, filter } = {}) => {
    return Api.get(GET_CUSTOM_FIELDS, {
      params: {
        category_ids,
        ...(filter !== undefined ? { filter } : {}),
      },
    });
  },
};

export const tipsApi = {
  tips: ({ } = {}) => {
    return Api.get(TIPS, {
      params: {},
    });
  },
};

export const itemOfferApi = {
  offer: ({ item_id, amount } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);
    if (amount) formData.append("amount", amount);

    return Api.post(ITEM_OFFER, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const chatListApi = {
  chatList: ({ type, page } = {}) => {
    return Api.get(CHAT_LIST, {
      params: {
        type,
        page,
      },
    });
  },
};

export const getMessagesApi = {
  chatMessages: ({ item_offer_id, page } = {}) => {
    return Api.get(CHAT_MESSAGES, {
      params: {
        item_offer_id,
        page,
      },
    });
  },
};
// add item api

export const addItemApi = {
  addItem: ({
    name,
    slug,
    description,
    category_id,
    all_category_ids,
    price,
    contact,
    video_link,
    custom_fields,
    image,
    gallery_images = [],
    address,
    latitude,
    longitude,
    custom_field_files = [],
    area_id,
    country,
    state,
    city,
    min_salary,
    max_salary,
    translations,
    custom_field_translations,
    region_code,
    currency_id
  } = {}) => {
    const formData = new FormData();
    // Append only if the value is defined and not an empty string

    if (name) formData.append("name", name);
    if (slug) formData.append("slug", slug);
    if (description) formData.append("description", description);
    if (category_id) formData.append("category_id", category_id);
    if (all_category_ids) formData.append("all_category_ids", all_category_ids);
    if (price) formData.append("price", price);
    if (contact) formData.append("contact", contact);
    if (video_link) formData.append("video_link", video_link);

    if (custom_fields)
      formData.append("custom_fields", JSON.stringify(custom_fields));

    if (image) formData.append("image", image);
    if (gallery_images.length > 0) {
      gallery_images.forEach((gallery_image, index) => {
        formData.append(`gallery_images[${index}]`, gallery_image);
      });
    }
    if (address) formData.append("address", address);
    if (latitude) formData.append("latitude", latitude);
    if (longitude) formData.append("longitude", longitude);

    // Append custom field files
    custom_field_files.forEach(({ key, files }) => {
      if (Array.isArray(files)) {
        files.forEach((file, index) =>
          formData.append(`custom_field_files[${key}]`, file)
        );
      } else {
        formData.append(`custom_field_files[${key}]`, files);
      }
    });

    if (country) formData.append("country", country);
    if (state) formData.append("state", state);
    if (city) formData.append("city", city);
    if (area_id) formData.append("area_id", area_id);
    if (min_salary) formData.append("min_salary", min_salary);
    if (max_salary) formData.append("max_salary", max_salary);
    if (region_code) formData.append("region_code", region_code);
    if (currency_id) formData.append("currency_id", currency_id);

    if (custom_field_translations)
      formData.append("custom_field_translations", custom_field_translations);

    if (translations) formData.append("translations", translations);

    return Api.post(ADD_ITEM, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

// Edit item API
export const editItemApi = {
  editItem: ({
    id,
    name,
    slug,
    description,
    category_id,
    all_category_ids,
    price,
    contact,
    video_link,
    custom_fields,
    image,
    gallery_images = [],
    address,
    latitude,
    longitude,
    custom_field_files = [],
    area_id,
    country,
    state,
    city,
    delete_item_image_id,
    min_salary,
    max_salary,
    translations,
    custom_field_translations,
    region_code,
    currency_id
    // expiry_date,
  } = {}) => {
    const formData = new FormData();
    // Append only if the value is defined and not an empty string
    if (id) formData.append("id", id);
    if (name) formData.append("name", name);
    if (slug) formData.append("slug", slug);
    if (description) formData.append("description", description);
    if (category_id) formData.append("category_id", category_id);
    if (all_category_ids) formData.append("all_category_ids", all_category_ids);
    if (price) formData.append("price", price);
    if (delete_item_image_id)
      formData.append("delete_item_image_id", delete_item_image_id);
    if (contact) formData.append("contact", contact);
    if (video_link) formData.append("video_link", video_link);
    if (latitude) formData.append("latitude", latitude);
    if (longitude) formData.append("longitude", longitude);
    if (custom_fields)
      formData.append("custom_fields", JSON.stringify(custom_fields));
    if (address) formData.append("address", address);
    formData.append("contact", contact);
    if (country) formData.append("country", country);
    if (state) formData.append("state", state);
    // if (custom_field_files) formData.append("custom_field_files", custom_field_files)
    if (area_id) formData.append("area_id", area_id);
    if (city) formData.append("city", city);
    if (currency_id) formData.append("currency_id", currency_id);
    if (image != null) formData.append("image", image);
    if (gallery_images.length > 0) {
      gallery_images.forEach((gallery_image, index) => {
        formData.append(`gallery_images[${index}]`, gallery_image);
      });
    }
    if (region_code) formData.append("region_code", region_code);

    formData.append("min_salary", min_salary);
    formData.append("max_salary", max_salary);
    // if (expiry_date) formData.append("expiry_date", expiry_date);

    custom_field_files.forEach(({ key, files }) => {
      if (Array.isArray(files)) {
        files.forEach((file, index) =>
          formData.append(`custom_field_files[${key}]`, file)
        );
      } else {
        formData.append(`custom_field_files[${key}]`, files);
      }
    });

    if (custom_field_translations)
      formData.append("custom_field_translations", custom_field_translations);

    if (translations) formData.append("translations", translations);
    return Api.post(UPDATE_LISTING, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const sendMessageApi = {
  sendMessage: ({ item_offer_id, message, file, audio } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_offer_id) formData.append("item_offer_id", item_offer_id);
    if (message) formData.append("message", message);
    if (file) formData.append("file", file);
    if (audio) formData.append("audio", audio);

    return Api.post(SEND_MESSAGE, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

// favorite API
export const manageFavouriteApi = {
  manageFavouriteApi: ({ item_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);

    return Api.post(MANAGE_FAVOURITE, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const getFavouriteApi = {
  getFavouriteApi: ({ page } = {}) => {
    return Api.get(GET_FAVOURITE_ITEMS, {
      params: {
        page,
      },
    });
  },
};

export const getReportReasonsApi = {
  reportReasons: ({ } = {}) => {
    return Api.get(GET_REPORT_REASONS, {
      params: {},
    });
  },
};

export const addReportReasonApi = {
  addReport: ({ item_id, report_reason_id, other_message } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);
    if (report_reason_id) formData.append("report_reason_id", report_reason_id);
    if (other_message) formData.append("other_message", other_message);

    return Api.post(ADD_REPORT, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
export const addReportReviewApi = {
  addReportReview: ({ seller_review_id, report_reason } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (seller_review_id) formData.append("seller_review_id", seller_review_id);
    if (report_reason) formData.append("report_reason", report_reason);

    return Api.post(ADD_REPORT_REVIEW, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const blockUserApi = {
  blockUser: ({ blocked_user_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (blocked_user_id) formData.append("blocked_user_id", blocked_user_id);

    return Api.post(BLOCK_USER, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
export const unBlockUserApi = {
  unBlockUser: ({ blocked_user_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (blocked_user_id) formData.append("blocked_user_id", blocked_user_id);

    return Api.post(UNBLOCK_USER, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const getBlockedUsers = {
  blockedUsers: ({ } = {}) => {
    return Api.get(BLOCKED_USERS, {
      params: {},
    });
  },
};

export const contactUsApi = {
  contactUs: ({ name, email, subject, message } = {}) => {
    const formData = new FormData();
    // Append only if the value is defined and not an empty string
    if (name) formData.append("name", name);
    if (email) formData.append("email", email);
    if (subject) formData.append("subject", subject);
    if (message) formData.append("message", message);
    return Api.post(CONTACT_US, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};
// get parent cate api
export const getParentCategoriesApi = {
  getPaymentCategories: ({ child_category_id, tree, slug } = {}) => {
    return Api.get(GET_PARENT_CATEGORIES, {
      params: {
        child_category_id,
        tree,
        slug,
      },
    });
  },
};

export const updateBankTransferApi = {
  updateBankTransfer: ({ payment_transection_id, payment_receipt } = {}) => {
    const formData = new FormData();
    if (payment_transection_id)
      formData.append("payment_transection_id", payment_transection_id);
    if (payment_receipt) formData.append("payment_receipt", payment_receipt);

    return Api.post(BANK_TRANSFER_UPDATE, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const jobApplyApi = {
  jobApply: ({ item_id, full_name, email, mobile, resume } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);
    if (full_name) formData.append("full_name", full_name);
    if (email) formData.append("email", email);
    if (mobile) formData.append("mobile", mobile);
    if (resume) formData.append("resume", resume);

    return Api.post(JOB_APPLY, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const getMyJobApplicationsList = {
  getMyJobApplications: ({ page } = {}) => {
    return Api.get(MY_JOB_APPLICATIONS, {
      params: {
        page: page,
      },
    });
  },
};

export const getAdJobApplicationsApi = {
  getAdJobApplications: ({ page, item_id } = {}) => {
    return Api.get(GET_JOB_APPLICATIONS, {
      params: {
        page: page,
        item_id: item_id,
      },
    });
  },
};

export const updateJobStatusApi = {
  updateJobStatus: ({ job_id, status } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (job_id) formData.append("job_id", job_id);
    if (status) formData.append("status", status);

    return Api.post(UPDATE_JOB_STATUS, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};

export const verifyOtpApi = {
  verifyOtp: ({ number, otp, country_code, password } = {}) => {
    return Api.get(VERIFY_OTP, {
      params: {
        number: number,
        country_code: country_code,
        otp: otp,
        password: password
      },
    });
  },
};
export const getOtpApi = {
  getOtp: ({ number, country_code } = {}) => {
    return Api.get(GET_OTP, {
      params: {
        number: number,
        country_code: country_code
      },
    });
  },
};

export const getLocationApi = {
  getLocation: ({ lat, lng, lang, search, place_id, session_id } = {}) => {
    return Api.get(GET_LOCATION, {
      params: { lat, lng, lang, search, place_id, session_id },
    });
  },
};

export const getUserInfoApi = {
  getUserInfo: () => {
    return Api.get(GET_USER_INFO);
  },
};

export const getCurrenciesApi = {
  getCurrencies: ({ country } = {}) => {
    return Api.get(GET_CURRENCIES, {
      params: {
        country: country,
      },
    });
  },
};
export const getUserExistsApi = {
  getUserExists: ({ mobile, country_code, forgot_password } = {}) => {
    return Api.get(USER_EXISTS, {
      params: {
        mobile: mobile,
        country_code: country_code,
        forgot_password: forgot_password
      },
    });
  },
};

export const setItemTotalClickApi = {
  setItemTotalClick: ({ item_id } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (item_id) formData.append("item_id", item_id);

    return Api.post(SET_ITEM_TOTAL_CLICK, formData, {
      headers: {
        "Content-Type": "multipart/form-data",
      },
    });
  },
};


export const resetPasswordApi = {
  resetPassword: ({ number, country_code, new_password, token } = {}) => {
    const formData = new FormData();

    // Append only if the value is defined and not an empty string
    if (number) formData.append("number", number);
    if (country_code) formData.append("country_code", country_code);
    if (new_password) formData.append("new_password", new_password);

    // Prepare headers
    const headers = {
      "Content-Type": "multipart/form-data",
    };

    // Add authorization header if token is provided
    if (token) {
      headers.authorization = `Bearer ${token}`;
    }

    return Api.post(RESET_PASSWORD, formData, {
      headers
    });
  },
};


export const getSeoSettingsApi = {
  getSeoSettings: ({ page } = {}) => {
    return Api.get(GET_SEO_SETTINGS, {
      params: {
        page,
      },
    });
  },
};