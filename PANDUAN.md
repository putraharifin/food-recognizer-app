# Panduan Food Recognizer App (Submission Dicoding)

Paket ini berisi **kode sumber lengkap** (`lib/`, `pubspec.yaml`, `test/`, `assets/`).
Folder `android/` dan `ios/` **tidak disertakan** karena sudah ada di proyek Anda
(hasil `flutter create` dan FlutterFire CLI, termasuk `google-services.json`).

> Catatan jujur: kode ini ditulis tanpa Flutter SDK di lingkungan saya, jadi belum
> pernah di-build atau dijalankan. Jalankan `flutter analyze` dan uji di perangkat
> nyata, lalu kirim pesan error bila ada.

---

## 1. Menggabungkan ke proyek Anda

1. Buka proyek `food_recognizer_app` Anda.
2. Hapus `lib/` lama, lalu salin `lib/`, `test/`, dan `assets/` dari ZIP ini.
   (`lib/firebase_options.dart` sudah sama dengan milik Anda.)
3. Pasang dependensi, supaya versinya ter-pin otomatis:
   ```
   flutter pub add provider firebase_core firebase_storage image_picker image_cropper camera tflite_flutter image http path_provider
   ```
   Lalu pastikan `pubspec.yaml` punya:
   ```yaml
   flutter:
     uses-material-design: true
     assets:
       - assets/
   ```
4. **Labels:** salin labelmap model ke `assets/labels.csv` (satu label per baris;
   header `name` dan baris `__background__` ditangani otomatis).

## 2. Konfigurasi Android

`android/app/src/main/AndroidManifest.xml` (di luar `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```
Di dalam `<application>`:
```xml
<activity
    android:name="com.yalantis.ucrop.UCropActivity"
    android:screenOrientation="portrait"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
```
`INTERNET` wajib agar MealDB, Gemini, dan Firebase berjalan di build release.

iOS (`ios/Runner/Info.plist`): `NSCameraUsageDescription` dan `NSPhotoLibraryUsageDescription`.

## 3. Unggah model ke Firebase Cloud Storage (Kriteria 2 Advanced)

1. Firebase Console > **Storage** > Get started.
2. Buat folder `models` dan unggah model `.tflite` dengan nama **`food_classifier.tflite`**
   (path akhir: `models/food_classifier.tflite`).
3. Tab **Rules**: tempel isi `storage.rules`, lalu Publish.
4. Pada app, model diunduh dinamis saat pertama kali dibuka, disimpan lokal, dan
   hanya diunduh ulang bila versi di cloud berubah. Offline, versi lokal tetap dipakai.

Catatan: proyek Firebase baru bisa meminta paket **Blaze** untuk membuat bucket Storage.
Alternatifnya **Firebase Hosting** (kriteria memperbolehkan): hosting file model,
isi `AppConfig.modelHostingUrl` di `lib/core/app_config.dart` dengan URL-nya, dan sertakan
folder hosting di proyek. App akan memakai URL ini bila Storage gagal.

## 4. API Key Gemini (Kriteria 3 Advanced)

API Key **tidak disematkan** di kode. Jalankan dengan:
```
flutter run --dart-define=GEMINI_API_KEY=KUNCI_ANDA
```
Di Android Studio: Run > Edit Configurations > *Additional run args*.
Tanpa key, halaman hasil menampilkan pesan dan tombol "Coba Lagi", dan fitur lain tetap jalan.
Model Gemini diatur di `AppConfig.geminiModel` (default `gemini-2.5-flash`).

## 5. Struktur kode

| Lokasi | Fungsi |
|---|---|
| `main.dart` | Inisialisasi Firebase, orientasi portrait, `MultiProvider` |
| `providers/camera_provider.dart` | Kamera, camera stream, image picker, image cropper |
| `providers/classifier_provider.dart` | Status unduh/muat model, inferensi gambar dan frame |
| `providers/result_provider.dart` | Nutrisi (Gemini) dan referensi resep (MealDB) |
| `services/isolate_classifier.dart` | Isolate + LiteRT (decode, resize, inferensi) |
| `services/model_download_service.dart` | Unduh model dari Firebase Storage |
| `services/meal_db_service.dart`, `gemini_service.dart` | Web API |
| `ui/screens/` | Home, Camera, Result, Detail |

## 6. Pemetaan ke kriteria

**Kriteria 1 (4 poin):** image_picker (galeri/kamera), preview gambar di Home,
image_cropper ("Crop & Analyze"), dan identifikasi real-time lewat library `camera` (Camera Page).

**Kriteria 2 (4 poin):** model yang disediakan via `tflite_flutter` (LiteRT);
inferensi di **Isolate** terpisah (decode, resize, dan `run` semuanya off-UI-thread);
model diunduh dinamis dari Firebase Cloud Storage.

**Kriteria 3 (4 poin):** Result Page (foto, nama, confidence %), referensi MealDB
(`strMeal`, `strMealThumb`, bahan `strIngredientX`/`strMeasureX`, `strInstructions`) di Detail Page,
dan nutrisi dari Gemini (kalori, karbohidrat, lemak, serat, protein) dengan structured output.

## 7. Uji sebelum submit

1. Buka app: banner "Mengunduh model..." muncul lalu hilang saat model siap.
2. Pilih gambar > **Analyze**: Result Page muncul dengan nama dan persentase.
3. **Crop & Analyze**: cropper terbuka, hasil crop dianalisis.
4. Ikon kamera di App Bar: preview live, overlay hasil berubah sekitar tiap 0,7 detik.
5. Ketuk item Reference: Detail Page berisi bahan dan langkah.
6. Gunakan sampel gambar dari Dicoding untuk memastikan hasilnya masuk akal.

## 8. Mengirim submission

1. Pastikan proyek lengkap: `android/`, `ios/`, `google-services.json`, `firebase_options.dart`.
2. Pastikan aset tidak lebih dari 5 MB (model **tidak** ada di assets) dan tidak ada API Key di kode.
3. Hapus folder `build`, lalu jalankan `flutter clean`.
4. ZIP proyek (maks 25 MB) tanpa menjalankan atau build lagi setelah clean.
5. Kirim lewat platform Dicoding.

## 9. Pemecahan masalah

| Gejala | Penyebab / solusi |
|---|---|
| "Berkas label tidak ditemukan" | Belum ada `assets/labels.csv`, atau belum `flutter pub get` |
| "Gagal mengunduh model" | Berkas belum diunggah, path salah, atau Rules belum mengizinkan read |
| Nama makanan bergeser/salah | Jumlah label tidak sama dengan output model; periksa `labels.csv` |
| Cropper crash di Android | `UCropActivity` belum didaftarkan di manifest |
| Nutrisi error 400/403 | API Key salah atau belum diberikan lewat `--dart-define` |
| Nutrisi error 429 | Kuota Gemini habis; coba lagi nanti |
| Build error `tflite_flutter` | Pastikan `minSdk` sesuai syarat plugin dan jalankan `flutter clean` |
| Referensi kosong | MealDB tidak punya resep untuk makanan itu; app mencoba juga kata kunci terpisah |
