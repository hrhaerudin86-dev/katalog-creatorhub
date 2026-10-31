-- ============================================================================
-- SKEMA DATABASE KREATORFLOW (Supabase PostgreSQL) - VERSI REVISI AMAN TAHAP 2
-- File: docs/schema-kreatorflow.sql
-- 
-- Platform: Performance Creator Marketplace
-- Menghubungkan Brand, Creator, Views, CTA Tracking Link, dan Reward.
-- 
-- PERBAIKAN KEAMANAN & INTEGRITAS KETAT:
-- 1. Anti-Privilege Escalation pada users_profile:
--    - Mencegah pengguna mendaftar atau mengedit diri menjadi admin (INSERT & UPDATE).
--    - Menyediakan provisioning profil aman via trigger auth.users (handle_new_user).
-- 2. Proteksi Finansial Saldo & Penghasilan:
--    - Brand TIDAK DAPAT mengubah saldo_budget secara langsung (dilindungi RLS & trigger).
--    - Creator TIDAK DAPAT memanipulasi total_penghasilan (dilindungi RLS & trigger).
--    - Rekening bank kreator dan kontak/saldo brand diproteksi RLS privat.
-- 3. Views & Delegasi Izin:
--    - campaign_clicks_summary menggunakan security_invoker = true agar Brand & Creator
--      hanya dapat membaca agregasi klik yang menjadi hak mereka.
--    - brands_public dan creators_public menggunakan security_barrier = true tanpa membocorkan data privat.
-- 4. Dukungan Service Role Backend & Admin:
--    - Fungsi is_admin_or_service() mengenali admin konsol serta request server (SUPABASE_SECRET_KEY)
--      tanpa memicu exception pada trigger operasional backend.
-- 5. Penguatan Seluruh Fungsi SECURITY DEFINER:
--    - Semua fungsi menetapkan search_path = public, pg_temp.
--    - Hak akses EXECUTE dicabut dari PUBLIC dan diatur secara eksplisit.
--    - resolve_tracking_code() aman dipanggil anon untuk redirect tanpa membuka tabel mentah.
-- 6. Log Klik & Anomali:
--    - IP mentah di-hash (ip_hash SHA-256).
--    - Integritas finansial & audit dijamin dengan ON DELETE RESTRICT pada riwayat transaksi.
-- ============================================================================

-- Ekstensi yang dibutuhkan
create extension if not exists "pgcrypto";

-- ============================================================================
-- 0. FUNGSI BANTU & TRIGGER KEAMANAN (SECURITY DEFINER DENGAN SEARCH_PATH AMAN)
-- ============================================================================

-- Fungsi otomatis memperbarui kolom updated_at
create or replace function public.set_current_timestamp_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql set search_path = public, pg_temp;

-- Fungsi pemeriksa admin & service_role backend
-- Mengenali admin terautentikasi dan service_role server (misal Server Actions / Route Handlers)
create or replace function public.is_admin_or_service()
returns boolean as $$
declare
  _is_adm boolean;
  _role text;
begin
  -- 1. Cek jika dipanggil langsung oleh role database postgres atau service_role
  if current_user in ('postgres', 'service_role') then
    return true;
  end if;

  -- 2. Cek JWT claim role untuk request backend Supabase (Service Role Key)
  begin
    _role := nullif(current_setting('request.jwt.claim.role', true), '');
    if _role = 'service_role' then
      return true;
    end if;
  exception when others then
    -- Abaikan jika request.jwt.claim.role tidak diset
  end;

  -- 3. Cek apakah auth.uid() memiliki role admin di users_profile
  select exists (
    select 1
    from public.users_profile
    where id = auth.uid()
      and role = 'admin'
  ) into _is_adm;

  return coalesce(_is_adm, false);
end;
$$ language plpgsql security definer set search_path = public, pg_temp stable;

-- Fungsi kompatibilitas is_admin()
create or replace function public.is_admin()
returns boolean as $$
begin
  return public.is_admin_or_service();
end;
$$ language plpgsql security definer set search_path = public, pg_temp stable;

-- Trigger: Mencegah privilege escalation pada INSERT dan UPDATE di users_profile
create or replace function public.trg_prevent_user_role_escalation()
returns trigger as $$
begin
  if tg_op = 'INSERT' then
    -- Mencegah client mendaftar langsung dengan role admin
    if new.role = 'admin' and not public.is_admin_or_service() then
      raise exception 'Akses ditolak: Akun admin hanya dapat dibuat oleh administrator atau service role backend.';
    end if;
    if new.role is null or new.role not in ('brand', 'creator', 'admin') then
      raise exception 'Role tidak valid: Harus "brand" atau "creator".';
    end if;
  elsif tg_op = 'UPDATE' then
    -- Mencegah modifikasi role oleh selain admin/service role
    if (new.role is distinct from old.role) and not public.is_admin_or_service() then
      raise exception 'Akses ditolak: Hanya admin yang berwenang mengubah role akun.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

