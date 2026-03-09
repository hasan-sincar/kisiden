const Loader = () => {
  return (
    <div className="h-screen flex items-center justify-center">
      <div className="relative w-12 h-12">
        <div className="absolute w-12 h-12 bg-primary rounded-full animate-ping"></div>
        <div className="absolute w-12 h-12 bg-primary rounded-full animate-ping delay-1000"></div>
      </div>
    </div>
  );
};

export default Loader;
