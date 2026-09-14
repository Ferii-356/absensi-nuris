// Modul bersama: inisialisasi Firebase Admin + satu-satunya pengirim notifikasi.
// Dipakai oleh api/telegramBot.js (izin via Telegram) DAN api/notifIzin.js
// (izin via APK NurisGo) supaya format payload & pemerima selalu konsisten.
//
// Env yang dibutuhkan (set di Vercel):
//   - FIREBASE_SERVICE_ACCOUNT_BASE64 : service account project absensi-santri-nuris dalam base64
//   - NOTIF_SECRET                   : secret bersama dengan APK (untuk api/notifIzin)
const admin = require("firebase-admin");

// Pemerima notifikasi izin baru — harus konsisten dengan APK & rules.
const ROLE_PENERIMA = ["super_admin", "sekretaris", "pengabsen"];

const CHANNEL_ID = "izin_baru";
const SOUND_ANDROID = "notif_izin";
const SOUND_IOS = "notif_izin.mp3";

const LABEL_JENIS = {
  sakit: "Sakit",
  pulang: "Izin Pulang",
  lainnya: "Izin Lainnya",
};

function initAdmin() {
  if (!admin.apps.length) {
    const serviceAccount = JSON.parse(
      Buffer.from(
        process.env.FIREBASE_SERVICE_ACCOUNT_BASE64,
        "base64"
      ).toString("utf-8")
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  return admin;
}

// Kirim push FCM ke super_admin, sekretaris, dan pengabsen.
// `extraData` berisi data payload (type 'izin_baru', izinId, dst) supaya
// staf bisa langsung menuju layar Kelola Izin saat notif diketuk.
async function kirimNotifikasiPengurus(judul, isi, extraData = {}) {
  const db = admin.firestore();

  const query = await db
    .collection("users")
    .where("role", "in", ROLE_PENERIMA)
    .get();

  const tokens = query.docs
    .map((doc) => doc.data().fcm_token)
    .filter((token) => !!token);

  if (tokens.length === 0) return { sent: 0 };

  try {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: judul,
        body: isi,
        sound: SOUND_IOS,
      },
      android: {
        priority: "high",
        notification: {
          channelId: CHANNEL_ID,
          sound: SOUND_ANDROID,
          color: "#0D47A1",
        },
      },
      data: {
        type: "izin_baru",
        ...extraData,
      },
    });
    return { sent: tokens.length };
  } catch (error) {
    console.error("Gagal kirim notifikasi:", error);
    return { sent: 0, error: String(error || "") };
  }
}

function labelJenis(jenis) {
  return LABEL_JENIS[jenis] ?? "Izin";
}

module.exports = {
  admin,
  initAdmin,
  kirimNotifikasiPengurus,
  labelJenis,
  ROLE_PENERIMA,
  CHANNEL_ID,
  SOUND_ANDROID,
  SOUND_IOS,
};