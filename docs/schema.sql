-- Skema database Katalog Kreator (versi Kreator Hub)
-- Cara pakai: Supabase > SQL Editor > New query > tempel seluruh isi file ini > Run.
-- Aman dijalankan ulang.
-- Catatan: nama tabel dan kolom sengaja TIDAK diubah ("produk", "harga", dst.)
-- supaya kode template tetap jalan. Di sini "produk" = kreator, "harga" = tarif endorsement per konten.
-- Semua nama kreator di bawah ini fiktif.

-- 1. Tabel produk (= kreator)
create table if not exists public.produk (
  id bigint generated always as identity primary key,
  nama text not null,
  harga integer not null check (harga >= 0),
  deskripsi text,
  foto_url text,
  kategori text,
  created_at timestamptz not null default now()
);

-- 2. Row Level Security
-- Tidak ada izin untuk publik: akses langsung ke tabel dari luar aplikasi ditolak.
-- Hanya admin yang sudah login yang boleh membaca dan mengubah data.
alter table public.produk enable row level security;

drop policy if exists "admin_baca_produk" on public.produk;
drop policy if exists "admin_tambah_produk" on public.produk;
drop policy if exists "admin_ubah_produk" on public.produk;
drop policy if exists "admin_hapus_produk" on public.produk;

create policy "admin_baca_produk" on public.produk
  for select to authenticated using (true);

create policy "admin_tambah_produk" on public.produk
  for insert to authenticated with check (true);

create policy "admin_ubah_produk" on public.produk
  for update to authenticated using (true) with check (true);

create policy "admin_hapus_produk" on public.produk
  for delete to authenticated using (true);

-- 3. Data kreator awal (hanya diisi jika tabel masih kosong)
insert into public.produk (nama, harga, deskripsi, foto_url, kategori)
select * from (values
  ('Dapur Rani (@dapurrani)', 750000, 'Kreator resep rumahan. Reels dan TikTok masakan harian, audiens ibu rumah tangga. Tarif per 1 video.', '/produk/kopi.svg', 'Kuliner'),
  ('Camilan Bang Dodi (@camilandodi)', 500000, 'Review jajanan dan camilan lokal dengan gaya santai. Tarif per 1 video review.', '/produk/keripik.svg', 'Camilan'),
  ('Sambal Sis Tika (@sambaltika)', 600000, 'Konten kuliner pedas dan tantangan makan. Tarif per 1 video.', '/produk/sambal.svg', 'Kuliner pedas'),
  ('Bakery Mbak Lia (@bakerylia)', 900000, 'Tutorial kue dan roti untuk pemula. Tarif per 1 video tutorial.', '/produk/nastar.svg', 'Bakery'),
  ('Gaya Lokal Nadia (@gayalokalnadia)', 1200000, 'Fashion lokal dan thrift, foto OOTD dan video styling. Tarif per 1 paket konten.', '/produk/tas.svg', 'Fashion'),
  ('Kain Nusantara Bima (@kainbima)', 1500000, 'Edukasi batik dan tenun, audiens pecinta budaya. Tarif per 1 paket konten.', '/produk/batik.svg', 'Budaya')
) as data_awal (nama, harga, deskripsi, foto_url, kategori)
where not exists (select 1 from public.produk);

-- 4. Data tambahan untuk menguji paginasi, urutan, filter, dan pencarian (54 kreator fiktif).
--    Bersama data awal jadi 60 data, 10 per kategori, dengan tarif dan waktu dibuat berbeda.
--    Hanya diisi sekali; kalau tidak dibutuhkan, hapus dengan:
--    delete from public.produk where deskripsi like 'Contoh untuk uji paginasi%';
with kategori (urut, kategori, foto_url, harga_dasar, langkah, daftar) as (values
  (1, 'Kuliner', '/produk/kopi.svg', 400000, 60000, array[
    'Resep Praktis Wulan', 'Masak Hemat Anita', 'Jajan Pasar Rizal',
    'Kuliner Malam Fajar', 'Dapur Anak Kos Sinta', 'Seafood Bang Yudi',
    'Sarapan Sehat Dewi', 'Warung Nusantara Hasan', 'Menu Keluarga Tari']),
  (2, 'Camilan', '/produk/keripik.svg', 300000, 40000, array[
    'Ngemil Santai Putri', 'Review Snack Gilang', 'Cemilan Viral Maya',
    'Kriuk Kriuk Rendi', 'Jajanan SD Retro Nina', 'Snack Box Aldo',
    'Camilan Sehat Laras', 'Pedas Manis Bayu', 'Oleh-oleh Kita Sari']),
  (3, 'Kuliner pedas', '/produk/sambal.svg', 350000, 50000, array[
    'Level Pedas Arif', 'Sambal Lovers Citra', 'Cabai Rawit Doni',
    'Tantangan Pedas Eka', 'Bumbu Dapur Lestari', 'Pedas Gila Rama',
    'Sambal Nusantara Yeni', 'Mie Pedas Ilham', 'Seblak Squad Mira']),
  (4, 'Bakery', '/produk/nastar.svg', 500000, 70000, array[
    'Roti Rumahan Intan', 'Kue Kering Lebaran Ratna', 'Cake Dekor Vina',
    'Donat Empuk Teguh', 'Brownies Fudgy Salsa', 'Bolu Kukus Ayu',
    'Cookies Lover Kevin', 'Pastry Pemula Dinda', 'Sourdough Pagi Hendra']),
  (5, 'Fashion', '/produk/tas.svg', 600000, 90000, array[
    'OOTD Kampus Alya', 'Thrift Haul Reza', 'Hijab Style Nabila',
    'Streetwear Lokal Dimas', 'Mix and Match Fira', 'Outfit Kerja Clara',
    'Tas Lokal Review Mega', 'Sneakers Lokal Bagas', 'Fashion Pria Irfan']),
  (6, 'Budaya', '/produk/batik.svg', 700000, 100000, array[
    'Batik Harian Larasati', 'Tenun Nusantara Wahyu', 'Wastra Indonesia Sekar',
    'Kain Tradisi Jaya', 'Songket Story Ratih', 'Budaya Kita Danu',
    'Motif Batik Ayu', 'Jelajah Wastra Prima', 'Kebaya Modern Tiara'])
)
insert into public.produk (nama, harga, deskripsi, foto_url, kategori, created_at)
select
  p.nama,
  k.harga_dasar + p.ke * k.langkah,
  format('Contoh untuk uji paginasi, urutan, dan pencarian. Kreator %s nomor %s (data fiktif).', lower(k.kategori), p.ke),
  k.foto_url,
  k.kategori,
  now() - make_interval(hours => ((k.urut - 1) * 9 + p.ke)::int)
from kategori k
cross join lateral unnest(k.daftar) with ordinality as p (nama, ke)
where not exists (select 1 from public.produk where deskripsi like 'Contoh untuk uji paginasi%');
