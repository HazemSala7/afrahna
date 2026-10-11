import type { Config } from 'tailwindcss';

// The palette is taken from the app's `AppColors` so the site and the phone
// read as one brand rather than two products with the same logo.
export default {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#B8835A',
          dark: '#8B5A3C',
          light: '#F0DDC8',
          accent: '#D4A373',
        },
        ink: {
          DEFAULT: '#3D2817',
          muted: '#9C8273',
        },
        cream: {
          DEFAULT: '#FAF3EC',
          deep: '#F3E5D2',
          surface: '#FFFBF6',
        },
        sale: '#C1452B',
      },
      fontFamily: {
        sans: ['var(--font-arabic)', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        card: '0 4px 16px rgba(184, 131, 90, 0.10)',
        lift: '0 10px 30px rgba(184, 131, 90, 0.18)',
      },
      borderRadius: { xl2: '1.25rem' },
    },
  },
  plugins: [],
} satisfies Config;
