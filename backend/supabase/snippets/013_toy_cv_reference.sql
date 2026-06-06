-- Per-toy "complete set" reference photo features (SETLS catalog or confirmed check-in).
alter table public.toys
  add column if not exists cv_ref_piece_count integer,
  add column if not exists cv_ref_fg_pixels integer,
  add column if not exists cv_ref_peak_count integer,
  add column if not exists cv_ref_blob_count integer,
  add column if not exists cv_ref_image_area integer,
  add column if not exists cv_ref_layout text,
  add column if not exists cv_ref_source varchar(16);

comment on column public.toys.cv_ref_piece_count is
  'Piece count in the stored reference photo.';
comment on column public.toys.cv_ref_layout is
  'JSON array: 8x8 normalized foreground layout signature.';
comment on column public.toys.cv_ref_source is
  'Reference origin: setls (catalog) or checkin (volunteer-confirmed).';
