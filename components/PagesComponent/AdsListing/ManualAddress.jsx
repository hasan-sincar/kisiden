import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
} from "@/components/ui/command";
import { useInView } from "react-intersection-observer";
import { Check, ChevronsUpDown, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import {
  getAreasApi,
  getCitiesApi,
  getCoutriesApi,
  getStatesApi,
} from "@/utils/api";
import { Textarea } from "@/components/ui/textarea";
import { t } from "@/utils";

const ManualAddress = ({
  showManualAddress,
  setShowManualAddress,
  setLocation,
}) => {
  const [CountryStore, setCountryStore] = useState({
    Countries: [],
    SelectedCountry: {},
    CountrySearch: "",
    currentPage: 1,
    hasMore: false,
    countryOpen: false,
    isLoading: false,
  });
  const [StateStore, setStateStore] = useState({
    States: [],
    SelectedState: {},
    StateSearch: "",
    currentPage: 1,
    hasMore: false,
    stateOpen: false,
    isLoading: false,
  });
  const [CityStore, setCityStore] = useState({
    Cities: [],
    SelectedCity: {},
    CitySearch: "",
    currentPage: 1,
    hasMore: false,
    isLoading: false,
    cityOpen: false,
  });
  const [AreaStore, setAreaStore] = useState({
    Areas: [],
    SelectedArea: {},
    AreaSearch: "",
    currentPage: 1,
    hasMore: false,
    areaOpen: false,
    isLoading: false,
  });
  const [Address, setAddress] = useState("");
  const [fieldErrors, setFieldErrors] = useState({});
  const isCountrySelected =
    Object.keys(CountryStore?.SelectedCountry).length > 0;
  // Check if areas exist for the selected city
  const hasAreas = AreaStore?.Areas.length > 0;
  // Infinite scroll refs
  const { ref: stateRef, inView: stateInView } = useInView();
  const { ref: countryRef, inView: countryInView } = useInView();
  const { ref: cityRef, inView: cityInView } = useInView();
  const { ref: areaRef, inView: areaInView } = useInView();

  const getCountriesData = async (search, page) => {
    try {
      setCountryStore((prev) => ({
        ...prev,
        isLoading: true,
        Countries: search ? [] : prev.Countries, // Clear list if searching
      }));
      // Fetch countries
      const params = {};
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getCoutriesApi.getCoutries(params);
      let allCountries;
      if (page > 1) {
        allCountries = [...CountryStore?.Countries, ...res?.data?.data?.data];
      } else {
        allCountries = res?.data?.data?.data;
      }
      setCountryStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Countries: allCountries,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Error fetching countries data:", error);
      setCountryStore((prev) => ({ ...prev, isLoading: false }));
    }
  };
  const getStatesData = async (search, page) => {
    try {
      setStateStore((prev) => ({
        ...prev,
        isLoading: true,
        States: search ? [] : prev.States,
      }));
      const params = {
        country_id: CountryStore?.SelectedCountry?.id,
      };
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getStatesApi.getStates(params);

      let allStates;
      if (page > 1) {
        allStates = [...StateStore?.States, ...res?.data?.data?.data];
      } else {
        allStates = res?.data?.data?.data;
      }

      setStateStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        States: allStates,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Error fetching states data:", error);
      setStateStore((prev) => ({ ...prev, isLoading: false }));
      return [];
    }
  };
  const getCitiesData = async (search, page) => {
    try {
      setCityStore((prev) => ({
        ...prev,
        isLoading: true,
        Cities: search ? [] : prev.Cities,
      }));
      const params = {
        state_id: StateStore?.SelectedState?.id,
      };
      if (search) {
        params.search = search; // Send only 'search' if provided
      } else {
        params.page = page; // Send only 'page' if no search
      }

      const res = await getCitiesApi.getCities(params);
      let allCities;
      if (page > 1) {
        allCities = [...CityStore?.Cities, ...res?.data?.data?.data];
      } else {
        allCities = res?.data?.data?.data;
      }
      setCityStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Cities: allCities,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Error fetching cities data:", error);
      setCityStore((prev) => ({ ...prev, isLoading: false }));
      return [];
    }
  };
  const getAreaData = async (search, page) => {
    try {
      setAreaStore((prev) => ({
        ...prev,
        isLoading: true,
        Areas: search ? [] : prev.Areas,
      }));
      const params = {
        city_id: CityStore?.SelectedCity?.id,
      };
      if (search) {
        params.search = search;
      } else {
        params.page = page;
      }
      const res = await getAreasApi.getAreas(params);
      let allArea;
      if (page > 1) {
        allArea = [...AreaStore?.Areas, ...res?.data?.data?.data];
      } else {
        allArea = res?.data?.data?.data;
      }
      setAreaStore((prev) => ({
        ...prev,
        currentPage: res?.data?.data?.current_page,
        Areas: allArea,
        hasMore:
          res?.data?.data?.current_page < res?.data?.data?.last_page
            ? true
            : false,
        isLoading: false,
      }));
    } catch (error) {
      console.error("Error fetching areas data:", error);
      setAreaStore((prev) => ({ ...prev, isLoading: false }));
      return [];
    }
  };
  useEffect(() => {
    const timeout = setTimeout(() => {
      if (showManualAddress) {
        getCountriesData(CountryStore?.CountrySearch, 1);
      }
    }, 500);
    return () => {
      clearTimeout(timeout);
    };
  }, [CountryStore?.CountrySearch, showManualAddress]);
  useEffect(() => {
    if (CountryStore?.SelectedCountry?.id) {
      const timeout = setTimeout(() => {
        getStatesData(StateStore?.StateSearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [CountryStore?.SelectedCountry?.id, StateStore?.StateSearch]);
  useEffect(() => {
    if (StateStore?.SelectedState?.id) {
      const timeout = setTimeout(() => {
        getCitiesData(CityStore?.CitySearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [StateStore?.SelectedState?.id, CityStore?.CitySearch]);
  useEffect(() => {
    if (CityStore?.SelectedCity?.id) {
      const timeout = setTimeout(() => {
        getAreaData(AreaStore?.AreaSearch, 1);
      }, 500);
      return () => {
        clearTimeout(timeout);
      };
    }
  }, [CityStore?.SelectedCity?.id, AreaStore?.AreaSearch]);

  // Trigger infinite scroll when refs come into view
  useEffect(() => {
    if (CountryStore?.hasMore && !CountryStore?.isLoading && countryInView) {
      getCountriesData("", CountryStore?.currentPage + 1);
    }
  }, [
    countryInView,
    CountryStore?.hasMore,
    CountryStore?.isLoading,
    CountryStore?.currentPage,
  ]);

  useEffect(() => {
    if (StateStore?.hasMore && !StateStore?.isLoading && stateInView) {
      getStatesData("", StateStore?.currentPage + 1);
    }
  }, [
    stateInView,
    StateStore?.hasMore,
    StateStore?.isLoading,
    StateStore?.currentPage,
  ]);

  useEffect(() => {
    if (CityStore?.hasMore && !CityStore?.isLoading && cityInView) {
      getCitiesData("", CityStore?.currentPage + 1);
    }
  }, [
    cityInView,
    CityStore?.hasMore,
    CityStore?.isLoading,
    CityStore?.currentPage,
  ]);

  useEffect(() => {
    if (AreaStore?.hasMore && !AreaStore?.isLoading && areaInView) {
      getAreaData("", AreaStore?.currentPage + 1);
    }
  }, [
    areaInView,
    AreaStore?.hasMore,
    AreaStore?.isLoading,
    AreaStore?.currentPage,
  ]);

  const validateFields = () => {
    const errors = {};
    if (!CountryStore?.SelectedCountry?.name) errors.country = true;
    if (!StateStore?.SelectedState?.name) errors.state = true;
    if (!CityStore?.SelectedCity?.name) errors.city = true;
    if (!AreaStore?.SelectedArea?.name && !Address.trim())
      errors.address = true;
    return errors;
  };

  const handleCountryChange = (value) => {
    const Country = CountryStore?.Countries.find(
      (country) => country.name === value
    );
    setCountryStore((prev) => ({
      ...prev,
      SelectedCountry: Country,
      countryOpen: false,
    }));
    setStateStore({
      States: [],
      SelectedState: {},
      StateSearch: "",
      currentPage: 1,
      hasMore: false,
      stateOpen: false,
    });
    setCityStore({
      Cities: [],
      SelectedCity: {},
      CitySearch: "",
      currentPage: 1,
      hasMore: false,
      cityOpen: false,
    });
    setAreaStore({
      Areas: [],
      SelectedArea: {},
      AreaSearch: "",
      currentPage: 1,
      hasMore: false,
      areaOpen: false,
    });
    setAddress("");
  };
  const handleStateChange = (value) => {
    const State = StateStore?.States.find((state) => state.name === value);
    setStateStore((prev) => ({
      ...prev,
      SelectedState: State,
      stateOpen: false,
    }));
    setCityStore({
      Cities: [],
      SelectedCity: {},
      CitySearch: "",
      currentPage: 1,
      hasMore: false,
      cityOpen: false,
    });
    setAreaStore({
      Areas: [],
      SelectedArea: {},
      AreaSearch: "",
      currentPage: 1,
      hasMore: false,
      areaOpen: false,
    });
    setAddress("");
  };
  const handleCityChange = (value) => {
    const City = CityStore?.Cities.find((city) => city.name === value);
    setCityStore((prev) => ({
      ...prev,
      SelectedCity: City,
      cityOpen: false,
    }));
    setAreaStore({
      Areas: [],
      SelectedArea: {},
      AreaSearch: "",
      currentPage: 1,
      hasMore: false,
      areaOpen: false,
    });
    setAddress("");
  };
  const handleAreaChange = (value) => {
    const chosenArea = AreaStore?.Areas.find((item) => item.name === value);
    setAreaStore((prev) => ({
      ...prev,
      SelectedArea: chosenArea,
      areaOpen: false,
    }));
  };

  const handleSave = () => {
    const errors = validateFields();
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) return;

    // Build address parts array and filter out empty values

    const addressParts = [];
    const addressPartsTranslated = [];

    if (hasAreas && AreaStore?.SelectedArea?.name) {
      addressParts.push(AreaStore.SelectedArea.name);
      addressPartsTranslated.push(
        AreaStore.SelectedArea.translated_name || AreaStore.SelectedArea.name
      );
    } else if (Address.trim()) {
      addressParts.push(Address.trim());
      addressPartsTranslated.push(Address.trim());
    }
    if (CityStore?.SelectedCity?.name) {
      addressParts.push(CityStore.SelectedCity.name);
      addressPartsTranslated.push(
        CityStore.SelectedCity.translated_name || CityStore.SelectedCity.name
      );
    }
    if (StateStore?.SelectedState?.name) {
      addressParts.push(StateStore.SelectedState.name);
      addressPartsTranslated.push(
        StateStore.SelectedState.translated_name ||
        StateStore.SelectedState.name
      );
    }
    if (CountryStore?.SelectedCountry?.name) {
      addressParts.push(CountryStore.SelectedCountry.name);
      addressPartsTranslated.push(
        CountryStore.SelectedCountry.translated_name ||
        CountryStore.SelectedCountry.name
      );
    }

    const formattedAddress = addressParts.join(", ");
    const formattedAddressTranslated = addressPartsTranslated.join(", ");

    const locationData = {
      country: CountryStore?.SelectedCountry?.name || "",
      state: StateStore?.SelectedState?.name || "",
      city: CityStore?.SelectedCity?.name || "",
      formattedAddress: formattedAddress,
      address_translated: formattedAddressTranslated,
      lat: CityStore?.SelectedCity?.latitude || null,
      long: CityStore?.SelectedCity?.longitude || null,
      area_id: AreaStore?.SelectedArea?.id || null,
    };
    setLocation(locationData);
    setShowManualAddress(false);
  };

  return (
    <Dialog open={showManualAddress} onOpenChange={setShowManualAddress}>
      <DialogContent className="">
        <DialogHeader>
          <DialogTitle>{t("manuAddAddress")}</DialogTitle>
        </DialogHeader>
        <div className="flex flex-col gap-4 py-4">
          <div className="flex flex-col gap-1">
            <Popover
              modal
              open={CountryStore?.countryOpen}
              onOpenChange={(isOpen) =>
                setCountryStore((prev) => ({ ...prev, countryOpen: isOpen }))
              }
            >
              <PopoverTrigger asChild>
                <Button
                  variant="outline"
                  role="combobox"
                  aria-expanded={CountryStore?.countryOpen}
                  className={`w-full justify-between outline-none ${fieldErrors.country ? "border-red-500" : ""
                    }`}
                >
                  {CountryStore?.SelectedCountry?.translated_name ||
                    CountryStore?.SelectedCountry?.name ||
                    t("country")}
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
              </PopoverTrigger>
              {fieldErrors.country && (
                <span className="text-red-500 text-sm">
                  {t("countryRequired")}
                </span>
              )}
              <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0">
                <Command shouldFilter={false}>
                  <CommandInput
                    placeholder={t("searchCountries")}
                    value={CountryStore.CountrySearch || ""}
                    onValueChange={(val) => {
                      setCountryStore((prev) => ({
                        ...prev,
                        CountrySearch: val,
                      }));
                    }}
                  />
                  <CommandEmpty>
                    {CountryStore.isLoading ? (
                      <LoacationLoader />
                    ) : (
                      <div className="text-center">
                        <p className="text-sm text-muted-foreground">
                          {t("noCountriesFound")}
                        </p>
                      </div>
                    )}
                  </CommandEmpty>
                  <CommandGroup className="max-h-[240px] overflow-y-auto">
                    {CountryStore?.Countries?.map((country, index) => {
                      const isLast =
                        index === CountryStore?.Countries?.length - 1;
                      return (
                        <CommandItem
                          key={country.id}
                          value={country.name}
                          onSelect={handleCountryChange}
                          ref={isLast ? countryRef : null}
                        >
                          <Check
                            className={cn(
                              "mr-2 h-4 w-4",
                              CountryStore?.SelectedCountry?.name ===
                                country?.name
                                ? "opacity-100"
                                : "opacity-0"
                            )}
                          />
                          {country.translated_name || country.name}
                        </CommandItem>
                      );
                    })}
                    {CountryStore.isLoading &&
                      CountryStore.Countries.length > 0 && <LoacationLoader />}
                  </CommandGroup>
                </Command>
              </PopoverContent>
            </Popover>
          </div>

          <div className="flex flex-col gap-1">
            <Popover
              modal
              open={StateStore?.stateOpen}
              onOpenChange={(isOpen) =>
                setStateStore((prev) => ({ ...prev, stateOpen: isOpen }))
              }
            >
              <PopoverTrigger asChild>
                <Button
                  variant="outline"
                  role="combobox"
                  aria-expanded={StateStore?.stateOpen}
                  className={`w-full justify-between outline-none ${fieldErrors.state ? "border-red-500" : ""
                    }`}
                  disabled={!isCountrySelected}
                >
                  {StateStore?.SelectedState?.translated_name ||
                    StateStore?.SelectedState?.name ||
                    t("state")}
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
              </PopoverTrigger>
              {fieldErrors.state && (
                <span className="text-red-500 text-sm">
                  {t("stateRequired")}
                </span>
              )}
              <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0">
                <Command shouldFilter={false}>
                  <CommandInput
                    placeholder={t("searchStates")}
                    value={StateStore.StateSearch || ""}
                    onValueChange={(val) => {
                      setStateStore((prev) => ({ ...prev, StateSearch: val }));
                    }}
                  />
                  <CommandEmpty>
                    {StateStore.isLoading ? (
                      <LoacationLoader />
                    ) : (
                      <div className="text-center">
                        <p className="text-sm text-muted-foreground">
                          {t("noStatesFound")}
                        </p>
                      </div>
                    )}
                  </CommandEmpty>
                  <CommandGroup className="max-h-[240px] overflow-y-auto">
                    {StateStore?.States?.map((state, index) => {
                      const isLast = index === StateStore?.States?.length - 1;
                      return (
                        <CommandItem
                          key={state.id}
                          value={state.name}
                          onSelect={handleStateChange}
                          ref={isLast ? stateRef : null}
                        >
                          <Check
                            className={cn(
                              "mr-2 h-4 w-4",
                              StateStore?.SelectedState?.name === state?.name
                                ? "opacity-100"
                                : "opacity-0"
                            )}
                          />
                          {state.translated_name || state.name}
                        </CommandItem>
                      );
                    })}
                    {StateStore.isLoading && StateStore.States.length > 0 && (
                      <LoacationLoader />
                    )}
                  </CommandGroup>
                </Command>
              </PopoverContent>
            </Popover>
          </div>

          <div className="flex flex-col gap-1">
            <Popover
              modal
              open={CityStore?.cityOpen}
              onOpenChange={(isOpen) =>
                setCityStore((prev) => ({ ...prev, cityOpen: isOpen }))
              }
            >
              <PopoverTrigger asChild>
                <Button
                  variant="outline"
                  role="combobox"
                  aria-expanded={CityStore?.cityOpen}
                  className={`w-full justify-between outline-none ${fieldErrors.city ? "border-red-500" : ""
                    }`}
                  disabled={!StateStore?.SelectedState?.id}
                >
                  {CityStore?.SelectedCity?.translated_name ||
                    CityStore?.SelectedCity?.name ||
                    t("city")}
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
              </PopoverTrigger>
              {fieldErrors.city && (
                <span className="text-red-500 text-sm">
                  {t("cityRequired")}
                </span>
              )}
              <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0">
                <Command shouldFilter={false}>
                  <CommandInput
                    placeholder={t("searchCities")}
                    value={CityStore.CitySearch || ""}
                    onValueChange={(val) => {
                      setCityStore((prev) => ({ ...prev, CitySearch: val }));
                    }}
                  />
                  <CommandEmpty>
                    {CityStore.isLoading ? (
                      <LoacationLoader />
                    ) : (
                      <div className="text-center">
                        <p className="text-sm text-muted-foreground">
                          {t("noCitiesFound")}
                        </p>
                      </div>
                    )}
                  </CommandEmpty>
                  <CommandGroup className="max-h-[240px] overflow-y-auto">
                    {CityStore?.Cities?.map((city, index) => {
                      const isLast = index === CityStore?.Cities?.length - 1;
                      return (
                        <CommandItem
                          key={city.id}
                          value={city.name}
                          onSelect={handleCityChange}
                          ref={isLast ? cityRef : null}
                        >
                          <Check
                            className={cn(
                              "mr-2 h-4 w-4",
                              CityStore?.SelectedCity?.name === city?.name
                                ? "opacity-100"
                                : "opacity-0"
                            )}
                          />
                          {city.translated_name || city.name}
                        </CommandItem>
                      );
                    })}
                    {CityStore.isLoading && CityStore.Cities.length > 0 && (
                      <LoacationLoader />
                    )}
                  </CommandGroup>
                </Command>
              </PopoverContent>
            </Popover>
          </div>

          {hasAreas || AreaStore?.AreaSearch ? (
            <div className="flex flex-col gap-1">
              <Popover
                modal
                open={AreaStore?.areaOpen}
                onOpenChange={(isOpen) =>
                  setAreaStore((prev) => ({ ...prev, areaOpen: isOpen }))
                }
              >
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={AreaStore?.areaOpen}
                    className={`w-full justify-between outline-none ${fieldErrors.address ? "border-red-500" : ""
                      }`}
                    disabled={!CityStore?.SelectedCity?.id}
                  >
                    {AreaStore?.SelectedArea?.translated_name ||
                      AreaStore?.SelectedArea?.name ||
                      t("area")}
                    <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                  </Button>
                </PopoverTrigger>
                {fieldErrors.address && (
                  <span className="text-red-500 text-sm">
                    {t("areaRequired")}
                  </span>
                )}
                <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0">
                  <Command shouldFilter={false}>
                    <CommandInput
                      placeholder={t("searchAreas")}
                      value={AreaStore.AreaSearch || ""}
                      onValueChange={(val) => {
                        setAreaStore((prev) => ({ ...prev, AreaSearch: val }));
                      }}
                    />
                    <CommandEmpty>
                      {AreaStore.isLoading ? (
                        <LoacationLoader />
                      ) : (
                        <div className="text-center">
                          <p className="text-sm text-muted-foreground">
                            {t("noAreasFound")}
                          </p>
                        </div>
                      )}
                    </CommandEmpty>
                    <CommandGroup className="max-h-[240px] overflow-y-auto">
                      {AreaStore?.Areas?.map((area, index) => {
                        const isLast = index === AreaStore?.Areas?.length - 1;
                        return (
                          <CommandItem
                            key={area.id}
                            value={area.name}
                            onSelect={handleAreaChange}
                            ref={isLast ? areaRef : null}
                          >
                            <Check
                              className={cn(
                                "mr-2 h-4 w-4",
                                AreaStore?.SelectedArea?.name === area?.name
                                  ? "opacity-100"
                                  : "opacity-0"
                              )}
                            />
                            {area.translated_name || area.name}
                          </CommandItem>
                        );
                      })}
                      {AreaStore.isLoading && AreaStore.Areas.length > 0 && (
                        <LoacationLoader />
                      )}
                    </CommandGroup>
                  </Command>
                </PopoverContent>
              </Popover>
            </div>
          ) : (
            <div className="flex flex-col gap-1">
              <Textarea
                rows={5}
                className={`border p-2 outline-none rounded-md w-full ${fieldErrors.address ? "border-red-500" : ""
                  }`}
                placeholder={t("enterAddre")}
                value={Address}
                onChange={(e) => setAddress(e.target.value)}
                disabled={!CityStore?.SelectedCity?.id}
              />
              {fieldErrors.address && (
                <span className="text-red-500 text-sm">
                  {t("addressRequired")}
                </span>
              )}
            </div>
          )}
        </div>
        <DialogFooter className="flex justify-end gap-2">
          <button onClick={() => setShowManualAddress(false)}>
            {t("cancel")}
          </button>
          <button
            className="bg-primary p-2 px-4 rounded-md text-white font-medium"
            onClick={handleSave}
          >
            {t("save")}
          </button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default ManualAddress;

const LoacationLoader = () => {
  return (
    <div className="flex items-center justify-center py-4">
      <Loader2 className="size-4 animate-spin" />
      <span className="ml-2 text-sm text-muted-foreground">
        {t("loading")}..
      </span>
    </div>
  );
};
