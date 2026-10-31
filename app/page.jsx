"use client";

import { useState } from "react";
import { formatRupiah } from "@/lib/format";

// Data contoh DEMO untuk Tahap 1 Kerangka Tampilan
// Sesuai dengan prototype KreatorFlow.html
const DEMO_CAMPAIGNS = [
  {
    id: 1,
    nama: "Launching Produk Baru",
    platform: "TikTok",
    status: "Aktif",
    views: 320000,
    clicks: 1850,
    cpm: 10000,
    budget: 5000000,
    cta: "WhatsApp brand",
    periode: "1–31 Okt 2026",
    owner: "Anda",
    brief:
      "Video 30–60 detik yang memperkenalkan produk baru dan mengajak penonton membuka WhatsApp brand.",
  },
  {
    id: 2,
    nama: "Awareness Brand Gen Z",
    platform: "Instagram Reels",
    status: "Aktif",
    views: 145000,
    clicks: 960,
    cpm: 12000,
    budget: 3000000,
    cta: "Halaman produk",
    periode: "5 Okt–5 Nov 2026",
    owner: "Anda",
    brief:
      "Reels gaya hidup anak muda, tampilkan produk secara natural dan arahkan ke halaman produk.",
  },
  {
    id: 3,
    nama: "Promo Website Oktober",
    platform: "TikTok",
    status: "Review",
    views: 85000,
    clicks: 420,
    cpm: 10000,
    budget: 2000000,
    cta: "Website",
    periode: "15–31 Okt 2026",
    owner: "Anda",
    brief:
      "Konten promo diskon Oktober dengan ajakan kunjungi website.",
  },
];

const ROLES = [
  { id: "brand", label: "Brand" },
  { id: "creator", label: "Creator" },
  { id: "admin", label: "Admin" },
  { id: "panduan", label: "Panduan" },
];

const NAV = {
  brand: {
    label: "MENU BRAND",
    items: [
      { id: "dashboard", label: "Dashboard" },
      { id: "kampanye", label: "Kampanye" },
      { id: "creator", label: "Creator" },
      { id: "analitik", label: "Analitik" },
      { id: "pembayaran", label: "Pembayaran" },
    ],
  },
  creator: {
    label: "MENU CREATOR",
    items: [
      { id: "temukan", label: "Temukan kampanye" },
      { id: "saya", label: "Kampanye saya" },
      { id: "penghasilan", label: "Penghasilan" },
    ],
  },
  admin: {
    label: "MENU ADMIN",
    items: [
      { id: "validasi", label: "Validasi konten", badge: 2 },
      { id: "anomali", label: "Anomali traffic", badge: 3 },
      { id: "reward", label: "Persetujuan reward", badge: 1 },
    ],
  },
  panduan: {
    label: "PANDUAN",
    items: [
      { id: "peran", label: "Peran dan alur" },
      { id: "pelacakan", label: "Pelacakan CTA" },
      { id: "data", label: "Struktur data" },
      { id: "roadmap", label: "Status dan roadmap" },
    ],
  },
};