-- Trigger: Melindungi saldo_budget tabel brands dari modifikasi sepihak pemilik Brand
create or replace function public.trg_protect_brand_fields()
returns trigger as $$
begin
  if not public.is_admin_or_service() then
    if tg_op = 'INSERT' then
      if new.saldo_budget <> 0 then
        raise exception 'Akses ditolak: Saldo awal brand harus Rp0. Pengisian saldo hanya dapat melalui top up resmi/admin.';
      end if;
      if new.user_id <> auth.uid() then
        raise exception 'Akses ditolak: user_id harus sesuai dengan identitas login Anda.';
      end if;
    elsif tg_op = 'UPDATE' then
      if new.saldo_budget is distinct from old.saldo_budget then
        raise exception 'Akses ditolak: Saldo budget hanya dapat diperbarui melalui mekanisme pembayaran server atau administrator.';
      end if;
      if new.user_id is distinct from old.user_id then
        raise exception 'Akses ditolak: Pemilik entitas brand (user_id) tidak dapat diubah.';
      end if;
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

-- Trigger: Melindungi total_penghasilan tabel creators dari modifikasi sepihak Creator
create or replace function public.trg_protect_creator_fields()
returns trigger as $$
begin
  if not public.is_admin_or_service() then
    if tg_op = 'INSERT' then
      if new.total_penghasilan <> 0 then
        raise exception 'Akses ditolak: total_penghasilan awal harus Rp0.';
      end if;
      if new.user_id <> auth.uid() then
        raise exception 'Akses ditolak: user_id harus sesuai dengan identitas login Anda.';
      end if;
    elsif tg_op = 'UPDATE' then
      if new.total_penghasilan is distinct from old.total_penghasilan then
        raise exception 'Akses ditolak: total_penghasilan hanya dapat diperbarui oleh sistem verifikasi reward atau administrator.';
      end if;
      if new.user_id is distinct from old.user_id then
        raise exception 'Akses ditolak: Pemilik akun kreator (user_id) tidak dapat dipindahtangankan.';
      end if;
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

-- Fungsi provisioning otomatis profil pengguna saat pendaftaran di Supabase Auth (auth.users)
create or replace function public.handle_new_user()
returns trigger as $$
declare
  _raw_role text;
  _valid_role text;
