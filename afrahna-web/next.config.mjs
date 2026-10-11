/** @type {import('next').NextConfig} */
// The site ships as a static export to the same shared host the API lives on:
// every page is real HTML on disk, so the first paint costs one request and no
// JavaScript at all. `next dev` keeps the server behaviour for convenience.
const isExport = process.env.NEXT_OUTPUT === 'export';

const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  compress: true,
  ...(isExport ? { output: 'export', trailingSlash: true } : {}),
  images: {
    // No image optimiser exists in a static export; the API already serves
    // sized files, and every <img> here is lazy with explicit dimensions.
    unoptimized: true,
    remotePatterns: [{ protocol: 'https', hostname: 'afrahna.co' }],
  },
  eslint: { ignoreDuringBuilds: false },
};

export default nextConfig;
