/**
 * The shapes the API actually returns, narrowed to the fields this site reads.
 *
 * Deliberately not a mirror of every column: a directory page needs a name, a
 * picture and a way to get in touch, and typing the other forty fields would
 * only make it harder to see which ones matter.
 */

/** Every record carries both languages; the site is Arabic-first. */
export interface Bilingual {
  name_ar?: string | null;
  name_en?: string | null;
}

export interface Category extends Bilingual {
  id: number;
  slug?: string | null;
  parent_id?: number | null;
  /** A name the dashboard picks ("building", "dress") — not a URL. */
  icon?: string | null;
  /** The category's picture; this one is a real file URL. */
  image?: string | null;
  is_active?: boolean;
}

export interface City extends Bilingual {
  id: number;
  slug?: string | null;
}

export interface Vendor extends Bilingual {
  id: number;
  slug?: string | null;
  description_ar?: string | null;
  description_en?: string | null;
  logo?: string | null;
  cover_image?: string | null;
  phone?: string | null;
  whatsapp?: string | null;
  email?: string | null;
  website?: string | null;
  instagram?: string | null;
  facebook?: string | null;
  tiktok?: string | null;
  snapchat?: string | null;
  address?: string | null;
  latitude?: number | string | null;
  longitude?: number | string | null;
  rating?: number | string | null;
  reviews_count?: number | null;
  views_count?: number | null;
  min_price?: number | string | null;
  max_price?: number | string | null;
  is_verified?: boolean;
  is_featured?: boolean;
  is_vip?: boolean;
  is_store?: boolean;
  is_active?: boolean;
  category?: Category | null;
  city?: City | null;
  category_id?: number | null;
  city_id?: number | null;
  created_at?: string | null;
}

export interface Product extends Bilingual {
  id: number;
  description_ar?: string | null;
  price?: number | string | null;
  discount_price?: number | string | null;
  image?: string | null;
  images?: string[] | null;
  is_available?: boolean;
  vendor_id?: number | null;
  vendor?: Vendor | null;
}

export interface Service extends Bilingual {
  id: number;
  description_ar?: string | null;
  price?: number | string | null;
  discount_price?: number | string | null;
  duration?: number | string | null;
  image?: string | null;
  is_active?: boolean;
  vendor_id?: number | null;
  vendor?: Vendor | null;
}

export interface Promotion {
  id: number;
  title_ar?: string | null;
  title_en?: string | null;
  description_ar?: string | null;
  image?: string | null;
  images?: string[] | null;
  /** 'percent' | 'amount' — decides how discount_value reads. */
  discount_type?: string | null;
  discount_value?: number | string | null;
  start_date?: string | null;
  end_date?: string | null;
  is_active?: boolean;
  vendor_id?: number | null;
  vendor?: Vendor | null;
}

export interface Slider {
  id: number;
  image?: string | null;
  title_ar?: string | null;
  subtitle_ar?: string | null;
  cta_ar?: string | null;
  badge_ar?: string | null;
  vendor_id?: number | null;
  link?: string | null;
}

export interface Post {
  id: number;
  /** 'post' | 'reel'. */
  type?: string | null;
  title?: string | null;
  body?: string | null;
  /** The reel's video, or the post's single image. */
  media_url?: string | null;
  images?: string[] | null;
  thumbnail?: string | null;
  /** 'done' once an uploaded reel has been transcoded; anything else is not playable yet. */
  video_status?: string | null;
  duration?: number | null;
  likes_count?: number | null;
  comments_count?: number | null;
  views_count?: number | null;
  is_published?: boolean;
  vendor_id?: number | null;
  vendor?: Vendor | null;
  created_at?: string | null;
}

export interface Review {
  id: number;
  vendor_id?: number | null;
  rating?: number | null;
  comment?: string | null;
  guest_name?: string | null;
  user?: { id: number; name?: string | null; avatar?: string | null } | null;
  created_at?: string | null;
}

export interface SiteStats {
  vendors?: number;
  users?: number;
  cities?: number;
  visitors?: number;
  offers?: number;
  services?: number;
  likes?: number;
  [k: string]: number | undefined;
}

export interface Story {
  id: number;
  image?: string | null;
  caption_ar?: string | null;
  vendor_id?: number | null;
  vendor?: Vendor | null;
  views_count?: number | null;
  is_active?: boolean;
  is_approved?: boolean;
  expires_at?: string | null;
  created_at?: string | null;
}

export interface Highlight {
  id: number;
  title?: string | null;
  cover_image?: string | null;
  /** Each item points at a story or an image. */
  items?: { id: number; image?: string | null; story_id?: number | null }[] | null;
  vendor_id?: number | null;
  vendor?: Vendor | null;
  is_active?: boolean;
}

/** A card design a member can pick for their invitation. */
export interface InvitationTemplate {
  id: number;
  name?: string | null;
  preview_image?: string | null;
  background_image?: string | null;
  bg_color?: string | null;
  text_color?: string | null;
  accent_color?: string | null;
  font_family?: string | null;
  animation?: string | null;
  is_active?: boolean;
}

/** A ready-made checklist the app hands a couple planning a wedding. */
export interface TaskTemplate {
  id: number;
  title_ar?: string | null;
  description_ar?: string | null;
  icon?: string | null;
  items?: { id?: number; title_ar?: string | null; title?: string | null }[] | null;
  is_active?: boolean;
}

export interface ProductSection extends Bilingual {
  id: number;
  products_count?: number | null;
  vendor_id?: number | null;
}
