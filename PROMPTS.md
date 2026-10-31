# Jurnal Prompt KreatorFlow

Jurnal ini mencatat proses pengembangan aplikasi KreatorFlow, mulai dari integrasi awal database, perubahan tampilan, hingga pemeriksaan dan perbaikan.

Keterangan:
- [DARI PANDUAN] Prompt berdasarkan instruksi worksheet.
- [DIBANTU ASISTEN] Prompt disusun dengan bantuan ChatGPT.
- [SENDIRI] Prompt yang ditulis sendiri oleh pembuat aplikasi.

## US-01 Katalog dari database

**Prompt:**

[DIBANTU ASISTEN] Hubungkan halaman aplikasi dengan database Supabase menggunakan environment variable yang sudah tersedia. Ambil data dari tabel produk dan tampilkan pada halaman utama.

**Hasil:**

Aplikasi berhasil mengambil dan menampilkan data dari tabel `produk` di Supabase. Perubahan data produk pada database juga berhasil ditampilkan pada aplikasi lokal.

**Perbaikan:**

Dilakukan pemeriksaan koneksi Supabase, konfigurasi environment variable, dan proses pengambilan data.

**Catatan pengembangan:**

Integrasi awal US-01 berhasil diuji pada template Katalog UMKM. Selanjutnya proyek dikembangkan menjadi KreatorFlow sehingga tampilan katalog lama tidak lagi menjadi tampilan utama.

## US-02 Detail produk

**Prompt:**

Belum dikerjakan sebagai fitur detail produk karena pengembangan diarahkan menjadi platform KreatorFlow.

**Hasil:**

Belum diimplementasikan.

**Perbaikan:**

Tidak ada. Fitur ini tidak dilanjutkan pada pengembangan KreatorFlow.

## US-03 Pesan via WhatsApp

**Prompt:**

Belum dikerjakan sebagai fitur pemesanan WhatsApp karena pengembangan diarahkan menjadi platform KreatorFlow.

**Hasil:**

Belum diimplementasikan.

**Perbaikan:**

Tidak ada.

## US-04 Login admin

**Prompt:**

Belum diimplementasikan sebagai fitur autentikasi Admin pada KreatorFlow.

**Hasil:**

Aplikasi saat ini masih menggunakan pemilihan tampilan peran Brand, Creator, dan Admin untuk keperluan demonstrasi.

**Perbaikan:**

Belum ada autentikasi pengguna yang sebenarnya.

## US-05 Ganti password

**Prompt:**

Belum dikerjakan karena fitur autentikasi pengguna KreatorFlow belum diimplementasikan.

**Hasil:**

Belum tersedia.

**Perbaikan:**

Menjadi bagian pengembangan lanjutan.

## US-06 Proteksi halaman admin

**Prompt:**

Belum diimplementasikan sebagai proteksi halaman Admin yang menggunakan autentikasi sebenarnya.

**Hasil:**

Menu Admin sudah tersedia sebagai tampilan demonstrasi, tetapi belum menggunakan pembatasan akses berbasis login dan role.

**Perbaikan:**

Belum tersedia.

## Debugging dan Pengembangan KreatorFlow

### 1. Perubahan identitas aplikasi

**Prompt:**

[DIBANTU ASISTEN] Ubah identitas template Katalog UMKM menjadi KreatorFlow, yaitu platform Performance Creator Marketplace yang menghubungkan Brand, Creator, dan Admin.

**Hasil:**

Identitas aplikasi, nama, tagline, dan tampilan utama berhasil disesuaikan menjadi KreatorFlow.

### 2. Pengembangan tampilan dashboard

**Prompt:**

[DIBANTU ASISTEN] Buat tampilan dashboard KreatorFlow dengan tiga peran pengguna, yaitu Brand, Creator, dan Admin, serta halaman Panduan. Gunakan data DEMO dan jangan mengubah konfigurasi database atau autentikasi.

**Hasil:**

Dashboard Brand, Creator, Admin, dan Panduan berhasil ditampilkan. Navigasi antarperan dan menu utama dapat dibuka.

**Perbaikan:**

Ditemukan deklarasi `export default` yang ganda pada halaman utama dan kemudian diperbaiki hingga hanya tersisa satu deklarasi.

### 3. Penyusunan skema database KreatorFlow

**Prompt:**

[DIBANTU ASISTEN] Susun skema database PostgreSQL untuk KreatorFlow yang mencakup profil pengguna, Brand, Creator, kampanye, keikutsertaan kampanye, submission konten, tracking link, CTA clicks, anomali traffic, dan payout.

**Hasil:**

File `docs/schema-kreatorflow.sql` berhasil dibuat dengan rancangan 10 tabel dan kebijakan keamanan RLS.

**Perbaikan:**

Dilakukan pemeriksaan keamanan terhadap akses data, role pengguna, data finansial, tracking link, dan validasi reward. File SQL revisi masih memerlukan perbaikan sintaks dan belum diterapkan ke Supabase.

### 4. Deployment ke Vercel

**Prompt:**

[DIBANTU ASISTEN] Kirim perubahan proyek ke GitHub agar Vercel melakukan deployment otomatis.

**Hasil:**

Perubahan berhasil di-commit dan di-push ke repository GitHub. Deployment Production Vercel berhasil dan website menampilkan dashboard KreatorFlow.

**Perbaikan:**

Dilakukan pemeriksaan deployment dan pengujian tampilan melalui link publik Vercel.

## Status Akhir Pengembangan

KreatorFlow telah memiliki tampilan