begin
  -- Ambil role dari raw_user_meta_data jika disediakan
  _raw_role := new.raw_user_meta_data->>'role';

  -- Cegah injeksi role admin dari pendaftaran mandiri pengguna
  if _raw_role in ('brand', 'creator') then
    _valid_role := _raw_role;
  else
    _valid_role := 'creator'; -- Default aman
  end if;

  insert into public.users_profile (id, role, nama, email, avatar_url)
  values (
    new.id,
    _valid_role,
    coalesce(new.raw_user_meta_data->>'nama', new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

-- ============================================================================
-- 1. TABEL: users_profile
-- Profil pengguna terhubung dengan Supabase Auth (auth.users)
-- ============================================================================
create table if not exists public.users_profile (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('brand', 'creator', 'admin')),
  nama text not null,
  email text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_users_profile_role on public.users_profile(role);

drop trigger if exists trg_users_profile_role_guard on public.users_profile;
create trigger trg_users_profile_role_guard
before insert or update on public.users_profile
for each row execute function public.trg_prevent_user_role_escalation();

drop trigger if exists trg_users_profile_updated_at on public.users_profile;
create trigger trg_users_profile_updated_at
before update on public.users_profile
for each row execute function public.set_current_timestamp_updated_at();

-- Pemicu trigger otomatis saat ada user baru di auth.users (jika tabel auth.users tersedia)
do $$
begin
  if exists (
    select 1 from pg_namespace n
    join pg_class c on c.relnamespace = n.oid
    where n.nspname = 'auth' and c.relname = 'users'
  ) then
    drop trigger if exists on_auth_user_created on auth.users;
    create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();
  end if;
end;
$$;

-- ============================================================================
-- 2. TABEL: brands
-- Profil entitas brand pemilik kampanye endorsement
-- Kolom privat (saldo_budget, kontak_wa) hanya diakses pemilik dan admin
-- ============================================================================
create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users_profile(id) on delete cascade,
  nama_brand text not null,
  kategori text,
  kontak_wa text,
  website_url text,
  saldo_budget bigint not null default 0 check (saldo_budget >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_brands_user_id on public.brands(user_id);

drop trigger if exists trg_brands_protect on public.brands;
create trigger trg_brands_protect
before insert or update on public.brands
for each row execute function public.trg_protect_brand_fields();

drop trigger if exists trg_brands_updated_at on public.brands;
create trigger trg_brands_updated_at
before update on public.brands
for each row execute function public.set_current_timestamp_updated_at();

-- View publik Brand (menggunakan security_barrier, menyembunyikan kontak_wa dan saldo_budget)
create or replace view public.brands_public
with (security_barrier = true) as
select
  id,
  nama_brand,
  kategori,
  website_url,
  created_at
from public.brands;

-- ============================================================================
-- 3. TABEL: creators
-- Profil kreator konten
-- Data rekening bank dan total penghasilan bersifat SENSITIF (hanya pemilik & admin)
-- ============================================================================
create table if not exists public.creators (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users_profile(id) on delete cascade,
  handle text not null unique, -- Contoh: '@dapurrani'
  nama text not null,
  niche text not null,        -- Contoh: 'Kuliner', 'Fashion', 'Camilan'
  platform_utama text not null default 'TikTok' check (platform_utama in ('TikTok', 'Instagram Reels', 'YouTube Shorts', 'Multi-platform')),
  bio text,
  nomor_rekening text,        -- SENSITIF
  nama_bank text,             -- SENSITIF
  atas_nama text,             -- SENSITIF
  total_penghasilan bigint not null default 0 check (total_penghasilan >= 0), -- SENSITIF
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_creators_user_id on public.creators(user_id);
create index if not exists idx_creators_handle on public.creators(handle);
create index if not exists idx_creators_niche on public.creators(niche);

drop trigger if exists trg_creators_protect on public.creators;
create trigger trg_creators_protect
before insert or update on public.creators
for each row execute function public.trg_protect_creator_fields();

drop trigger if exists trg_creators_updated_at on public.creators;
create trigger trg_creators_updated_at
before update on public.creators
for each row execute function public.set_current_timestamp_updated_at();

-- View publik Creator (menggunakan security_barrier, menyembunyikan data perbankan & pendapatan total)
create or replace view public.creators_public
with (security_barrier = true) as
select
  id,
  user_id,
  handle,
  nama,
  niche,
  platform_utama,
  bio,
  created_at
from public.creators;

-- ============================================================================
-- 4. TABEL: campaigns
-- Manajemen kampanye endorsement oleh Brand
-- Model pembayaran: CPM (per 1k views valid), CPC (per klik), Hybrid (views + klik)
-- ============================================================================
create table if not exists public.campaigns (
  id bigint generated always as identity primary key,
  brand_id uuid not null references public.brands(id) on delete restrict, -- RESTRICT: riwayat kampanye tidak boleh hilang
  nama text not null,
  platform text not null check (platform in ('TikTok', 'Instagram Reels', 'YouTube Shorts')),
  status text not null default 'Review' check (status in ('Aktif', 'Review', 'Jeda', 'Selesai')),
  model_pembayaran text not null default 'cpm' check (model_pembayaran in ('cpm', 'cpc', 'hybrid')),
  budget bigint not null check (budget >= 500000), -- Minimal budget Rp500.000 sesuai prototype
  cpm bigint not null default 0 check (cpm >= 0),   -- Biaya per 1.000 views valid (Rp)
  cpc bigint not null default 0 check (cpc >= 0),   -- Biaya per 1 CTA click valid (Rp)
  cta_target text not null check (cta_target in ('Website', 'Halaman produk', 'WhatsApp brand')),
  cta_url text,                                    -- URL tujuan asli (landing page)
  periode text not null,                           -- Format deskriptif: '1–31 Okt 2026'
  tanggal_mulai date,
  tanggal_selesai date,
  brief text not null,
  total_views bigint not null default 0 check (total_views >= 0),
  total_clicks bigint not null default 0 check (total_clicks >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_campaigns_brand_id on public.campaigns(brand_id);
create index if not exists idx_campaigns_status on public.campaigns(status);
create index if not exists idx_campaigns_platform on public.campaigns(platform);

drop trigger if exists trg_campaigns_updated_at on public.campaigns;
create trigger trg_campaigns_updated_at
before update on public.campaigns
for each row execute function public.set_current_timestamp_updated_at();

-- ============================================================================
-- 5. TABEL: campaign_creators
-- Relasi pendaftaran creator ke kampanye yang diminati
-- ============================================================================
create table if not exists public.campaign_creators (
  id bigint generated always as identity primary key,
  campaign_id bigint not null references public.campaigns(id) on delete restrict,
  creator_id uuid not null references public.creators(id) on delete restrict,
  status text not null default 'Bergabung' check (status in ('Bergabung', 'Aktif', 'Selesai', 'Dibatalkan')),
  joined_at timestamptz not null default now(),
  unique (campaign_id, creator_id)
);

create index if not exists idx_campaign_creators_campaign_id on public.campaign_creators(campaign_id);
create index if not exists idx_campaign_creators_creator_id on public.campaign_creators(creator_id);

-- ============================================================================
-- 6. TABEL: submissions
-- Pengiriman tautan video publikasi oleh Creator untuk divalidasi Admin
-- Terikat ke relasi sah campaign_creators
-- ============================================================================
create table if not exists public.submissions (
  id bigint generated always as identity primary key,
  campaign_id bigint not null,
  creator_id uuid not null,
  url_konten text not null,
  reported_views bigint not null default 0 check (reported_views >= 0),
  valid_views bigint not null default 0 check (valid_views >= 0),
  clicks bigint not null default 0 check (clicks >= 0),
  status text not null default 'Review' check (status in ('Review', 'Ditahan', 'Disetujui', 'Ditolak')),
  flag_anomali text,
  catatan_admin text,
  payout_status text check (payout_status in ('belum', 'menunggu', 'disetujui', 'dibayar')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- INTEGRITAS KOMPOSIT: Creator hanya bisa kirim submission jika telah bergabung ke kampanye ini
  foreign key (campaign_id, creator_id) references public.campaign_creators(campaign_id, creator_id) on delete restrict
);

create index if not exists idx_submissions_campaign_id on public.submissions(campaign_id);
create index if not exists idx_submissions_creator_id on public.submissions(creator_id);
create index if not exists idx_submissions_status on public.submissions(status);

-- Trigger proteksi: Mencegah creator mengubah metrik atau status validasi
create or replace function public.trg_protect_submission_fields()
returns trigger as $$
begin
  if not public.is_admin_or_service() then
    if new.valid_views is distinct from old.valid_views or
       new.clicks is distinct from old.clicks or
       new.status is distinct from old.status or
       new.payout_status is distinct from old.payout_status or
       new.flag_anomali is distinct from old.flag_anomali or
       new.catatan_admin is distinct from old.catatan_admin or
       new.campaign_id is distinct from old.campaign_id or
       new.creator_id is distinct from old.creator_id then
      raise exception 'Akses ditolak: Creator tidak berwenang mengubah status validasi, metrik views/klik, atau status reward.';
    end if;

    if old.status <> 'Review' then
      raise exception 'Akses ditolak: Konten yang telah diproses/disetujui tidak dapat diedit.';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

drop trigger if exists trg_submissions_protect on public.submissions;
create trigger trg_submissions_protect
before update on public.submissions
for each row execute function public.trg_protect_submission_fields();

drop trigger if exists trg_submissions_updated_at on public.submissions;
create trigger trg_submissions_updated_at
before update on public.submissions
for each row execute function public.set_current_timestamp_updated_at();

-- ============================================================================
-- 7. TABEL: tracking_links
-- Tautan pelacakan unik per Creator per Kampanye (e.g. go.brandanda.id/c/dapurrani-k1)
-- ============================================================================
create table if not exists public.tracking_links (
  id bigint generated always as identity primary key,
  campaign_id bigint not null,
  creator_id uuid not null,
  code text not null unique,        -- Slug unik, misal: 'dapurrani-k1'
  target_url text not null,         -- URL redirect asli brand
  total_clicks bigint not null default 0 check (total_clicks >= 0),
  created_at timestamptz not null default now(),
  unique (campaign_id, creator_id),
  foreign key (campaign_id, creator_id) references public.campaign_creators(campaign_id, creator_id) on delete restrict
);

create index if not exists idx_tracking_links_code on public.tracking_links(code);
create index if not exists idx_tracking_links_campaign_creator on public.tracking_links(campaign_id, creator_id);

-- Fungsi lookup aman untuk redirect server-side (mencegah scraping tabel)
create or replace function public.resolve_tracking_code(p_code text)
returns table(target_url text, campaign_id bigint, creator_id uuid, tracking_link_id bigint) as $$
begin
  return query
  select tl.target_url, tl.campaign_id, tl.creator_id, tl.id
  from public.tracking_links tl
  join public.campaigns c on c.id = tl.campaign_id
  where tl.code = p_code
    and c.status = 'Aktif'
  limit 1;
end;
$$ language plpgsql security definer set search_path = public, pg_temp stable;

-- ============================================================================
-- 8. TABEL: cta_clicks
-- Log klik CTA setiap kali tracking link diklik pengunjung
-- IP mentah TIDAK disimpan; menggunakan ip_hash (SHA-256 + salt) demi kepatuhan privasi
-- ============================================================================
create table if not exists public.cta_clicks (
  id bigint generated always as identity primary key,
  tracking_link_id bigint not null references public.tracking_links(id) on delete restrict,
  campaign_id bigint not null,
  creator_id uuid not null,
  ip_hash text not null,            -- Hash satu arah dari IP pengunjung (SHA-256)
  user_agent text,
  referrer text,
  is_valid boolean not null default true, -- Penanda klik valid vs bot/anomali
  created_at timestamptz not null default now(),
  foreign key (campaign_id, creator_id) references public.campaign_creators(campaign_id, creator_id) on delete restrict
);

create index if not exists idx_cta_clicks_tracking_link on public.cta_clicks(tracking_link_id);
create index if not exists idx_cta_clicks_campaign_id on public.cta_clicks(campaign_id);
create index if not exists idx_cta_clicks_creator_id on public.cta_clicks(creator_id);
create index if not exists idx_cta_clicks_created_at on public.cta_clicks(created_at);

-- View analitik agregasi klik dengan security_invoker = true
-- Memastikan caller RLS berlaku: Brand hanya melihat kampanyenya, Creator hanya link miliknya
create or replace view public.campaign_clicks_summary
with (security_invoker = true) as
select
  campaign_id,
  creator_id,
  date_trunc('day', created_at) as tanggal,
  count(*) filter (where is_valid = true) as valid_clicks,
  count(*) filter (where is_valid = false) as flagged_clicks
from public.cta_clicks
group by campaign_id, creator_id, date_trunc('day', created_at);

-- ============================================================================
-- 9. TABEL: anomalies
-- Deteksi anomali traffic (CTR abnormal, lonjakan views bot, burst click farm)
-- ============================================================================
create table if not exists public.anomalies (
  id bigint generated always as identity primary key,
  campaign_id bigint not null,
  creator_id uuid not null,
  submission_id bigint references public.submissions(id) on delete set null,
  judul text not null,              -- Misal: 'Rasio klik terlalu tinggi'
  detail text not null,             -- Penjelasan anomali yang ditemukan
  status text not null default 'Baru' check (status in ('Baru', 'Ditahan', 'Diabaikan', 'Selesai')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  foreign key (campaign_id, creator_id) references public.campaign_creators(campaign_id, creator_id) on delete restrict
);

create index if not exists idx_anomalies_campaign_id on public.anomalies(campaign_id);
create index if not exists idx_anomalies_creator_id on public.anomalies(creator_id);
create index if not exists idx_anomalies_status on public.anomalies(status);

-- ============================================================================
-- 10. TABEL: payouts
-- Persetujuan nominal reward sebelum dicairkan ke Creator
-- HANYA Admin atau Service Role backend yang berwenang mengelola persetujuan reward
-- ============================================================================
create table if not exists public.payouts (
  id bigint generated always as identity primary key,
  submission_id bigint not null unique references public.submissions(id) on delete restrict,
  creator_id uuid not null,
  campaign_id bigint not null,
  views_valid bigint not null default 0 check (views_valid >= 0),
  clicks_valid bigint not null default 0 check (clicks_valid >= 0),
  amount bigint not null check (amount >= 0), -- Total reward yang disetujui (Rp)
  status text not null default 'menunggu' check (status in ('menunggu', 'disetujui', 'dibayar', 'ditolak')),
  approved_by uuid references public.users_profile(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (campaign_id, creator_id) references public.campaign_creators(campaign_id, creator_id) on delete restrict
);

create index if not exists idx_payouts_creator_id on public.payouts(creator_id);
create index if not exists idx_payouts_campaign_id on public.payouts(campaign_id);
create index if not exists idx_payouts_status on public.payouts(status);

-- Trigger proteksi: Hanya admin atau service role backend yang boleh mengelola tabel payouts
create or replace function public.trg_protect_payout_integrity()
returns trigger as $$
begin
  if not public.is_admin_or_service() then
    raise exception 'Akses ditolak: Hanya admin atau service role backend yang berwenang membuat atau mengubah persetujuan reward.';
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public, pg_temp;

drop trigger if exists trg_payouts_protect on public.payouts;
create trigger trg_payouts_protect
before insert or update or delete on public.payouts
for each row execute function public.trg_protect_payout_integrity();

-- ============================================================================
-- KEBIJAKAN ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Aktifkan RLS pada seluruh tabel KreatorFlow
alter table public.users_profile enable row level security;
alter table public.brands enable row level security;
alter table public.creators enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_creators enable row level security;
alter table public.submissions enable row level security;
alter table public.tracking_links enable row level security;
alter table public.cta_clicks enable row level security;
alter table public.anomalies enable row level security;
alter table public.payouts enable row level security;

-- ----------------------------------------------------------------------------
-- RLS: users_profile (Bebas Rekursi & Proteksi Privilege Escalation)
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_users_profile" on public.users_profile;
drop policy if exists "admin_service_all_users_profile" on public.users_profile;
create policy "admin_service_all_users_profile" on public.users_profile
  for all to authenticated
  using (public.is_admin_or_service());

drop policy if exists "user_read_own_profile" on public.users_profile;
create policy "user_read_own_profile" on public.users_profile
  for select to authenticated
  using (id = auth.uid());

-- Pengguna baru hanya boleh insert profil dengan role brand atau creator (bukan admin)
drop policy if exists "user_insert_own_profile" on public.users_profile;
create policy "user_insert_own_profile" on public.users_profile
  for insert to authenticated
  with check (
    id = auth.uid()
    and (role in ('brand', 'creator') or public.is_admin_or_service())
  );

-- Bebas infinite recursion: validasi role ditangani oleh trg_prevent_user_role_escalation
drop policy if exists "user_update_own_profile" on public.users_profile;
create policy "user_update_own_profile" on public.users_profile
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ----------------------------------------------------------------------------
-- RLS: brands (Proteksi Saldo & Kontak Privat)
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_brands" on public.brands;
drop policy if exists "admin_service_all_brands" on public.brands;
create policy "admin_service_all_brands" on public.brands
  for all to authenticated
  using (public.is_admin_or_service());

drop policy if exists "brand_manage_own" on public.brands;
drop policy if exists "brand_select_own" on public.brands;
create policy "brand_select_own" on public.brands
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "brand_insert_own" on public.brands;
create policy "brand_insert_own" on public.brands
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (saldo_budget = 0 or public.is_admin_or_service())
  );

-- Brand hanya dapat mengubah nama, kategori, kontak_wa, website_url; saldo_budget dijaga trg_protect_brand_fields
drop policy if exists "brand_update_own" on public.brands;
create policy "brand_update_own" on public.brands
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- RLS: creators (Proteksi Data Rekening & Penghasilan)
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_creators" on public.creators;
drop policy if exists "admin_service_all_creators" on public.creators;
create policy "admin_service_all_creators" on public.creators
  for all to authenticated
  using (public.is_admin_or_service());

drop policy if exists "creator_manage_own" on public.creators;
drop policy if exists "creator_select_own" on public.creators;
create policy "creator_select_own" on public.creators
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "creator_insert_own" on public.creators;
create policy "creator_insert_own" on public.creators
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (total_penghasilan = 0 or public.is_admin_or_service())
  );

-- Creator hanya dapat mengubah profil & rekening miliknya; total_penghasilan dijaga trg_protect_creator_fields
drop policy if exists "creator_update_own" on public.creators;
create policy "creator_update_own" on public.creators
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- RLS: campaigns
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_campaigns" on public.campaigns;
drop policy if exists "admin_service_all_campaigns" on public.campaigns;
create policy "admin_service_all_campaigns" on public.campaigns
  for all to authenticated
  using (public.is_admin_or_service());

-- Brand hanya dapat mengelola kampanye miliknya sendiri
drop policy if exists "brand_manage_own_campaigns" on public.campaigns;
create policy "brand_manage_own_campaigns" on public.campaigns
  for all to authenticated
  using (brand_id in (select id from public.brands where user_id = auth.uid()))
  with check (brand_id in (select id from public.brands where user_id = auth.uid()));

-- Creator hanya dapat membaca kampanye Aktif yang belum kadaluarsa atau kampanye yang diikutinya
drop policy if exists "creator_read_active_campaigns" on public.campaigns;
create policy "creator_read_active_campaigns" on public.campaigns
  for select to authenticated
  using (
    (status = 'Aktif' and (tanggal_selesai is null or tanggal_selesai >= current_date))
    or id in (
      select campaign_id from public.campaign_creators
      where creator_id in (select id from public.creators where user_id = auth.uid())
    )
  );

-- ----------------------------------------------------------------------------
-- RLS: campaign_creators
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_campaign_creators" on public.campaign_creators;
drop policy if exists "admin_service_all_campaign_creators" on public.campaign_creators;
create policy "admin_service_all_campaign_creators" on public.campaign_creators
  for all to authenticated
  using (public.is_admin_or_service());

-- Creator hanya boleh mendaftar ke kampanye Aktif dan belum kadaluarsa dengan status awal 'Bergabung'
drop policy if exists "creator_join_active_campaign" on public.campaign_creators;
create policy "creator_join_active_campaign" on public.campaign_creators
  for insert to authenticated
  with check (
    creator_id in (select id from public.creators where user_id = auth.uid())
    and status = 'Bergabung'
    and campaign_id in (
      select id from public.campaigns
      where status = 'Aktif'
        and (tanggal_selesai is null or tanggal_selesai >= current_date)
    )
  );

-- Creator hanya boleh membatalkan keikutsertaan miliknya sendiri
drop policy if exists "creator_cancel_own_join" on public.campaign_creators;
create policy "creator_cancel_own_join" on public.campaign_creators
  for update to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()))
  with check (
    creator_id in (select id from public.creators where user_id = auth.uid())
    and status = 'Dibatalkan'
  );

-- Creator melihat riwayat kampanye yang diikutinya
drop policy if exists "creator_view_own_joins" on public.campaign_creators;
create policy "creator_view_own_joins" on public.campaign_creators
  for select to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()));

-- Brand melihat creator yang bergabung pada kampanyenya
drop policy if exists "brand_view_campaign_creators" on public.campaign_creators;
create policy "brand_view_campaign_creators" on public.campaign_creators
  for select to authenticated
  using (campaign_id in (
    select id from public.campaigns where brand_id in (select id from public.brands where user_id = auth.uid())
  ));

-- ----------------------------------------------------------------------------
-- RLS: submissions
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_submissions" on public.submissions;
drop policy if exists "admin_service_all_submissions" on public.submissions;
create policy "admin_service_all_submissions" on public.submissions
  for all to authenticated
  using (public.is_admin_or_service());

-- Creator hanya boleh submit ke kampanye aktif yang statusnya 'Bergabung'/'Aktif'
drop policy if exists "creator_insert_submission" on public.submissions;
create policy "creator_insert_submission" on public.submissions
  for insert to authenticated
  with check (
    creator_id in (select id from public.creators where user_id = auth.uid())
    and status = 'Review'
    and valid_views = 0
    and clicks = 0
    and payout_status is null
    and flag_anomali is null
    and catatan_admin is null
    and campaign_id in (
      select cc.campaign_id from public.campaign_creators cc
      join public.campaigns c on c.id = cc.campaign_id
      where cc.creator_id in (select id from public.creators where user_id = auth.uid())
        and cc.status in ('Bergabung', 'Aktif')
        and c.status = 'Aktif'
        and (c.tanggal_selesai is null or c.tanggal_selesai >= current_date)
    )
  );

-- Creator hanya boleh update url_konten jika status masih 'Review'
drop policy if exists "creator_update_own_submission" on public.submissions;
create policy "creator_update_own_submission" on public.submissions
  for update to authenticated
  using (
    creator_id in (select id from public.creators where user_id = auth.uid())
    and status = 'Review'
  )
  with check (
    creator_id in (select id from public.creators where user_id = auth.uid())
    and status = 'Review'
  );

drop policy if exists "creator_view_own_submissions" on public.submissions;
create policy "creator_view_own_submissions" on public.submissions
  for select to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()));

drop policy if exists "brand_view_campaign_submissions" on public.submissions;
create policy "brand_view_campaign_submissions" on public.submissions
  for select to authenticated
  using (campaign_id in (
    select id from public.campaigns where brand_id in (select id from public.brands where user_id = auth.uid())
  ));

-- ----------------------------------------------------------------------------
-- RLS: tracking_links (TIDAK ADA SELECT ANONIM LANGSUNG)
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_tracking_links" on public.tracking_links;
drop policy if exists "admin_service_all_tracking_links" on public.tracking_links;
create policy "admin_service_all_tracking_links" on public.tracking_links
  for all to authenticated
  using (public.is_admin_or_service());

drop policy if exists "brand_view_tracking_links" on public.tracking_links;
create policy "brand_view_tracking_links" on public.tracking_links
  for select to authenticated
  using (campaign_id in (
    select id from public.campaigns where brand_id in (select id from public.brands where user_id = auth.uid())
  ));

drop policy if exists "creator_view_tracking_links" on public.tracking_links;
create policy "creator_view_tracking_links" on public.tracking_links
  for select to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()));