export default function KreatorFlowApp() {
  const [role, setRole] = useState("brand");
  const [activeTabs, setActiveTabs] = useState({
    brand: "dashboard",
    creator: "temukan",
    admin: "validasi",
    panduan: "peran",
  });

  const curTab = activeTabs[role];

  const handleRoleChange = (newRole) => {
    setRole(newRole);
  };

  const handleTabChange = (newTab) => {
    setActiveTabs((prev) => ({
      ...prev,
      [role]: newTab,
    }));
  };

  // Kalkulasi ringkasan performa brand (DEMO)
  const totalViews = DEMO_CAMPAIGNS.reduce((acc, c) => acc + c.views, 0);
  const totalClicks = DEMO_CAMPAIGNS.reduce((acc, c) => acc + c.clicks, 0);
  const totalBudget = DEMO_CAMPAIGNS.reduce((acc, c) => acc + c.budget, 0);
  const totalUsed = DEMO_CAMPAIGNS.reduce(
    (acc, c) => acc + (c.views / 1000) * c.cpm,
    0
  );
  const budgetPercent = totalBudget
    ? Math.round((totalUsed / totalBudget) * 100)
    : 0;
  const remainingBudget = Math.max(totalBudget - totalUsed, 0);
  const ctrOverall = totalViews
    ? ((totalClicks / totalViews) * 100).toFixed(2).replace(".", ",") + "%"
    : "0,00%";

  const formatK = (n) =>
    n >= 1000
      ? (n / 1000).toLocaleString("id-ID", { maximumFractionDigits: 1 }) + "K"
      : String(n);

  const getPillClass = (status) => {
    const map = {
      Aktif: "good",
      Review: "warn",
      Jeda: "neutral",
      Disetujui: "good",
      Ditahan: "warn",
      Ditolak: "bad",
      Baru: "bad",
      Diabaikan: "neutral",
      Menunggu: "warn",
    };
    return `pill ${map[status] || "neutral"}`;
  };

  return (
    <>
      {/* 1. TOP HEADER & ROLE SWITCHER */}
      <header className="top">
        <div className="wrap">
          <div className="brand">
            <svg
              width="30"
              height="30"
              viewBox="0 0 30 30"
              aria-hidden="true"
              className="shrink-0"
            >
              <rect width="30" height="30" rx="7" fill="var(--accent)" />
              <path
                d="M8 21V9m0 6 6-6m-6 6 6 6M19 21V12m4 9V9"
                stroke="var(--accent-ink)"
                strokeWidth="2.4"
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <span className="brand-name">KreatorFlow</span>
            <span className="tag">DEMO</span>
          </div>

          <p className="tagline">
            Performance Creator Marketplace. Satu platform untuk menghubungkan
            brand, creator, views, dan CTA.
          </p>

          <div className="seg" role="group" aria-label="Pilih peran">
            {ROLES.map((r) => {
              const isPressed = r.id === role;
              const isGuide = r.id === "panduan";
              return (
                <button
                  key={r.id}
                  type="button"
                  className={isGuide ? "guide" : ""}
                  aria-pressed={isPressed}
                  onClick={() => handleRoleChange(r.id)}
                >
                  {r.label}
                </button>
              );
            })}
          </div>
        </div>
      </header>

      {/* 2. MAIN APPLICATION SHELL */}
      <main className="wrap">
        <div className="shell">
          {/* SIDEBAR NAVIGATION */}
          <nav className="nav" aria-label={NAV[role].label}>
            <div className="eyebrow">{NAV[role].label}</div>

            {role === "creator" && (
              <div
                className="muted"
                style={{ padding: "0 12px 8px", fontSize: "12px" }}
              >
                Masuk sebagai:
                <br />
                <b style={{ color: "var(--ink)" }}>Dapur Rani</b>{" "}
                <span className="mono text-xs">@dapurrani</span>
              </div>
            )}

            {NAV[role].items.map((item) => {
              const isCurrent = item.id === curTab;
              return (
                <button
                  key={item.id}
                  type="button"
                  aria-current={isCurrent ? "page" : undefined}
                  onClick={() => handleTabChange(item.id)}
                >
                  <span>{item.label}</span>
                  {item.badge ? (
                    <span className="badge">{item.badge}</span>
                  ) : null}
                </button>
              );
            })}
          </nav>

          {/* MAIN WORKING CONTENT PANEL */}
          <section className="panel" id="panel">
            {/* VIEW: BRAND > DASHBOARD */}
            {role === "brand" && curTab === "dashboard" && (
              <>
                <div className="head">
                  <div className="row between">
                    <h1>Dashboard Brand</h1>
                    <span className="tag">DATA DEMO</span>
                  </div>
                  <p>Ringkasan performa seluruh kampanye brand Anda.</p>
                </div>

                {/* STAT STRIP */}
                <div className="strip">
                  <div>
                    <div className="eyebrow">Total views</div>
                    <div className="big">{formatK(totalViews)}</div>
                    <div className="sub">Gabungan kampanye</div>
                  </div>
                  <div>
                    <div className="eyebrow">CTA clicks</div>
                    <div className="big">
                      {totalClicks.toLocaleString("id-ID")}
                    </div>
                    <div className="sub">Klik tercatat demo</div>
                  </div>
                  <div>
                    <div className="eyebrow">Total anggaran</div>
                    <div className="big">{formatRupiah(totalBudget)}</div>
                    <div className="sub">Budget kampanye demo</div>
                  </div>
                  <div>
                    <div className="eyebrow">CTR keseluruhan</div>
                    <div className="big">{ctrOverall}</div>
                    <div className="sub">Klik ÷ views</div>
                  </div>
                </div>

                {/* BUDGET USAGE CARD */}
                <section className="card stack">
                  <div className="row between">
                    <h2>Ringkasan penggunaan budget</h2>
                    <span className="muted text-xs">
                      Estimasi biaya berdasarkan CPM (DEMO)
                    </span>
                  </div>
                  <div className="out-big">{formatRupiah(totalUsed)}</div>
                  <div
                    className="track"
                    role="img"
                    aria-label={`Budget terpakai ${budgetPercent} persen`}
                  >
                    <div
                      className={`fill ${budgetPercent > 100 ? "over" : ""}`}
                      style={{ width: `${Math.min(budgetPercent, 100)}%` }}
                    />
                  </div>
                  <div className="row between text-sm">
                    <span>
                      Terpakai: <b>{budgetPercent}%</b>
                    </span>
                    <span className="muted">
                      Sisa estimasi:{" "}
                      <b className="num">{formatRupiah(remainingBudget)}</b>
                    </span>
                  </div>
                </section>

                {/* CAMPAIGN LIST */}
                <section className="stack">
                  <div className="row between">
                    <h2>Kampanye terbaru</h2>
                    <button
                      type="button"
                      className="btn sm"
                      onClick={() => handleTabChange("kampanye")}
                    >
                      Lihat semua
                    </button>
                  </div>

                  <div className="list">
                    {DEMO_CAMPAIGNS.map((c) => (
                      <div key={c.id} className="crow">
                        <div>
                          <div className="row gap-2">
                            <b>{c.nama}</b>
                            <span className={getPillClass(c.status)}>
                              {c.status}
                            </span>
                          </div>
                          <div className="muted text-xs mt-1">
                            {c.platform} · {c.periode}
                          </div>
                        </div>

                        <div>
                          <div className="k">Views</div>
                          <div className="v">
                            {c.views.toLocaleString("id-ID")}
                          </div>
                        </div>

                        <div>
                          <div className="k">CTA clicks</div>
                          <div className="v">
                            {c.clicks.toLocaleString("id-ID")}
                          </div>
                        </div>

                        <div>
                          <div className="k">CPM</div>
                          <div className="v">{formatRupiah(c.cpm)}</div>
                        </div>

                        <div>
                          <button
                            type="button"
                            className="btn sm"
                            onClick={() => handleTabChange("analitik")}
                          >
                            Lihat analitik
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </section>

                {/* DEMO NOTICE CALLOUT */}
                <div className="note">
                  <b>Catatan prototype (DEMO).</b> Ini adalah tampilan kerangka
                  antarmuka interaktif Tahap 1. Data yang ditampilkan merupakan
                  simulasi tampilan dan belum terhubung ke database kampanye,
                  tracking URL, atau transaksi keuangan.
                </div>
              </>
            )}

            {/* VIEW: BRAND > OTHER TABS (PREVIEW KERANGKA) */}
            {role === "brand" && curTab !== "dashboard" && (
              <div className="card stack">
                <div className="row between">
                  <h2>
                    Menu Brand:{" "}
                    {NAV.brand.items.find((i) => i.id === curTab)?.label}
                  </h2>
                  <span className="pill accent">KERANGKA TAHAP 1</span>
                </div>
                <p className="muted">
                  Bagian ini disiapkan untuk tahap implementasi berikutnya sesuai
                  alur prototype KreatorFlow.
                </p>
                <div className="mt-4">
                  <button
                    type="button"
                    className="btn primary sm"
                    onClick={() => handleTabChange("dashboard")}
                  >
                    Kembali ke Dashboard Brand
                  </button>
                </div>
              </div>
            )}

            {/* VIEW: CREATOR (PREVIEW KERANGKA) */}
            {role === "creator" && (
              <div className="card stack">
                <div className="row between">
                  <h2>
                    Tampilan Creator:{" "}
                    {NAV.creator.items.find((i) => i.id === curTab)?.label}
                  </h2>
                  <span className="pill warn">KERANGKA TAHAP 1</span>
                </div>
                <p className="muted">
                  Peran Creator memungkinkan kreator konten menemukan kampanye,
                  mengirimkan tautan konten video, dan memantau estimasi reward.
                </p>
                <div className="note mt-2">
                  Navigasi antar menu Creator aktif dan siap dihubungkan pada tahap berikutnya.
                </div>
              </div>
            )}

            {/* VIEW: ADMIN (PREVIEW KERANGKA) */}
            {role === "admin" && (
              <div className="card stack">
                <div className="row between">
                  <h2>
                    Tampilan Admin:{" "}
                    {NAV.admin.items.find((i) => i.id === curTab)?.label}
                  </h2>
                  <span className="pill bad">KERANGKA TAHAP 1</span>
                </div>
                <p className="muted">
                  Peran Admin menjaga ekosistem dengan memvalidasi tautan konten,
                  meneliti anomali traffic bot/fraud, dan menyetujui reward
                  payout sebelum pencairan.
                </p>
                <div className="note mt-2">
                  Navigasi antrean validasi (2), anomali (3), dan persetujuan reward (1) aktif.
                </div>
              </div>
            )}

            {/* VIEW: PANDUAN */}
            {role === "panduan" && (
              <div className="stack">
                <div className="head">
                  <h1>Panduan Platform</h1>
                  <p>
                    KreatorFlow menghubungkan brand yang membayar berdasarkan
                    hasil dengan creator yang membuat konten.
                  </p>
                </div>

                <div className="grid2">
                  <article className="card stack">
                    <span
                      className="pill accent"
                      style={{ alignSelf: "flex-start" }}
                    >
                      A
                    </span>
                    <h3>Brand: pihak yang membayar</h3>
                    <p className="muted">
                      Membuat kampanye, menetapkan anggaran, memilih platform,
                      menentukan reward per 1.000 views, dan menyiapkan CTA ke
                      website atau kanal penjualan.
                    </p>
                  </article>

                  <article className="card stack">
                    <span
                      className="pill accent"
                      style={{ alignSelf: "flex-start" }}
                    >
                      B
                    </span>
                    <h3>Creator: pihak yang menghasilkan konten</h3>
                    <p className="muted">
                      Memilih kampanye, mengikuti brief, menerbitkan video,
                      mengirim tautan, lalu memantau views yang disetujui dan
                      reward yang diperoleh.
                    </p>
                  </article>

                  <article className="card stack">
                    <span
                      className="pill accent"
                      style={{ alignSelf: "flex-start" }}
                    >
                      C
                    </span>
                    <h3>Admin: pihak yang menjaga kepercayaan</h3>
                    <p className="muted">
                      Memvalidasi konten dan traffic, menangani indikasi
                      kecurangan, dan menyetujui reward sebelum pembayaran
                      dilakukan.
                    </p>
                  </article>
                </div>

                <section className="stack">
                  <h2>Alur bisnis dari awal sampai pembayaran</h2>
                  <ol className="steps">
                    <li>
                      <b>1. Brand membuat kampanye</b>
                      <span className="muted">
                        Menentukan brief, platform, budget, CPM, CTA, dan
                        periode.
                      </span>
                    </li>
                    <li>
                      <b>2. Creator bergabung</b>
                      <span className="muted">
                        Membaca syarat, memilih kampanye, lalu menyetujui
                        ketentuan.
                      </span>
                    </li>
                    <li>
                      <b>3. Creator menerbitkan video</b>
                      <span className="muted">
                        Video dipublikasikan di akun sosial dan tautan dikirim
                        ke sistem.
                      </span>
                    </li>
                    <li>
                      <b>4. Sistem mencatat performa</b>
                      <span className="muted">
                        Views dan klik CTA dikumpulkan berkala dengan waktu
                        pencatatan.
                      </span>
                    </li>
                    <li>
                      <b>5. Admin memvalidasi hasil</b>
                      <span className="muted">
                        Views mencurigakan atau traffic bot ditahan untuk
                        diperiksa.
                      </span>
                    </li>
                    <li>
                      <b>6. Reward disetujui</b>
                      <span className="muted">
                        Sistem menghitung biaya sesuai aturan dan mencatat saldo
                        payout.
                      </span>
                    </li>
                  </ol>
                </section>
              </div>
            )}
          </section>
        </div>
      </main>
    </>
  );
}
