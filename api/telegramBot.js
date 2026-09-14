const { Telegraf } = require("telegraf");
const { admin, initAdmin, kirimNotifikasiPengurus, labelJenis } = require("../_shared/notify");

initAdmin();

const db = admin.firestore();
const bot = new Telegraf(process.env.TELEGRAM_BOT_TOKEN);

// Awal hari (00:00 lokal) — sama dengan tanggalAwalHari() di APK.
function awalHari(now) {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

// Cek apakah santri masih punya izin pending yang bertabrakan dengan rentang
// [mulai, selesai]. Aturan sama dengan APK (IzinService.ajukanIzin): satu izin
// aktif per santri, supaya jalur APK & Telegram konsisten.
async function cekIzinAktif(db, nis, mulai, selesai) {
  if (!nis) return false;
  const snap = await db
    .collection("izin")
    .where("nis", "==", nis)
    .where("status", "==", "pending")
    .get();
  const a = mulai.getTime();
  const b = selesai.getTime();
  return snap.docs.some((doc) => {
    const d = doc.data();
    if (!d.tanggalMulai || !d.tanggalSelesai) return false;
    const im = d.tanggalMulai.toDate().getTime();
    const ism = d.tanggalSelesai.toDate().getTime();
    return !(ism < a || im > b);
  });
}

bot.start((ctx) => {
  ctx.reply(
    "Assalamu'alaikum! 👋\n\n" +
    "Bot ini dipakai untuk mengirim izin absensi ke pengurus PPPM Nuris.\n\n" +
    "Langkah pertama, daftarkan dirimu dulu dengan perintah:\n" +
    "/daftar NIM_KAMU\n\n" +
    "Contoh: /daftar 240299"
  );
});

bot.command("daftar", async (ctx) => {
  const teks = ctx.message.text.split(" ");
  const nim = teks[1];

  if (!nim) {
    return ctx.reply("Format salah. Contoh: /daftar 240299");
  }

  const chatId = ctx.chat.id.toString();

  const query = await db
    .collection("santri")
    .where("nim", "==", nim)
    .limit(1)
    .get();

  if (query.empty) {
    return ctx.reply(
      `NIM "${nim}" tidak ditemukan di data santri. ` +
      `Periksa kembali NIM kamu, atau hubungi pengurus.`
    );
  }

  // Lepas chat_id ini dari santri lain (kalau sebelumnya pernah dipakai daftar santri berbeda)
  const santriLain = await db
    .collection("santri")
    .where("telegram_chat_id", "==", chatId)
    .get();

  for (const doc of santriLain.docs) {
    await doc.ref.update({ telegram_chat_id: admin.firestore.FieldValue.delete() });
  }

  const santriDoc = query.docs[0];
  const santriData = santriDoc.data();

  await santriDoc.ref.update({ telegram_chat_id: chatId });

  return ctx.reply(
    `Berhasil terdaftar sebagai ${santriData.nama}.\n\n` +
    `Sekarang kamu bisa kirim izin dengan perintah:\n` +
    `/izin alasan_kamu\n\n` +
    `Contoh: /izin Sakit demam, tidak bisa mengikuti kegiatan malam ini`
  );
});

bot.command("izin", async (ctx) => {
  const teksLengkap = ctx.message.text;
  const alasan = teksLengkap.replace(/^\/izin(@\S+)?\s*/i, "").trim();

  if (!alasan) {
    return ctx.reply("Format salah. Contoh: /izin Sakit demam, tidak bisa ikut asrama");
  }

  const chatId = ctx.chat.id.toString();

  const query = await db
    .collection("santri")
    .where("telegram_chat_id", "==", chatId)
    .limit(1)
    .get();

  if (query.empty) {
    return ctx.reply(
      "Kamu belum terdaftar. Daftar dulu dengan perintah:\n" +
      "/daftar NIM_KAMU"
    );
  }

  const santriDoc = query.docs[0];
  const santriData = santriDoc.data();

  // Simpan state sementara ke Firestore karena Vercel itu serverless (stateless)
  const pendingRef = await db.collection("pending_izin").add({
    chat_id: chatId,
    santri_id: santriDoc.id,
    santri_data: santriData,
    alasan: alasan,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const docId = pendingRef.id;

  return ctx.reply(
    `📋 *Pilih sesi yang ingin kamu izinkan:*\n\nAlasan: "${alasan}"`,
    {
      parse_mode: "Markdown",
      reply_markup: {
        inline_keyboard: [
          [
            { text: "🌅 Maghrib", callback_data: `izin_sesi:maghrib:${docId}` },
            { text: "🌙 Isya", callback_data: `izin_sesi:isya:${docId}` },
            { text: "⭐ Subuh", callback_data: `izin_sesi:subuh:${docId}` },
          ],
        ],
      },
    }
  );
});

bot.action(/^izin_sesi:(maghrib|isya|subuh):(.+)$/, async (ctx) => {
  try {
    const sesi = ctx.match[1];
    const docId = ctx.match[2];

    const pendingDoc = await db.collection("pending_izin").doc(docId).get();
    if (!pendingDoc.exists) {
      await ctx.answerCbQuery();
      return ctx.reply("Data izin sudah kadaluarsa atau tidak ditemukan. Silakan kirim ulang /izin.");
    }

    const data = pendingDoc.data();
    const tanggal = awalHari(new Date());
    const nim = data.santri_data.nim || "";

    // Tolak bila santri masih punya izin pending yang bertabrakan (satu izin
    // aktif per santri, sejalan dengan layanan di APK).
    if (await cekIzinAktif(db, nim, tanggal, tanggal)) {
      await pendingDoc.ref.delete();
      await ctx.answerCbQuery("Masih ada izin pending.");
      return ctx.editMessageText(
        "Maaf, kamu masih punya izin pending yang belum diproses pengurus.\n" +
        "Silakan tunggu sampai izinmu diproses sebelum mengajukan izin baru."
      );
    }

    // Simpan ke collection izin utama — format SAMA dengan yang ditulis
    // APK (lib/models/izin_model.dart) supaya muncul di Kelola Izin,
    // bisa disetujui/ditolak, masuk riwayat santri, dan laporan.
    const izinRef = await db.collection("izin").add({
      nis: nim,
      nama: data.santri_data.nama || "",
      kelasId: data.santri_data.kelas_id || "",
      jenisIzin: "lainnya",
      tanggalMulai: admin.firestore.Timestamp.fromDate(tanggal),
      tanggalSelesai: admin.firestore.Timestamp.fromDate(tanggal),
      alasan: data.alasan || "",
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      // Info tambahan khas Telegram (tidak dipakai APK, aman untuk dibiarkan)
      santri_id: data.santri_id,
      sesi: sesi,
      sumber: "telegram",
    });

    // Hapus data sementara
    await pendingDoc.ref.delete();

    // Notifikasi via pengirim tunggal (sama seperti api/notifIzin untuk APK)
    const isi = `${labelJenis("lainnya")} dari ${data.santri_data.nama} — ${data.alasan}`;
    await kirimNotifikasiPengurus("Izin Santri Baru", isi, {
      izinId: izinRef.id,
      nis: data.santri_data.nim || "",
      nama: data.santri_data.nama || "",
      jenis: "lainnya",
      alasan: data.alasan || "",
      sumber: "telegram",
    });

    const labelSesi = sesi.charAt(0).toUpperCase() + sesi.slice(1);
    await ctx.editMessageText(
      `✅ Izin kamu sudah dicatat, ${data.santri_data.nama}.\n` +
      `Sesi: *${labelSesi}*\n` +
      `Alasan: "${data.alasan}"\n\n` +
      `Semoga lekas membaik / urusan lancar. 🙏`,
      { parse_mode: "Markdown" }
    );

    return ctx.answerCbQuery("Izin berhasil dicatat!");
  } catch (error) {
    console.error("Error action izin_sesi:", error);
    await ctx.answerCbQuery("Terjadi kesalahan.");
    return ctx.reply("Gagal memproses izin. Silakan coba lagi nanti.");
  }
});

bot.on("text", (ctx) => {
  ctx.reply(
    "Perintah tidak dikenali. Gunakan:\n" +
    "/daftar NIM - untuk mendaftar\n" +
    "/izin alasan - untuk mengirim izin"
  );
});

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return res.status(200).send("Bot izin absensi santri aktif.");
  }

  try {
    await bot.handleUpdate(req.body, res);
  } catch (error) {
    console.error("Error handling update:", error);
    res.status(500).send("Error");
  }
};