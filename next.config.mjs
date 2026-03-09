/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: false,
  htmlLimitedBots: /.*/,
  images: {
    unoptimized: true,
    remotePatterns: [
      {
        protocol: "https",
        hostname: "eclassify.thewrteam.in",
        port: "", // You can leave this empty if there is no specific port
        pathname: "/**",
      },
    ],
  },
};

export default nextConfig;
