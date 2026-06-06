-- Per-toy photo baseline learned from confirmed complete check-ins.
alter table public.toys
  add column if not exists cv_learn_piece_count integer,
  add column if not exists cv_learn_fg_pixels integer,
  add column if not exists cv_learn_peak_count integer,
  add column if not exists cv_learn_samples integer not null default 0;

comment on column public.toys.cv_learn_piece_count is
  'Volunteer-confirmed piece count from a complete-set photo.';
comment on column public.toys.cv_learn_fg_pixels is
  'Foreground pixel count from the learned baseline photo.';
comment on column public.toys.cv_learn_peak_count is
  'Peak-detection count from the learned baseline photo.';
