-- Piece counts for desk check-in (total parts in set vs missing on return).
alter table public.toys
  add column if not exists total_pieces integer,
  add column if not exists missing_pieces integer;

comment on column public.toys.total_pieces is 'Expected number of pieces in the toy set.';
comment on column public.toys.missing_pieces is 'Pieces currently known to be missing from the set.';
