import ProductDetail from "@/components/PagesComponent/ProductDetail/ProductDetails";

const MyListingPage = async ({ params }) => {
  const { slug } = await params;
  return <ProductDetail slug={slug} />;
};

export default MyListingPage;
