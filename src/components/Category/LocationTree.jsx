import { t } from "@/utils";
import {
  getAreasApi,
  getCitiesApi,
  getCoutriesApi,
  getStatesApi,
} from "@/utils/api";
import { Tree } from "antd";
import { useEffect, useState } from "react";
import { GoPlus } from "react-icons/go";
import { LuMinus } from "react-icons/lu";

const LocationTree = ({
  setCountry,
  setState,
  setCity,
  setIsFetchSingleCatItem,
  selectedLocationKey,
  setSelectedLocationKey,
  setArea,
  setKmRange,
  setIsShowKmRange,
}) => {
  const [treeData, setTreeData] = useState([]);

  // country pages
  const [countryCurrentPage, setCountryCurrentPage] = useState(1);
  const [countryLastPage, setCountryLastPage] = useState(1);

  // state pages
  const [stateCurrentPage, setStateCurrentPage] = useState({});
  const [stateLastPage, setStateLastPage] = useState({});

  // city pages
  const [cityCurrentPage, setCityCurrentPage] = useState({});
  const [cityLastPage, setCityLastPage] = useState({});

  // area pages
  const [areaCurrentPage, setAreaCurrentPage] = useState({}); // <--- Added for area pagination
  const [areaLastPage, setAreaLastPage] = useState({}); // <--- Added for area pagination

  const getCountriesData = async (page) => {
    try {
      // Fetch countries
      const res = await getCoutriesApi.getCoutries({ page });
      setCountryCurrentPage(res?.data?.data?.current_page);
      setCountryLastPage(res?.data?.data?.last_page);
      const allCountries = res?.data?.data?.data || [];

      // Construct tree data with only countries
      const countriesData = allCountries.map((country) => ({
        title: country.name,
        key: country.name,
        id: country.id,
        isCountry: true,
        isLeaf: false,
      }));

      setTreeData((prevTreeData) => {
        if (page > 1) {
          // Append new countries to the existing list
          const updatedRootNode = {
            ...prevTreeData[0],
            children: [...prevTreeData[0].children, ...countriesData],
          };
          return [updatedRootNode];
        } else {
          // Create a new root node with the initial list of countries
          const rootNode = {
            title: "All Countries",
            key: "all_countries",
            id: "all_countries",
            isLeaf: false,
            children: countriesData,
          };
          return [rootNode];
        }
      });
    } catch (error) {
      console.error("Error fetching countries data:", error);
    }
  };

  useEffect(() => {
    getCountriesData(1);
  }, []);

  const getStatesData = async (countryId, page = 1) => {
    try {
      const res = await getStatesApi.getStates({ country_id: countryId, page });
      const allStates = res?.data?.data?.data || [];

      setStateCurrentPage((prev) => ({
        ...prev,
        [countryId]: res?.data?.data?.current_page,
      }));

      setStateLastPage((prev) => ({
        ...prev,
        [countryId]: res?.data?.data?.last_page,
      }));

      const states = allStates.map((state) => ({
        title: state.name,
        key: `${countryId}_${state.id}`,
        id: state.id,
        isState: true,
        isLeaf: false,
      }));

      if (res?.data?.data?.current_page < res?.data?.data?.last_page) {
        states.push({
          title: t("loadMore"),
          key: `loadMoreStates_${countryId}`,
          isLoadMore: true,
          isLeaf: true,
          countryId: countryId,
          selectable: false,
        });
      }
      return states;
    } catch (error) {
      console.error("Error fetching states data:", error);
      return [];
    }
  };

  const getCitiesData = async (stateId, page = 1) => {
    try {
      const res = await getCitiesApi.getCities({ state_id: stateId, page });
      const allCities = res?.data?.data?.data || [];

      setCityCurrentPage((prev) => ({
        ...prev,
        [stateId]: res?.data?.data?.current_page,
      }));

      setCityLastPage((prev) => ({
        ...prev,
        [stateId]: res?.data?.data?.last_page,
      }));

      const cities = allCities.map((city) => ({
        title: city.name,
        key: `${stateId}_${city.id}`,
        id: city.id,
        isCity: true,
        isLeaf: city.areas_count === 0,
      }));

      if (res?.data?.data?.current_page < res?.data?.data?.last_page) {
        cities.push({
          title: t("loadMore"),
          key: `loadMoreCities_${stateId}`,
          isLoadMore: true,
          isLeaf: true,
          stateId: stateId,
          selectable: false,
        });
      }

      return cities;
    } catch (error) {
      console.error("Error fetching cities data:", error);
      return [];
    }
  };

  const getAreasData = async (cityId, page = 1) => {
    try {
      const res = await getAreasApi.getAreas({ city_id: cityId, page });
      const allAreas = res?.data?.data?.data || [];

      setAreaCurrentPage((prev) => ({
        ...prev,
        [cityId]: res?.data?.data?.current_page,
      }));

      setAreaLastPage((prev) => ({
        ...prev,
        [cityId]: res?.data?.data?.last_page,
      }));

      const areas = allAreas.map((area) => ({
        title: area.name,
        key: `${cityId}_${area.id}`,
        id: area.id,
        isArea: true,
        isLeaf: true,
      }));

      if (res?.data?.data?.current_page < res?.data?.data?.last_page) {
        areas.push({
          title: t("loadMore"),
          key: `loadMoreAreas_${cityId}`,
          isLoadMore: true,
          isLeaf: true,
          cityId: cityId,
          selectable: false,
        });
      }

      return areas;
    } catch (error) {
      console.error("Error fetching areas data:", error);
      return [];
    }
  };

  const handleLoadData = async (node) => {
    if (node.isLoadMore) {
      if (node.key.startsWith("loadMoreStates")) {
        const countryId = node.countryId;
        loadMoreStates(countryId);
      } else if (node.key.startsWith("loadMoreCities")) {
        const stateId = node.stateId;
        loadMoreCities(stateId);
      } else if (node.key.startsWith("loadMoreAreas")) {
        // <--- Handle load more for areas
        const cityId = node.cityId;
        loadMoreAreas(cityId);
      }
    } else if (node.isCountry) {
      const states = await getStatesData(node.id);
      setTreeData((prevTreeData) => {
        // Update the root node's children with the new states
        const updatedRootNode = {
          ...prevTreeData[0],
          children: prevTreeData[0].children.map((country) => {
            if (country.id === node.id) {
              // Update the specific country with its new children (states)
              return { ...country, children: states };
            }
            return country;
          }),
        };
        // Return the updated treeData with the modified root node
        return [updatedRootNode];
      });
    } else if (node.isState) {
      const cities = await getCitiesData(node.id);
      setTreeData((prevTreeData) => {
        const updatedRootNode = {
          ...prevTreeData[0], // Spread the root node
          children: prevTreeData[0].children.map((country) => {
            const updatedCountry = { ...country };
            if (updatedCountry.children) {
              updatedCountry.children = updatedCountry.children.map((state) => {
                if (state.id === node.id) {
                  return { ...state, children: cities }; // Update state's cities
                }
                return state;
              });
            }
            return updatedCountry;
          }),
        };

        return [updatedRootNode]; // Return the updated root node with new cities
      });
    } else if (node.isCity) {
      const areas = await getAreasData(node.id);
      setTreeData((prevTreeData) => {
        const updatedRootNode = {
          ...prevTreeData[0],
          children: prevTreeData[0].children.map((country) => {
            const updatedCountry = { ...country };
            if (updatedCountry.children) {
              updatedCountry.children = updatedCountry.children.map((state) => {
                const updatedState = { ...state };
                if (updatedState.children) {
                  updatedState.children = updatedState.children.map((city) => {
                    if (city.id === node.id) {
                      return { ...city, children: areas };
                    }
                    return city;
                  });
                }
                return updatedState;
              });
            }
            return updatedCountry;
          }),
        };
        return [updatedRootNode];
      });
    }
  };

  const renderTreeNode = (node) => {
    return (
      <div className="filter_item_cont">
        {node.isLoadMore ? (
          <span
            className="loadMore_label"
            onClick={() => handleLoadMoreClick(node)}
          >
            {node.title}
          </span>
        ) : (
          <span className={`filter_item`}>{node.title}</span>
        )}
      </div>
    );
  };

  const handleLoadMoreClick = (node) => {
    if (node.key.startsWith("loadMoreStates")) {
      const countryId = node.countryId;
      loadMoreStates(countryId);
    } else if (node.key.startsWith("loadMoreCities")) {
      const stateId = node.stateId;
      loadMoreCities(stateId);
    } else if (node.key.startsWith("loadMoreAreas")) {
      // <--- Handle load more click for areas
      const cityId = node.cityId;
      loadMoreAreas(cityId);
    }
  };

  const switcherIcon = ({ expanded }) => {
    return expanded ? (
      <LuMinus size={14} color="#595b6c" fontWeight={600} />
    ) : (
      <GoPlus size={14} color="#595b6c" fontWeight={600} />
    );
  };

  const handleLocationSelect = (selectedKeys, info) => {
    const { node } = info;

    if (
      node?.key === "all_countries" &&
      selectedLocationKey.includes("all_countries")
    ) {
      return;
    }

    // Default reset
    setCity("");
    setCountry("");
    setState("");
    setArea("");
    if (selectedKeys.length === 0 || node?.key === "all_countries") {
      setSelectedLocationKey(["all_countries"]);
    } else {
      setSelectedLocationKey(selectedKeys);
      // Handle country, state, and city selection
      if (node?.isCountry) {
        setCountry(node.title);
      } else if (node?.isState) {
        setState(node.title);
      } else if (node?.isCity) {
        setCity(node?.title);
      } else if (node?.isArea) {
        setArea(node);
      }
    }
    // Trigger API call after state update
    setIsShowKmRange(false);
    setKmRange(0);
    setIsFetchSingleCatItem((prev) => !prev);
  };

  const loadMoreCountries = () => {
    getCountriesData(countryCurrentPage + 1);
  };

  const loadMoreStates = (countryId) => {
    getStatesData(countryId, stateCurrentPage[countryId] + 1).then(
      (newStates) => {
        setTreeData((prevTreeData) => {
          const updatedRootNode = {
            ...prevTreeData[0], // Spread the root node
            children: prevTreeData[0].children.map((country) => {
              if (country.id === countryId) {
                return {
                  ...country,
                  children: [
                    ...country.children.filter((child) => !child.isLoadMore),
                    ...newStates,
                  ],
                };
              }
              return country;
            }),
          };
          return [updatedRootNode];
        });
      }
    );
  };

  const loadMoreCities = (stateId) => {
    getCitiesData(stateId, cityCurrentPage[stateId] + 1).then((newCities) => {
      setTreeData((prevTreeData) => {
        const updatedRootNode = {
          ...prevTreeData[0], // Spread the root node
          children: prevTreeData[0].children.map((country) => {
            const updatedCountry = { ...country };
            if (updatedCountry.children) {
              updatedCountry.children = updatedCountry.children.map((state) => {
                if (state.id === stateId) {
                  return {
                    ...state,
                    children: [
                      ...state.children.filter((child) => !child.isLoadMore),
                      ...newCities,
                    ],
                  };
                }
                return state;
              });
            }
            return updatedCountry;
          }),
        };
        return [updatedRootNode];
      });
    });
  };

  const loadMoreAreas = (cityId) => {
    getAreasData(cityId, areaCurrentPage[cityId] + 1).then((newAreas) => {
      setTreeData((prevTreeData) => {
        const updatedRootNode = {
          ...prevTreeData[0],
          children: prevTreeData[0].children.map((country) => {
            const updatedCountry = { ...country };
            if (updatedCountry.children) {
              updatedCountry.children = updatedCountry.children.map((state) => {
                const updatedState = { ...state };
                if (updatedState.children) {
                  updatedState.children = updatedState.children.map((city) => {
                    if (city.id === cityId) {
                      return {
                        ...city,
                        children: [
                          ...city.children.filter((child) => !child.isLoadMore),
                          ...newAreas,
                        ],
                      };
                    }
                    return city;
                  });
                }
                return updatedState;
              });
            }
            return updatedCountry;
          }),
        };
        return [updatedRootNode];
      });
    });
  };

  return (
    <>
      {treeData && treeData.length > 0 && (
        <Tree
          treeData={treeData}
          titleRender={(node, index) => renderTreeNode(node, index === 0)}
          className="catTree"
          switcherIcon={switcherIcon}
          loadData={handleLoadData}
          onSelect={handleLocationSelect}
          selectedKeys={selectedLocationKey}
          defaultExpandedKeys={["all_countries"]}
        />
      )}
      {countryCurrentPage < countryLastPage && (
        <div className="loadMore" onClick={loadMoreCountries}>
          <button>{t("loadMore")}</button>
        </div>
      )}
    </>
  );
};

export default LocationTree;