-- ----------------------------------------------------------------------------
-- RLS: cta_clicks (Proteksi Metadata Privasi Pengunjung)
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_cta_clicks" on public.cta_clicks;
drop policy if exists "admin_service_all_cta_clicks" on public.cta_clicks;
create policy "admin_service_all_cta_clicks" on public.cta_clicks
  for all to authenticated
  using (public.is_admin_or_service());

-- Brand hanya dapat melihat log klik pada kampanyenya
drop policy if exists "brand_view_campaign_clicks" on public.cta_clicks;
create policy "brand_view_campaign_clicks" on public.cta_clicks
  for select to authenticated
  using (campaign_id in (
    select id from public.campaigns where brand_id in (select id from public.brands where user_id = auth.uid())
  ));

-- Creator hanya dapat melihat log klik pada link miliknya
drop policy if exists "creator_view_own_clicks" on public.cta_clicks;
create policy "creator_view_own_clicks" on public.cta_clicks
  for select to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()));

-- ----------------------------------------------------------------------------
-- RLS: anomalies
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_anomalies" on public.anomalies;
drop policy if exists "admin_service_all_anomalies" on public.anomalies;
create policy "admin_service_all_anomalies" on public.anomalies
  for all to authenticated
  using (public.is_admin_or_service());

drop policy if exists "brand_view_campaign_anomalies" on public.anomalies;
create policy "brand_view_campaign_anomalies" on public.anomalies
  for select to authenticated
  using (campaign_id in (
    select id from public.campaigns where brand_id in (select id from public.brands where user_id = auth.uid())
  ));

