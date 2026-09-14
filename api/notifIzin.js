// Endpoint yang dipanggil APK NurisGo SETELAH berhasil menyimpan izin.
// Dipanggil lewat HTTP (bukan trigger), jadi TIDAK perlu paket Blaze.
//
// Body JSON:
//   { "izinId": "<id dokumen izin>", "secret": "<NOTIF_SECRET>" }
//
// Membaca ulang dokumen izin dari Firestore lalu mengirim notifikasi ke
// super_admin / sekretaris / pengabsen lewat _shared/notify.js.
const { admin, initAdmin, kirimNotifikasiPengurus, labelJenis } = require("../_shared/notify");

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "method not allowed" });
  }

  const { izinId, secret } = req.body || {};

  if (!secret || secret !== process.env.NOTIF_SECRET) {
    return res.status(401).json({ ok: false, error: "unauthorized" });
  }
  if (!izinId) {
    return res.status(400).json({ ok: false, error: "izinId required" });
  }

  try {
    initAdmin();
    const db = admin.firestore();

    const snap = await db.collection("izin").doc(izinId).get();
    if (!snap.exists) {
      return res.status(404).json({ ok: false, error: "izin not found" });
    }

    const d = snap.data();
    const jenis = d.jenisIzin || "lainnya";
    const isi = d.alasan
      ? `${labelJenis(jenis)} dari ${d.nama} — ${d.alasan}`
      : `${labelJenis(jenis)} dari ${d.nama}`;

    const result = await kirimNotifikasiPengurus("Izin Santri Baru", isi, {
      izinId,
      nis: d.nis || "",
      nama: d.nama || "",
      jenis,
      alasan: d.alasan || "",
      sumber: d.sumber || "apk",
    });

    return res.status(200).json({ ok: true, ...result });
  } catch (error) {
    console.error("Error notifIzin:", error);
    return res.status(500).json({ ok: false, error: String(error || "") });
  }
};