import { useEffect, useRef, useState } from "react";
import {
  Carousel,
  CarouselContent,
  CarouselItem,
} from "@/components/ui/carousel";
import { PhotoProvider, PhotoView } from "react-photo-view";
import "react-photo-view/dist/react-photo-view.css";
import {
  RiArrowLeftLine,
  RiArrowRightLine,
  RiPlayCircleFill,
} from "react-icons/ri";
import { useSelector } from "react-redux";
import { getIsRtl } from "@/redux/reducer/languageSlice";
import ReactPlayer from "react-player";
import { getPlaceholderImage } from "@/redux/reducer/settingSlice";
import CustomImage from "@/components/Common/CustomImage";

const ProductGallery = ({ galleryImages, videoData }) => {
  const [selectedIndex, setSelectedIndex] = useState(0); // -1 means video
  const carouselApi = useRef(null);
  const isRTL = useSelector(getIsRtl);
  const placeHolderImage = useSelector(getPlaceholderImage);

  const hasVideo = videoData?.url;

  useEffect(() => {
    if (!carouselApi.current) return;
    // If no video, we use this normally
    const handleSelect = () => {
      const index = carouselApi.current.selectedScrollSnap();
      setSelectedIndex(index);
    };
    carouselApi.current.on("select", handleSelect);
    setSelectedIndex(carouselApi.current.selectedScrollSnap());

    return () => {
      carouselApi.current?.off("select", handleSelect);
    };
  }, []);

  const handlePrevImage = () => {
    if (!carouselApi.current) return;
    if (selectedIndex === -1) {
      // From video, go to last image
      const lastImageIndex = galleryImages.length - 1;
      carouselApi.current.scrollTo(lastImageIndex);
      setSelectedIndex(lastImageIndex);
    } else if (selectedIndex === 0) {
      if (hasVideo) {
        setSelectedIndex(-1);
      } else {
        const lastIndex = galleryImages.length - 1;
        carouselApi.current.scrollTo(lastIndex);
        setSelectedIndex(lastIndex);
      }
    } else {
      const newIndex = selectedIndex - 1;
      carouselApi.current.scrollTo(newIndex);
      setSelectedIndex(newIndex);
    }
  };

  const handleNextImage = () => {
    if (!carouselApi.current) return;
    if (selectedIndex === -1) {
      // From video, go to first image
      carouselApi.current.scrollTo(0);
      setSelectedIndex(0);
    } else if (selectedIndex === galleryImages.length - 1) {
      // From last image, go to video
      if (hasVideo) {
        // Go to video
        setSelectedIndex(-1);
      } else {
        // Loop to first image
        carouselApi.current.scrollTo(0);
        setSelectedIndex(0);
      }
    } else {
      const newIndex = (selectedIndex + 1) % galleryImages.length;
      carouselApi.current.scrollTo(newIndex);
      setSelectedIndex(newIndex);
    }
  };

  const handleImageClick = (index) => {
    setSelectedIndex(index);
  };

  return (
    <PhotoProvider>
      <div className="bg-muted rounded-lg">
        {selectedIndex === -1 ? (
          <ReactPlayer
            url={videoData.url}
            controls
            playing={false}
            className="aspect-[870/500] rounded-lg"
            width="100%"
            height="100%"
            config={{
              file: {
                attributes: { controlsList: "nodownload" },
              },
            }}
          />
        ) : (
          <PhotoView
            src={galleryImages[selectedIndex] || placeHolderImage}
            index={selectedIndex}
            key={selectedIndex}
          >
            <CustomImage
              src={galleryImages[selectedIndex]}
              alt="Product Detail"
              width={870}
              height={500}
              className="h-full w-full object-center object-contain rounded-lg aspect-[870/500] cursor-pointer"
            />
          </PhotoView>
        )}
      </div>
      <div className="relative">
        <Carousel
          key={isRTL ? "rtl" : "ltr"}
          opts={{
            align: "start",
            containScroll: "trim",
            direction: isRTL ? "rtl" : "ltr",
          }}
          className="w-full"
          setApi={(api) => {
            carouselApi.current = api;
          }}
        >
          <CarouselContent className="md:-ml-[20px]">
            {galleryImages?.map((image, index) => (
              <CarouselItem key={index} className="basis-auto md:pl-[20px]">
                <PhotoView src={image} index={index} className="hidden" />
                <CustomImage
                  src={image}
                  alt="Product Detail"
                  height={120}
                  width={120}
                  className={`w-[100px] sm:w-[120px] aspect-square object-cover rounded-lg cursor-pointer ${
                    selectedIndex === index ? "border-2 border-primary" : ""
                  }`}
                  onClick={() => handleImageClick(index)}
                />
              </CarouselItem>
            ))}
            {hasVideo && (
              <CarouselItem className="basis-auto md:pl-[20px]">
                <div
                  className={`relative w-[100px] sm:w-[120px] aspect-square rounded-lg cursor-pointer ${
                    selectedIndex === -1 ? "border-2 border-primary" : ""
                  }`}
                  onClick={() => setSelectedIndex(-1)}
                >
                  <CustomImage
                    src={videoData?.thumbnail}
                    alt="Video Thumbnail"
                    height={120}
                    width={120}
                    className="w-full h-full object-cover rounded-lg"
                  />
                  <div className="absolute inset-0 bg-black bg-opacity-30 rounded-lg flex items-center justify-center">
                    <RiPlayCircleFill size={40} className="text-white" />
                  </div>
                </div>
              </CarouselItem>
            )}
          </CarouselContent>
          <div className="absolute top-1/2 ltr:left-2 rtl:right-2 -translate-y-1/2">
            <button
              onClick={handlePrevImage}
              className="bg-primary p-1 sm:p-2 rounded-full"
            >
              <RiArrowLeftLine
                size={24}
                color="white"
                className={isRTL ? "rotate-180" : ""}
              />
            </button>
          </div>
          <div className="absolute top-1/2 ltr:right-2 rtl:left-2 -translate-y-1/2">
            <button
              onClick={handleNextImage}
              className="bg-primary p-1 sm:p-2 rounded-full"
            >
              <RiArrowRightLine
                size={24}
                color="white"
                className={isRTL ? "rotate-180" : ""}
              />
            </button>
          </div>
        </Carousel>
      </div>
    </PhotoProvider>
  );
};
export default ProductGallery;