drop policy if exists "creator_view_own_anomalies" on public.anomalies;
create policy "creator_view_own_anomalies" on public.anomalies
  for select to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()));

-- ----------------------------------------------------------------------------
-- RLS: payouts (HANYA BISA DIBACA OLEH CREATOR & BRAND, DIKELOLA ADMIN/SERVICE)
-- ----------------------------------------------------------------------------
drop policy if exists "admin_all_payouts" on public.payouts;
drop policy if exists "admin_service_all_payouts" on public.payouts;
create policy "admin_service_all_payouts" on public.payouts
  for all to authenticated
  using (public.is_admin_or_service());

-- Creator hanya bisa MELIHAT status reward/payout miliknya
drop policy if exists "creator_view_own_payouts" on public.payouts;
create policy "creator_view_own_payouts" on public.payouts
  for select to authenticated
  using (creator_id in (select id from public.creators where user_id = auth.uid()));

-- Brand hanya bisa MELIHAT reward yang dibayarkan pada kampanyenya
drop policy if exists "brand_view_campaign_payouts" on public.payouts;
create policy "brand_view_campaign_payouts" on public.payouts
  for select to authenticated
  using (campaign_id in (
    select id from public.campaigns where brand_id in (select id from public.brands where user_id = auth.uid())
  ));

