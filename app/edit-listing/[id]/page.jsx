import EditListing from "@/components/PagesComponent/EditListing/EditListing";

const EditListingPage = async (props) => {
  const params = await props.params;
  const id = await params.id;
  return <EditListing id={id} />;
};

export default EditListingPage;