-- ============================================================================
-- 11. PENGATURAN HAK AKSES (REVOKE & GRANT EKSPLISIT)
-- ============================================================================

-- Cabut izin eksekusi publik default pada fungsi keamanan
revoke all on function public.is_admin() from public;
revoke all on function public.is_admin_or_service() from public;
grant execute on function public.is_admin() to authenticated, service_role;
grant execute on function public.is_admin_or_service() to authenticated, service_role;

revoke all on function public.trg_prevent_user_role_escalation() from public;
revoke all on function public.trg_protect_brand_fields() from public;
revoke all on function public.trg_protect_creator_fields() from public;
revoke all on function public.trg_protect_submission_fields() from public;
revoke all on function public.trg_protect_payout_integrity() from public;
revoke all on function public.set_current_timestamp_updated_at() from public;
revoke all on function public.handle_new_user() from public;

-- resolve_tracking_code dibuka untuk anon, authenticated, dan service_role (untuk redirect URL)
revoke all on function public.resolve_tracking_code(text) from public;
grant execute on function public.resolve_tracking_code(text) to anon, authenticated, service_role;

-- Hak akses views
revoke all on public.campaign_clicks_summary from public;
revoke all on public.campaign_clicks_summary from anon;
grant select on public.campaign_clicks_summary to authenticated, service_role;

revoke all on public.brands_public from public;
grant select on public.brands_public to anon, authenticated, service_role;

revoke all on public.creators_public from public;
grant select on public.creators_public to anon, authenticated, service_role;

-- Hak akses tabel dasar bagi pengguna terautentikasi (RLS memfilter hak akses baris)
grant select, insert, update on public.users_profile to authenticated;
grant select, insert, update on public.brands to authenticated;
grant select, insert, update on public.creators to authenticated;
grant select, insert, update on public.campaigns to authenticated;
grant select, insert, update on public.campaign_creators to authenticated;
grant select, insert, update on public.submissions to authenticated;
grant select, insert, update on public.tracking_links to authenticated;
grant select on public.cta_clicks to authenticated;
grant select, update on public.anomalies to authenticated;
grant select on public.payouts to authenticated;

-- Service role memiliki hak penuh untuk mengelola seluruh data platform
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant all on all routines in schema public to service_role;
