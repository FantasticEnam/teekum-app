# Volume 02: Model Biner, Tipe Kawat & Entitas Domain Sesi (Meepo)

## 1. Ringkasan Eksekutif & Arsitektur Kawat 56-Bita

Volume 02 mendefinisikan kontrak serialisasi biner inti, format transmisi kawat tingkat bita, wadah kriptografis, dan entitas domain sesi dari klien jaringan mesh Meepo. Di lingkungan zona bencana luar-jaringan (*off-grid*) yang parah, spektrum radio nirkabel sangat terbatas, MTU Bluetooth Low Energy (BLE) dan Wi-Fi Direct sangat terbatas, serta perangkat beroperasi di bawah batasan daya baterai yang ketat. Untuk mengatasi realitas fisik yang keras ini, Meepo meninggalkan protokol serialisasi teks biasa dengan panjang variabel (seperti JSON atau Protobuf) dan sebaliknya menerapkan **frame transmisi kawat 56-bita** yang mutlak invarian.

Setiap datagram yang melintasi radio mesh mematuhi tata letak fisik tiga segmen yang tidak dapat diubah:
1. **Amplop Perutean Teks-Terbuka (Bita 0..9, 10 Bita):** Membawa metadata perutean yang tidak dienkripsi—versi protokol (`0x03`), opcode paket (`PacketType`), jumlah hop (`0..7`), ID sesi 24-bit, dan nomor urut terpartisi bit. Hal ini memungkinkan radio rekan (*peer*) perantara untuk memeriksa dan meneruskan paket tanpa memegang kunci kriptografi atau mendekripsi muatan.
2. **Muatan Ciphertext Tersegel (Bita 10..39, 30 Bita):** Dienkripsi menggunakan *stream cipher* ChaCha20 dengan kunci sesi simetris 256-bit. Semua fitur tingkat tinggi—ping lokasi, pesan obrolan, pembaruan titik kumpul, penemuan rute, dan peringatan darurat SOS—mengemas status terserialisasi mereka ke dalam wadah 30-bita yang identik ini.
3. **Tag Otentikasi MAC Poly1305 (Bita 40..55, 16 Bita):** Tag otentikasi 128-bit berkecepatan tinggi dan berkeamanan kriptografis kuat yang dihitung atas amplop yang tidak dienkripsi (Authenticated Associated Data, atau AAD) dan muatan *ciphertext*. Modifikasi fisik apa pun pada frame atau kerusakan bita radio menyebabkan kegagalan verifikasi seketika dan pembuangan paket secara senyap (*silent drop*).

```
+---------------------------------------------------------------------------------------+
|                                Datagram Fisik 56-Bita                                 |
+--------------------------+-----------------------------------+------------------------+
| Bita 0..9 (10 Bita)      | Bita 10..39 (30 Bita)             | Bita 40..55 (16 Bita)  |
| Tajuk Perutean Cleartext | Muatan Ciphertext Tersegel        | Tag MAC Poly1305       |
| (AAD Tidak Dienkripsi)   | (Dienkripsi ChaCha20)             | (Tag Otentikasi)       |
+--------------------------+-----------------------------------+------------------------+
```

---

### Analogi Kawat Bahasa Awam (ELI5): Kantong Diplomatik Bersegel

Bayangkan sebuah zona bencana dahsyat—seperti lapangan puing gempa bumi, cekungan sungai yang banjir, atau jaringan kota yang padam listrik total—di mana menara seluler dan gardu induk listrik hancur lebur. Sebuah Tim Tanggap Darurat Komunitas (CERT) dan regu pencarian dan pertolongan (SAR) relawan dikerahkan melintasi blok-blok yang runtuh untuk menemukan korban selamat, menandai zona bahaya, dan mengoordinasikan triase medis. Karena jangkauan radio langsung melalui puing beton sangat terbatas, para petugas menyampaikan pesan darurat digital dari perangkat ke perangkat melintasi mesh ad-hoc.

Untuk menjaga komunikasi Anda tetap aman dan efisien, kelompok Anda menggunakan kantong diplomatik logam terstandarisasi yang identik:
1. **Label Alamat Transparan Teks-Terbuka (Bita 0..9):** Ditempel di bagian luar kantong berupa kartu transparan kecil yang mencantumkan:
   - Versi sistem kantong yang Anda gunakan (Versi 3).
   - Jenis surat apa yang ada di dalamnya (misalnya Obrolan, Ping Lokasi, atau SOS Darurat).
   - Penghitung langkah (Hop Count) yang dimulai dari 0. Setiap petugas relai yang meneruskan kantong menambahkan 1 ke penghitung ini. Jika penghitung mencapai 7, kantong dipensiunkan agar tidak berputar-putar di reruntuhan selamanya.
   - ID regu penyelamat Anda (Session ID) dan nomor pesan (Sequence Number).
2. **Brankas Baja Terkunci Berat (Bita 10..39):** Di dalam kantong terdapat kotak kunci baja lapis baja yang hanya dapat dibuka dengan kunci simetris 256-bit privat milik regu penyelamat Anda. Orang asing atau relawan perantara yang meneruskan kantong melalui reruntuhan tidak dapat membuka kotak kunci atau memeriksa detail korban; mereka hanya tahu nomor ID sesi kepemilikannya dan ke mana harus meneruskannya.
3. **Segel Lilin Anti-Perusakan (Bita 40..55):** Sebelum mengirim kantong, Anda memasang segel lilin yang tidak dapat dipecahkan yang dicap dengan kode matematis unik (Poly1305 MAC). Ketika rekan tim Anda menerima kantong tersebut, mereka memverifikasi segel terhadap kunci regu mereka. Jika seseorang merusak label alamat atau menggores kotak kunci logam, segel akan pecah dan penerima langsung membuang paket yang rusak tersebut.

---

### Invarian Kawat Kriptografis Kritis

Arsitektur kawat Meepo memberlakukan lima invarian rekayasa sistem yang tidak dapat ditawar:

1. **Invariansi Datagram 56-Bita yang Ketat:**
   Setiap paket yang ditransmisikan di seluruh 8 opcode protokol diberi bantalan (*padding*) atau dipotong tepat 56 bita. Hal ini mencegah penyadap yang dilengkapi penganalisis paket radio (RF sniffer) mengklasifikasikan lalu lintas berdasarkan panjang datagram (misalnya membedakan antara siaran darurat SOS, suar lokasi, atau pesan teks).
2. **Invarian Penopengan AAD Hop Count:**
   Dalam penerusan mesh perantara, node relai harus menaikkan nilai bita `hopCount` (Bita 2) untuk melacak jarak transmisi dan mencegah perulangan tak terbatas. Jika Bita 2 disertakan dalam kalkulasi MAC Poly1305, tag otentikasi pengirim akan rusak pada lompatan (*hop*) relai pertama. Untuk mengatasi hal ini, `CleartextEnvelope.authenticatedAssociatedData()` secara ketat menopeng Bita 2 menjadi `0x00` selama enkripsi dan dekripsi. Relai dapat menaikkan jumlah hop pada kawat sementara tag MAC Poly1305 tetap 100% valid.
3. **Pemisahan Bit Nomor Urut (*Sequence Number Bit Partitioning*):**
   Nomor urut 32-bit (`UInt32`) dibagi menjadi:
   - 8 bit atas (`sequenceNumber >> 24`): `memberSlot` pengirim ($0..255$).
   - 24 bit bawah (`sequenceNumber & 0x00FFFFFF`): Penghitung urutan paket monotonik ($0..16.777.215$).
   Pemisahan ini menjamin bahwa hingga 256 anggota kelompok memelihara penghitung urutan yang sepenuhnya independen, menghilangkan tabrakan deteksi putar ulang (*replay collision*) antar pengirim simultan.
4. **Penyusunan Nonce AEAD 12-Bita:**
   Cipher AEAD ChaCha20-Poly1305 memerlukan *nonce* 12-bita (96-bit) yang TIDAK PERNAH boleh berulang di bawah kunci simetris yang sama. Meepo secara deterministik menyusun *nonce* ini dari metadata kawat:
   - Bita 0..2 (3 bita): `sessionId` 24-bit.
   - Bita 3..6 (4 bita): `sequenceNumber` big-endian 32-bit.
   - Bita 7 (1 bita): `0x30 | opcode` (menggabungkan protokol versi 3 dan jenis paket).
   - Bita 8..11 (4 bita): Tag domain ASCII statis `[0x54, 0x4B, 0x4D, 0x33]` (`"TKM3"`).
5. **Kuantisasi Geografis Titik-Tetap (*Fixed-Point*):**
   Untuk mengemas koordinat GPS desimal menjadi bidang integer yang ringkas, koordinat dikalikan dengan $10^7$ (`10_000_000.0`) dan disimpan sebagai integer 32-bit bertanda (*signed 32-bit integer*) big-endian (`Int32`). Ini memberikan resolusi geografis sekitar 1,1 sentimeter di seluruh dunia dengan hanya membutuhkan 8 bita total untuk garis lintang dan garis bujur.

---

## Berkas Sumber yang Disertakan

Tabel berikut merinci setiap berkas kode sumber yang ditetapkan untuk Volume 02. Setiap jalur berkas ditautkan relatif terhadap dokumen ini, disertai dengan kategorinya, jumlah baris yang diverifikasi (`wc -l`), dan peran arsitektural tunggalnya:

| Jalur Berkas | Kategori | Jumlah Baris (`wc -l`) | Tujuan & Tanggung Jawab Arsitektural |
| :--- | :--- | :---: | :--- |
| [MeepoConfiguration.swift](../../Teekum/Teekum/Core/Configuration/MeepoConfiguration.swift) | Konfigurasi | 199 | Repositori konfigurasi utama yang menyatukan ambang batas jaringan, batas hop, jeda coba ulang, batas baterai, dan waktu UI. |
| [PacketConstants.swift](../../Teekum/Teekum/Core/Packets/PacketConstants.swift) | Protokol Kawat | 67 | Invarian kawat jaringan yang mendefinisikan datagram tetap 56-bita, amplop 10-bita, topeng ID sesi 24-bit, dan tag domain. |
| [CleartextEnvelope.swift](../../Teekum/Teekum/Core/Packets/CleartextEnvelope.swift) | Protokol Kawat | 178 | Tajuk kawat tidak terenkripsi 10-bita yang membawa versi protokol, opcode paket, batas hop, ID sesi, dan nomor urut terpartisi. |
| [RawWirePacket.swift](../../Teekum/Teekum/Core/Packets/RawWirePacket.swift) | Protokol Kawat | 54 | Wadah datagram kawat kanonik 56-bita yang mengikat CleartextEnvelope 10-bita, ciphertext 30-bita, dan tag otentikasi Poly1305 16-bita. |
| [PacketType.swift](../../Teekum/Teekum/Core/Packets/PacketType.swift) | Protokol Kawat | 19 | Enumerasi opcode paket kawat yang mendefinisikan 8 tipe datagram aktif (0x01 hingga 0x08) dan serialisasi opcode. |
| [PacketCodecError.swift](../../Teekum/Teekum/Core/Packets/PacketCodecError.swift) | Protokol Kawat | 55 | Domain galat serialisasi dan deserialisasi yang mencakup underflow buffer, jumlah hop tidak valid, dan opcode tidak dikenal. |
| [ACKStatus.swift](../../Teekum/Teekum/Core/Packets/ACKStatus.swift) | Muatan Biner | 13 | Enumerasi status konfirmasi pengiriman yang mengklasifikasikan hasil tanda terima (delivered, timedOut, failed). |
| [ACKPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ACKPayload.swift) | Muatan Biner | 93 | Muatan biner 30-bita yang mengonfirmasi penerimaan pesan dengan inisial penerima, penghitung urutan, dan stempel waktu milidetik. |
| [AttendanceStatus.swift](../../Teekum/Teekum/Core/Packets/Payloads/AttendanceStatus.swift) | Muatan Biner | 22 | Enumerasi status kehadiran titik kumpul (attending, declined, pending) untuk sinkronisasi titik temu. |
| [ChatMessagePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ChatMessagePayload.swift) | Muatan Biner | 146 | Muatan biner 30-bita yang mengemas inisial pengirim, penghitung urutan, dan hingga 20 bita teks UTF-8 dengan pemotongan batas karakter. |
| [LocationPingPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/LocationPingPayload.swift) | Muatan Biner | 106 | Muatan biner 30-bita yang mengemas lintang/bujur terkuantisasi (Int32), akurasi horizontal, status baterai, dan inisial pengirim. |
| [MeetingAction.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingAction.swift) | Muatan Biner | 15 | Enumerasi tindakan mutasi titik kumpul (propose, update, cancel) yang mengatur siklus hidup titik temu. |
| [MeetingUpdatePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingUpdatePayload.swift) | Muatan Biner | 147 | Muatan biner 30-bita yang menyandikan koordinat GPS titik temu, waktu target epoch, slot pembuat, dan opcode tindakan. |
| [RouteReqPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteReqPayload.swift) | Muatan Biner | 59 | Muatan biner 30-bita untuk penemuan rute AODV yang membawa inisial target, urutan inisiator, dan metrik akumulasi. |
| [RouteRespPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteRespPayload.swift) | Muatan Biner | 59 | Muatan biner 30-bita untuk balasan rute AODV yang membangun jalur kembali dengan urutan tujuan dan jumlah hop. |
| [SOSPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSPayload.swift) | Muatan Biner | 103 | Muatan biner 30-bita yang menyiarkan peringatan darurat bahaya dengan koordinat GPS, akurasi horizontal, dan inisial pengirim. |
| [SOSResolvedPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSResolvedPayload.swift) | Muatan Biner | 41 | Muatan biner 30-bita yang menyiarkan pembatalan dan resolusi dari keadaan darurat SOS yang aktif. |
| [SOSType.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSType.swift) | Muatan Biner | 27 | Enumerasi klasifikasi peringatan darurat yang membedakan usapan SOS pengguna manual dari pemicu ketidakaktifan otomatis. |
| [GroupSession.swift](../../Teekum/Teekum/Core/Session/GroupSession.swift) | Model Domain Sesi | 185 | Model domain inti yang mewakili grup mesh zona bencana aktif dengan ID sesi 24-bit, kunci simetris, dan profil anggota lokal. |
| [GroupSessionInvite.swift](../../Teekum/Teekum/Core/Session/GroupSessionInvite.swift) | Model Domain Sesi | 22 | Tipe nilai yang mewakili kredensial undangan dan muatan kode QR yang berisi ID sesi, sidik jari kunci, dan nama grup. |
| [MeetingAttendance.swift](../../Teekum/Teekum/Core/Session/MeetingAttendance.swift) | Model Domain Sesi | 34 | Model domain yang melacak RSVP kehadiran anggota dan status kedatangan untuk titik temu kelompok yang aktif. |
| [MeetingPoint.swift](../../Teekum/Teekum/Core/Session/MeetingPoint.swift) | Model Domain Sesi | 66 | Model domain yang mewakili titik temu kelompok dengan koordinat GPS, waktu pertemuan terjadwal, dan kepemilikan kunci pembuat (*setter lock*). |
| [Member.swift](../../Teekum/Teekum/Core/Session/Member.swift) | Model Domain Sesi | 136 | Model domain yang mewakili rekan kelompok zona bencana, termasuk telemetri, koordinat GPS terbaru, arah hadap, dan status keterjangkauan. |
| [MemberColor.swift](../../Teekum/Teekum/Core/Session/MemberColor.swift) | Model Domain Sesi | 84 | Enum domain yang mendefinisikan 8 warna identitas anggota yang dapat dipilih dengan serialisasi hex dan jembatan warna SwiftUI. |
| [MemberID.swift](../../Teekum/Teekum/Core/Session/MemberID.swift) | Model Domain Sesi | 41 | Tipe nilai pengenal anggota ringkas yang mengikat 1 hingga 3 karakter inisial dengan slot anggota terpartisi. |
| [SessionHolder.swift](../../Teekum/Teekum/Core/Session/SessionHolder.swift) | Model Domain Sesi | 19 | Wadah yang dapat diamati yang memegang instans GroupSession aktif untuk observasi tampilan SwiftUI yang reaktif. |
| [SessionPersistence.swift](../../Teekum/Teekum/Core/Session/SessionPersistence.swift) | Model Domain Sesi | 43 | Aktor yang mengelola persistensi disk yang aman untuk kredensial sesi grup aktif dan metadata peserta. |
| [SessionRecord.swift](../../Teekum/Teekum/Core/Session/SessionRecord.swift) | Model Domain Sesi | 33 | Skema persistensi Codable yang digunakan untuk membuat serialisasi dan memulihkan status sesi aktif di seluruh restart aplikasi. |
| [SessionStore.swift](../../Teekum/Teekum/Core/Session/SessionStore.swift) | Model Domain Sesi | 192 | Penyimpanan status terpusat yang dapat diamati yang melacak daftar peserta, titik temu aktif, peristiwa kehilangan kontak, dan kehadiran. |
| **Total Artefak Volume 02** | **29 Berkas** | **2258** | **100% Akuntansi Basis Kode Volume 02** |

---

## Diagram Tata Letak Bita ASCII & Serialisasi

Diagram ASCII berikut merinci tata letak bit dan bita fisik untuk datagram kawat 56-bita, amplop perutean teks-terbuka, *nonce* kriptografi, dan semua jenis muatan biner aktif.

### 1. Frame Datagram Fisik 56-Bita (`RawWirePacket`)

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Cleartext Routing Envelope                    |
|                     (Bita 0..3: 4 Bita)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                 Cleartext Routing Envelope                    |
|                     (Bita 4..7: 4 Bita)                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Envelope (8..9)               |   Sealed Ciphertext Payload   |
| (Bita 8..9: 2 Bita)           |    (Bita 10..11: 2 Bita)      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Sealed Ciphertext Payload                   |
|                    (Bita 12..39: 28 Bita)                     |
|                   [Aliran Terenkripsi ChaCha20]               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                   Poly1305 Authentication Tag                 |
|                    (Bita 40..55: 16 Bita)                     |
|                     [MAC Kriptografis 128-Bit]                |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 2. Amplop Perutean Teks-Terbuka 10-Bita (`CleartextEnvelope`)

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Vers  | Opcode|   Hop Count   |           Session ID          |
| (4b)  |  (4b) | (8 bit: 0..7) |           (Bita 2..3)         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Session ID (4)|  Member Slot  |   Monotonic Sequence Counter  |
|   (Bita 4)    |  (8 bit: 0)   |          (Bita 6..7)          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Counter (8)   | Cadangan / Pad|
|   (Bita 8)    |   (Bita 9)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

Bita 0:     [ Versi: 4 bit (0x03) | PacketType Opcode: 4 bit (0x01..0x08) ]
Bita 1:     [ Hop Count: 8 bit (0..7, ditopeng AAD menjadi 0x00 selama otentikasi) ]
Bita 2..4:  [ Session ID: 24 bit big-endian (0x000001..0xFFFFFF) ]
Bita 5..8:  [ Sequence Number: 32 bit (8b atas MemberSlot | 24b bawah Sequence Counter) ]
Bita 9:     [ Cadangan / Bita perataan amplop akhir (0x00) ]
```

### 3. Penyusunan Nonce AEAD 12-Bita

```text
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                     Session ID (24 bit)       | Sequence Num  |
|                       (Bita 0..2)             |   (Bita 3)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                    Sequence Number (lanjutan) | Vers | Opcode |
|                       (Bita 4..6)             |   (Bita 7)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            Tag Domain "TKM3" [0x54, 0x4B, 0x4D, 0x33]         |
|                      (Bita 8..11: 4 Bita)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 4. Tata Letak Muatan Biner (Slot Muatan Tersegel 30 Bita)

#### A. Muatan ACK (`PacketType.ack = 0x04`)
```text
+-----------------------+-----------------------+--------------------+------------------------+
| Bita 0..3 (4 Bita)    | Bita 4..5 (2 Bita)    | Bita 6 (1 Bita)    | Bita 7..29 (23 Bita)   |
| Nomor Urut Target     | Inisial Target        | Status (ACKStatus) | Bantalan Nol Cadangan  |
| (Big-Endian UInt32)   | (Tersandi Base-27)    | (0x01 = Delivered) | (Data(repeating: 0))   |
+-----------------------+-----------------------+--------------------+------------------------+
```

#### B. Muatan Pesan Obrolan (`PacketType.chat = 0x02`)
```text
+-----------------------+-----------------------+--------------------+--------------------+------------------------+
| Bita 0..1 (2 Bita)    | Bita 2..3 (2 Bita)    | Bita 4 (1 Bita)    | Bita 5..24 (20 B)  | Bita 25..29 (5 Bita)   |
| Inisial Pengirim      | Inisial Target        | Panjang Bita UTF-8 | Teks UTF-8 Terjepit| Bantalan Nol Cadangan  |
| (Tersandi Base-27)    | ("ALL" = Siaran)      | (0..20 Bita)       | (Dipotong Mundur)  | (Data(repeating: 0))   |
+-----------------------+-----------------------+--------------------+--------------------+------------------------+
```

#### C. Muatan Ping Lokasi (`PacketType.locationPing = 0x01`)
```text
+--------------------+--------------------+--------------------+-----------------+-----------------+-----------------+--------------------+-----------------+------------------------+
| Bita 0..3 (4 B)    | Bita 4..7 (4 B)    | Bita 8..11 (4 B)   | Bita 12 (1 B)   | Bita 13 (1 B)   | Bita 14 (1 B)   | Bita 15..16 (2 B)  | Bita 17 (1 B)   | Bita 18..29 (12 B)     |
| Lintang Kuantisasi | Bujur Kuantisasi   | Waktu (Epoch)      | Akurasi (Meter) | Baterai (%)     | Arah (0..255)   | Inisial Pengirim   | Kode Warna      | Bantalan Nol Cadangan  |
| (Int32 *10.000.000)| (Int32 *10.000.000)| (Big-Endian UInt32)| (UInt8 Terjepit)| (0..100)        | (Derajat*256/36)| (Tersandi Base-27) | (MemberColor)   | (Data(repeating: 0))   |
+--------------------+--------------------+--------------------+-----------------+-----------------+-----------------+--------------------+-----------------+------------------------+
```

#### D. Muatan Pembaruan Titik Temu (`PacketType.meetingUpdate = 0x07`)
```text
+--------------------+--------------------+--------------------+-----------------+--------------------+-----------------+--------------------+-----------------+------------------+
| Bita 0..3 (4 B)    | Bita 4..7 (4 B)    | Bita 8..11 (4 B)   | Bita 12 (1 B)   | Bita 13..24 (12 B) | Bita 25 (1 B)   | Bita 26..27 (2 B)  | Bita 28 (1 B)   | Bita 29 (1 B)    |
| Lintang Kuantisasi | Bujur Kuantisasi   | Waktu Target(Epoch)| Pjg Nama (0..12)| Nama Titik Temu    | Aksi (Opcode)   | Inisial Pengusul   | Anggota Target  | Bantalan Cadangan|
| (Int32 *10.000.000)| (Int32 *10.000.000)| (Big-Endian UInt32)| (UInt8)         | (Bantalan Nol 12B) | (MeetingAction) | (Tersandi Base-27) | (Slot Anggota)  | (0x00)           |
+--------------------+--------------------+--------------------+-----------------+--------------------+-----------------+--------------------+-----------------+------------------+
```

#### E. Muatan Permintaan Rute (`0x05`) & Respons Rute (`0x06`)
```text
+-----------------------+-----------------------+-----------------------+-------------------+------------------------+
| Bita 0..1 (2 Bita)    | Bita 2..3 (2 Bita)    | Bita 4..7 (4 Bita)    | Bita 8 (1 Bita)   | Bita 9..29 (21 Bita)   |
| Inisial Inisiator     | Inisial Target        | Nonce Penemuan        | Biaya Rute        | Bantalan Nol Cadangan  |
| (Tersandi Base-27)    | (Tersandi Base-27)    | (Big-Endian UInt32)   | (Akumulator Hop)  | (Data(repeating: 0))   |
+-----------------------+-----------------------+-----------------------+-------------------+------------------------+
```

#### F. Muatan SOS Darurat (`PacketType.sos = 0x03`)
```text
+--------------------+--------------------+--------------------+------------------+------------------+--------------------+--------------------+------------------+------------------+------------------+-----------------------+
| Bita 0..3 (4 B)    | Bita 4..7 (4 B)    | Bita 8..11 (4 B)   | Bita 12 (1 B)    | Bita 13 (1 B)    | Bita 14..17 (4 B)  | Bita 18..19 (2 B)  | Bita 20 (1 B)    | Bita 21 (1 B)    | Bita 22 (1 B)    | Bita 23..29 (7 B)     |
| Lintang Kuantisasi | Bujur Kuantisasi   | Waktu (Epoch)      | Akurasi (Meter)  | Penanda Darurat  | ID Peristiwa SOS   | Inisial Pengirim   | Jenis Darurat    | Level Baterai    | Kode Warna       | Bantalan Nol Cadangan |
| (Int32 *10.000.000)| (Int32 *10.000.000)| (Big-Endian UInt32)| (UInt8)          | (0x01 Tetap)     | (Big-Endian UInt32)| (Tersandi Base-27) | (Opcode SOSType) | (0..100 Terjepit)| (MemberColor)    | (Data(repeating: 0))  |
+--------------------+--------------------+--------------------+------------------+------------------+--------------------+--------------------+------------------+------------------+------------------+-----------------------+
```

#### G. Muatan Resolusi SOS (`PacketType.sosResolved = 0x08`)
```text
+-----------------------+-----------------------+------------------------+
| Bita 0..3 (4 Bita)    | Bita 4..5 (2 Bita)    | Bita 6..29 (24 Bita)   |
| ID Peristiwa SOS      | Inisial Pengirim      | Bantalan Nol Cadangan  |
| (Big-Endian UInt32)   | (Tersandi Base-27)    | (Data(repeating: 0))   |
+-----------------------+-----------------------+------------------------+
```

---

## 1. Teekum/Teekum/Core/Configuration/MeepoConfiguration.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MeepoConfiguration.swift](../../Teekum/Teekum/Core/Configuration/MeepoConfiguration.swift) |
| **Jumlah Baris (`wc -l`)** | 199 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum tipe nilai (`nonisolated public enum MeepoConfiguration`) |
| **Domain Konkurensi** | Enum ruang nama `nonisolated`; sepenuhnya bebas dari isolasi aktor dan aman untuk thread di semua domain. |
| **Peran Arsitektural** | Repositori konfigurasi master yang menyatukan ambang batas jaringan, batas hop, jeda coba ulang, batas baterai, dan waktu UI. |

### Apa yang Dilakukan Berkas Ini
`MeepoConfiguration.swift` berfungsi sebagai sumber kebenaran tunggal (*single source of truth*) untuk semua konstanta arsitektural, batasan protokol kawat, interval kadensi, ambang batas jaringan, batas hop, jeda coba ulang, dan gerbang pemutus baterai di seluruh aplikasi. Berkas ini mengelompokkan tombol-tombol operasional ini ke dalam ruang nama statis terpisah (`Network`, `Timing`, `Chat`, `SOS`, `Rendezvous`, `Battery`, `Navigation`), memastikan bahwa parameter sistem kritis (seperti datagram kawat tetap 56-bita atau ambang batas kelangsungan hidup baterai 20%) disesuaikan secara terpusat tanpa divergensi kode antar modul.

### Analogi Bahasa Awam (ELI5)
Bayangkan `MeepoConfiguration.swift` sebagai buku peraturan utama dan dasbor dial kendali untuk jaringan radio ekspedisi di luar jangkauan sinyal. Alih-alih membiarkan setiap operator radio menebak berapa lama transmisi diizinkan, berapa banyak hop panggilan bahaya dapat melompat, atau kapan harus beralih ke mode hemat daya darurat, kepala insinyur menulis semua aturan yang tidak dapat diubah ke dalam satu buku panduan yang wajib diperiksa oleh setiap perangkat sebelum mengirim satu bita pun ke udara.

### Istilah Teknis yang Didefinisikan
- **Ruang Nama Enum Tak Berpenghuni (*Uninhabited Enum Namespace*):** Enum Swift tanpa kasus (`enum MeepoConfiguration {}`) yang digunakan murni sebagai ruang nama untuk konstanta dan fungsi statis. Karena tidak memiliki kasus, tipe ini tidak dapat dialokasikan atau diinstansiasi sebagai objek runtime (`MeepoConfiguration()`), mencegah beban memori dan kebocoran status.
- **`nonisolated`:** Kata kunci Konkurensi Swift yang secara eksplisit melepaskan entitas dari konteks isolasi aktor apa pun. Menandai konstanta konfigurasi sebagai `nonisolated` memastikan mereka dapat dibaca secara sinkron dan tanpa `await` dari thread pekerja latar belakang, body tampilan UI, dan aktor terisolasi.
- **Invarian Datagram Kawat (*Wire Datagram Invariant*):** Batasan protokol dengan panjang tetap yang mewajibkan setiap frame radio yang ditransmisikan berukuran tepat 56 bita. Ini mencegah fragmentasi paket di saluran Bluetooth Low Energy (BLE) yang rentan hilang dan menghilangkan alokasi ulang memori pada radio tertanam dengan sumber daya terbatas.
- **Nonce AEAD (Authenticated Encryption with Associated Data):** Angka sekali pakai 12-bita (96-bit) yang digunakan dalam cipher kriptografi (ChaCha20-Poly1305) untuk memastikan bahwa teks biasa yang identik yang dienkripsi di bawah kunci yang sama menghasilkan ciphertext yang berbeda.
- **Pembatasan Laju Token Bucket (*Token Bucket Rate Limiting*):** Algoritma manajemen lalu lintas jaringan di mana token diakumulasikan pada tingkat yang stabil hingga kapasitas burst. Meneruskan paket menghabiskan satu token; jika tidak ada token yang tersisa, paket dicekik atau dibuang untuk mencegah badai siaran (*broadcast storm*) mesh.
- **AODV (Ad-hoc On-Demand Distance Vector):** Protokol perutean mesh reaktif di mana jalur antar node ditemukan hanya ketika diminta oleh aliran lalu lintas aktif (melalui datagram Permintaan Rute `RREQ` dan Balasan Rute `RREP`).

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Header dan Parameter Protokol Jaringan (Baris 1–49)
```swift
// Baris 1-49
//
//  MeepoConfiguration.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

/// Centralized Master Configuration Repository for Google Antigravity / TeeKum disaster zone Mesh.
///
/// Every configurable knob, cadences, network thresholds, hop limits, battery cutoffs,
/// retry parameters, and UI timings are unified in this single file for rapid testing and field tuning.
nonisolated public enum MeepoConfiguration {
    
    // MARK: - 1. Wire Protocol & Network Topology Parameters
    public enum Network {
        /// Strictly fixed 56-byte wire datagram format (invariant across all packet types).
        public static let wirePacketSize: Int = 56
        
        /// Size of cleartext envelope for routing inspection (10 bytes).
        public static let cleartextEnvelopeSize: Int = 10
        
        /// Size of encrypted ChaCha20 / Poly1305 payload (30 bytes).
        public static let encryptedPayloadSize: Int = 30
        
        /// Size of Poly1305 authentication tag (16 bytes).
        public static let authTagSize: Int = 16
        
        /// Size of cryptographic AEAD nonce (12 bytes).
        public static let nonceSize: Int = 12
        
        /// Protocol version (0x01 for Protocol Version 1).
        public static let protocolVersion: UInt8 = 0x01
        
        /// 4-byte domain separation tag used in AEAD nonce construction: 'T', 'K', 'M', '3'.
        public static let protocolDomainTag: [UInt8] = [0x54, 0x4B, 0x4D, 0x33]

        /// Bitmask for canonical 24-bit Session ID values (`0x000000...0xFFFFFF`).
        public static let sessionIdMask: UInt32 = 0x00FFFFFF

        /// Maximum allowable 24-bit Session ID (`0x00FFFFFF` = 16,777,215).
        public static let maxSessionId: UInt32 = 0x00FFFFFF
        
        /// Hard architectural maximum allowable hop limit across the entire mesh (1...15).
        public static let maxHopLimit: UInt8 = 15
        
        /// Hop limit for standard periodic Location Ping packets (Type 0x01) (default: 8).
        public static let defaultHopLimit: UInt8 = 8
        
        /// Dedicated hop limit budget for Chat Messages (Type 0x07) and Delivery ACKs (Type 0x06).
        /// Tuneable independently to control text propagation radius and conserve disaster zone airtime (default: 8).
        public static let chatHopLimit: UInt8 = 8
        
        /// High-reach hop limit for Group Rendezvous / Meeting Point updates (Type 0x03) (default: 15).
        public static let meetingPointHopLimit: UInt8 = 15
        
        /// Maximum-priority hop limit for Emergency SOS siren alerts (Type 0x02) (default: 15).
        public static let sosHopLimit: UInt8 = 15
    }
```
- **Baris 1–11:** Komentar header dan `import Foundation`. Mendeklarasikan `nonisolated public enum MeepoConfiguration`.
- **Baris 15–18:** `wirePacketSize = 56` memberlakukan invarian arsitektur keras bahwa setiap paket kawat fisik berukuran tepat 56 bita.
- **Baris 20–22:** `cleartextEnvelopeSize = 10` mendefinisikan tajuk tidak terenkripsi 10-bita (Bita 0..9) yang dibaca oleh relai mesh perantara.
- **Baris 24–26:** `encryptedPayloadSize = 30` mendefinisikan blok ciphertext ChaCha20 30-bita (Bita 10..39).
- **Baris 28–30:** `authTagSize = 16` mendefinisikan tag MAC Poly1305 16-bita (Bita 40..55). Perhatikan bahwa $10 + 30 + 16 = 56$ bita.
- **Baris 32–34:** `nonceSize = 12` mendefinisikan nonce AEAD 12-bita yang dibutuhkan oleh ChaChaPoly.
- **Baris 36–37:** `protocolVersion = 0x01` mengidentifikasi Protokol Versi 1 di nibble atas Bita 0.
- **Baris 39–40:** `protocolDomainTag = [0x54, 0x4B, 0x4D, 0x33]` mendefinisikan karakter ASCII `'T'`, `'K'`, `'M'`, `'3'` yang ditambahkan ke nonce untuk pemisahan domain.
- **Baris 42–46:** `sessionIdMask = 0x00FFFFFF` dan `maxSessionId = 0x00FFFFFF` menegakkan batas 24-bit pada pengenal kelompok.
- **Baris 48–56:** Batas hop: `maxHopLimit = 15` (maksimum 4-bit), `defaultHopLimit = 8` (ping lokasi), `chatHopLimit = 8` (obrolan dan ACK), `meetingPointHopLimit = 15` (titik kumpul jangkauan luas), dan `sosHopLimit = 15` (peringatan darurat jangkauan maksimum).

#### Blok 2: Kadensi Mesh & Parameter Waktu (Baris 51–118)
```swift
// Baris 51-118
    // MARK: - 2. Broadcast Cadence & Mesh Timing Parameters
    public enum Timing {
        /// Location publishing interval when actively moving with strong nearby peers (default: 4.0s).
        public static let locationMovingInterval: TimeInterval = 4.0
        
        /// Location publishing interval when stationary with nearby peers (default: 20.0s).
        public static let locationStationaryInterval: TimeInterval = 20.0
        
        /// Accelerated publishing interval when links degrade or peers become distant (default: 2.0s).
        public static let distantPeerInterval: TimeInterval = 2.0
        
        /// Throttled publishing interval in disaster zone Survival Mode (<20% battery) (default: 60.0s).
        public static let survivalInterval: TimeInterval = 60.0
        
        /// RSSI threshold (dBm) below which a link is deemed weak/distant (default: -75 dBm).
        public static let distantRSSIThreshold: Int8 = -75
        
        /// GPS distance threshold (meters) beyond which a peer is treated as distant (default: 30.0m).
        public static let distantDistanceThresholdMeters: Double = 30.0
        
        /// Elapsed seconds of inactivity before a member is marked Stale (default: 30.0s).
        public static let stalePeerThreshold: TimeInterval = 30.0
        
        /// Elapsed seconds of inactivity before a member is marked Offline (default: 180.0s).
        public static let offlinePeerThreshold: TimeInterval = 180.0
        
        /// Direct neighbor heartbeat cadence (default: 2.0s).
        public static let neighborHeartbeatInterval: TimeInterval = 2.0
        
        /// Timeout to prune dead direct neighbor connections (default: 6.0s).
        public static let neighborPruneThreshold: TimeInterval = 6.0
        
        /// AODV routing table entry validity time-to-live (default: 30.0s).
        public static let routingTableTTL: TimeInterval = 30.0
        
        /// Minimum interval between route requests (RREQ) to prevent mesh flooding (default: 10.0s).
        public static let rreqRateLimitInterval: TimeInterval = 10.0
        
        /// Timeout waiting for Route Response (RREP) before retrying (default: 1.5s).
        public static let rreqRetryTimeout: TimeInterval = 1.5
        
        /// Maximum route discovery retries (default: 2).
        public static let rreqMaxRetries: Int = 2
        
        /// Maximum ordinary packet relay forwarding rate (packets/second, default: 2.0).
        public static let ordinaryRelayRateLimit: Double = 8.0
        
        /// Burst token bucket capacity for ordinary packet relaying (default: 4.0).
        public static let ordinaryRelayBurstCapacity: Double = 4.0
        
        /// Urgent SOS packet forwarding rate (packets/second, default: 4.0).
        public static let urgentSOSRateLimit: Double = 4.0
        
        /// Maximum entries preserved in the LRU duplicate suppression cache (default: 1024).
        public static let seenPacketCacheCapacity: Int = 1024
        
        /// Priority outbox queue buffer capacity (default: 64 packets).
        public static let outboxQueueCapacity: Int = 64
        
        /// Maximum retry attempts for outbox transmissions (default: 2 retries = 3 total attempts).
        public static let outboxMaxRetries: Int = 2
        
        /// Initial backoff delay for outbox retries (default: 0.25s).
        public static let outboxBackoffInitialDelay: TimeInterval = 0.25
        
        /// Multiplier for exponential backoff between retries (default: 2.0).
        public static let outboxBackoffMultiplier: Double = 2.0
    }
```
- **Baris 53–66:** Interval publikasi lokasi dinamis: bergerak (`4.0s`), diam (`20.0s`), tautan menurun/jauh (`2.0s`), dan mode bertahan (`60.0s`).
- **Baris 68–73:** Batas degradasi rekan: ambang batas RSSI `<= -75 dBm` atau jarak spasial `>= 30.0m` memicu publikasi yang dipercepat.
- **Baris 75–79:** Ambang kehadiran: tidak aktif setelah `30.0s` menandai rekan usang (*stale*); tidak aktif setelah `180.0s` menandai rekan offline.
- **Baris 81–85:** Kesehatan tetangga: detak jantung langsung setiap `2.0s`; rekan dipangkas sebagai mati setelah `6.0s` tanpa detak jantung.
- **Baris 87–98:** Perutean dan penemuan AODV: TTL entri rute adalah `30.0s`; batas laju antar penemuan RREQ adalah `10.0s`; batas waktu respons RREP adalah `1.5s` dengan `2` coba ulang.
- **Baris 100–108:** Penerusan token bucket: laju lalu lintas biasa adalah `8.0` paket/detik dengan kapasitas burst `4.0`; laju SOS darurat adalah `4.0` paket/detik; kapasitas cache deduplikasi adalah `1024` entri.
- **Baris 110–118:** Antrean kotak keluar berprioritas: buffer menampung hingga `64` paket, mencoba ulang hingga `2` kali dengan jeda awal `0.25s` dan pengali `2.0x`.

#### Blok 3: Parameter Obrolan, SOS, Pertemuan, Baterai & Navigasi (Baris 120–199)
```swift
// Baris 120-199
    // MARK: - 3. Chat Messaging Parameters
    public enum Chat {
        public static let carryFastRetryInterval: TimeInterval = 2.0
        public static let carryFastAttemptLimit: Int = 3
        public static let carrySlowRetryInterval: TimeInterval = 30.0
        /// Maximum chat messages held strictly in ephemeral RAM (purged on exit) (default: 50).
        public static let maxHistory: Int = 50
        
        /// Anti-spam client-side cooldown interval between outgoing messages (default: 3.0s).
        public static let cooldownDuration: TimeInterval = 3.0
        
        /// ACK confirmation timeout window before marking a recipient as timed out (default: 15.0s).
        public static let deliveryTimeout: TimeInterval = 15.0
        
        /// Maximum automated retries for unacknowledged messages (default: 2 retries = 3 attempts).
        public static let maxRetries: Int = 2
        
        /// Initial backoff delay for chat message retries (default: 0.5s).
        public static let backoffInitialDelay: TimeInterval = 0.5
        
        /// Multiplier for exponential backoff on unacknowledged chat retries (default: 1.5).
        public static let backoffMultiplier: Double = 1.5
        
        /// Maximum UTF-8 byte boundary for chat text (strictly 20 bytes).
        public static let maxPayloadBytes: Int = 20
    }
    
    // MARK: - 4. Emergency SOS Parameters
    public enum SOS {
        /// Inactivity stillness duration before triggering pre-alarm warning countdown (default: 180.0s = 3 minutes).
        public static let inactivityStillnessDuration: TimeInterval = 180.0
        
        /// Pre-alarm silent haptic warning countdown duration before broadcasting auto-SOS (default: 30.0s).
        public static let inactivityWarningCountdown: TimeInterval = 30.0
        
        /// Acceleration variance threshold (in g) above which device is considered in physical motion (default: 0.15g).
        public static let inactivityMotionThreshold: Double = 0.15
    }
    
    // MARK: - 5. Group Rendezvous / Meeting Point Parameters
    public enum Rendezvous {
        /// Proximity radius in meters for automatic arrival detection (default: 25.0m).
        public static let defaultArrivalRadiusMeters: Double = 25.0
        
        /// Duration past scheduled meetup time before rendezvous auto-clears (default: 3600.0s = 1 hour).
        public static let autoExpirationSeconds: TimeInterval = 3600.0
        
        /// 1-tap quick preset offsets in minutes.
        public static let presetMinutes: [Int] = [0, 15, 30, 60]
    }
    
    // MARK: - 6. Battery & Survival Mode Parameters
    public enum Battery {
        /// Battery percentage threshold triggering disaster zone Survival Mode (default: 20%).
        public static let survivalThresholdPercent: UInt8 = 20
        
        /// Default duration for Lock Screen Timed Relay mode (default: 1800s = 30 minutes).
        public static let timedRelayDefaultDuration: TimeInterval = 1800.0
    }
    
    // MARK: - 7. Tactical Radar & Directional Navigation Parameters
    public enum Navigation {
        /// Outer polar boundary radius rendered on Tactical Radar (default: 60.0m).
        public static let tacticalRadarRangeMeters: Double = 60.0
        
        /// Field of view angle for attendee heading vision cones on map (default: 50.0 degrees).
        public static let visionConeFOV: Double = 50.0
    }
}
```
- **Baris 122–143:** Parameter `Chat`: riwayat RAM efemeral dibatasi hingga `50` pesan; pendinginan (*cooldown*) klien adalah `3.0s`; batas waktu konfirmasi pengiriman adalah `15.0s`; coba ulang otomatis sebanyak `2` kali dengan jeda awal `0.5s` dan pengali `1.5x`; kapasitas teks dibatasi tepat `20` bita UTF-8.
- **Baris 146–155:** Parameter `SOS`: Ambang batas ketidaktergerakan (*stillness*) adalah `180.0s` (3 menit); hitung mundur peringatan pra-alarm adalah `30.0s`; ambang batas varians akselerometer CoreMotion adalah `0.15g`.
- **Baris 158–168:** Parameter `Rendezvous`: radius kedatangan adalah `25.0m`; kedaluwarsa otomatis adalah `3600.0s` (1 jam setelah waktu target); preset waktu cepat adalah `[0, 15, 30, 60]` menit.
- **Baris 171–178:** Parameter `Battery`: Mode Bertahan bencana aktif pada baterai `<= 20%`; durasi default relai berbatas waktu pada layar terkunci adalah `1800.0s` (30 menit).
- **Baris 181–188:** Parameter `Navigation`: Rentang polar maksimum Radar Taktis adalah `60.0m`; sudut pandang kerucut hadap peta adalah `50.0` derajat.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Datagram 56-Bita Tetap:** Paket dengan panjang variabel melalui Bluetooth Low Energy menimbulkan latensi renegosiasi MTU, overhead fragmentasi yang tidak dapat diprediksi, dan fragmentasi memori heap pada mikrokontroler tertanam. Menerapkan buffer 56-bita yang invarian menjamin penjadwalan radio yang deterministik dan alokasi memori statis.
- **Gerbang Pemutus Baterai 20%:** Ketika petugas penyelamat dan korban selamat memiliki baterai di bawah 20%, ponsel mereka berisiko mati sebelum operasi berakhir. Mengaktifkan Mode Bertahan pada 20% menjaga sisa daya perangkat khusus untuk suar SOS darurat berprioritas tinggi, mematikan penerusan relai untuk orang asing.

---

## 2. Teekum/Teekum/Core/Packets/PacketConstants.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [PacketConstants.swift](../../Teekum/Teekum/Core/Packets/PacketConstants.swift) |
| **Jumlah Baris (`wc -l`)** | 67 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum tipe nilai (`public enum PacketConstants`) |
| **Domain Konkurensi** | Ruang nama nilai tanpa batasan; aman untuk thread di semua aktor. |
| **Peran Arsitektural** | Invarian kawat jaringan yang mendefinisikan datagram tetap 56-bita, amplop 10-bita, topeng ID sesi 24-bit, dan tag domain. |

### Apa yang Dilakukan Berkas Ini
`PacketConstants.swift` menyediakan antarmuka tingkat protokol yang bersih ke konstanta konfigurasi dasar yang ditentukan dalam `MeepoConfiguration`. Berkas ini mengekspos pengakses terhitung (*computed accessors*) untuk ukuran paket, bita versi protokol, batas hop, dan tag domain. Berkas ini juga merangkum validasi kanonik dan algoritma serialisasi transmisi kawat big-endian untuk Pengenal Sesi 24-bit (`sessionId`), memastikan pengkodean kawat 3-bita yang seragam di semua penangan paket.

### Analogi Bahasa Awam (ELI5)
Jika `MeepoConfiguration` adalah ruang kendali dial master, `PacketConstants.swift` adalah alat ukur terstandarisasi dan stensil kawat yang digunakan oleh teknisi saat merakit paket. Ketika teknisi membuat amplop paket, mereka menggunakan alat ukur ini untuk memastikan bahwa amplop berukuran tepat 10 bita, muatannya 30 bita, cap keamanannya 16 bita, dan nomor identifikasi kelompok dicap sebagai kode heksadesimal 3-bita yang bersih.

### Istilah Teknis yang Didefinisikan
- **ID Sesi 24-Bit (`sessionId`):** Pengenal jaringan 3-bita yang mengidentifikasi sesi kelompok pada transmisi kawat (`0x000001` hingga `0xFFFFFF`, mewakili hingga 16.777.215 jaringan zona bencana yang unik).
- **Pengkodean Big-Endian:** Konvensi urutan bita arsitektur di mana bita paling signifikan (*most significant byte* / MSB) dari kata multi-bita ditempatkan pada alamat memori terendah (bita pertama pada kawat).
- **Penopengan Bitwise (`&`):** Menerapkan topeng bit (`sessionId & 0x00FFFFFF`) untuk menolkan bit tinggi yang tidak diinginkan, memastikan bahwa variabel integer 32-bit secara ketat sesuai dengan domain 24-bit.
- **Pemformatan String Heksadesimal:** Mengonversi integer mentah menjadi string ASCII terformat (`String(format: "%06X", ...)`) yang menghasilkan tepat 6 karakter heksadesimal huruf besar (misalnya `0x7E3AF5` -> `"7E3AF5"`).

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Ukuran Kawat & Parameter Protokol (Baris 1–40)
```swift
// Baris 1-40
//
//  PacketConstants.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

nonisolated public enum PacketConstants {
    public static var wirePacketSize: Int { MeepoConfiguration.Network.wirePacketSize }
    public static var cleartextEnvelopeSize: Int { MeepoConfiguration.Network.cleartextEnvelopeSize }
    public static var encryptedPayloadSize: Int { MeepoConfiguration.Network.encryptedPayloadSize }
    public static var authTagSize: Int { MeepoConfiguration.Network.authTagSize }
    public static var nonceSize: Int { MeepoConfiguration.Network.nonceSize }
    
    public static var protocolVersion: UInt8 { MeepoConfiguration.Network.protocolVersion }
    public static var defaultHopLimit: UInt8 {
        get { MeepoConfiguration.Network.defaultHopLimit }
    }
    public static var chatHopLimit: UInt8 {
        get { MeepoConfiguration.Network.chatHopLimit }
    }
    public static var maxHopLimit: UInt8 {
        get { MeepoConfiguration.Network.maxHopLimit }
    }
    public static var meetingPointHopLimit: UInt8 {
        get { MeepoConfiguration.Network.meetingPointHopLimit }
    }
    public static var sosHopLimit: UInt8 {
        get { MeepoConfiguration.Network.sosHopLimit }
    }
    
    /// Validates whether a given data buffer size matches the strictly fixed 56-byte wire format.
    public static func isValidWirePacketSize(_ count: Int) -> Bool {
        count == wirePacketSize
    }
    
    /// 4-byte protocol domain tag used in nonce construction: 'T', 'K', 'M', '3'
    public static var protocolDomainTag: [UInt8] { MeepoConfiguration.Network.protocolDomainTag }
```
- **Baris 1–10:** Mengimpor Foundation dan mendeklarasikan `nonisolated public enum PacketConstants`.
- **Baris 11–15:** Properti terhitung yang mendelegasikan ke `MeepoConfiguration.Network`: `wirePacketSize` (56), `cleartextEnvelopeSize` (10), `encryptedPayloadSize` (30), `authTagSize` (16), dan `nonceSize` (12).
- **Baris 17–33:** Pengakses batas hop: `protocolVersion` (`0x01`), `defaultHopLimit` (8), `chatHopLimit` (8), `maxHopLimit` (15), `meetingPointHopLimit` (15), dan `sosHopLimit` (15).
- **Baris 35–37:** `isValidWirePacketSize(_ count: Int)` memvalidasi apakah buffer bita yang masuk sama dengan tepat 56 bita.
- **Baris 39–40:** Mengekspos `protocolDomainTag` (`[0x54, 0x4B, 0x4D, 0x33]`).

#### Blok 2: Pengelolaan & Serialisasi ID Sesi 24-Bit (Baris 42–67)
```swift
// Baris 42-67
    /// Canonical 24-bit Session ID bitmask (`0x00FFFFFF`).
    public static var sessionIdMask: UInt32 { MeepoConfiguration.Network.sessionIdMask }

    /// Maximum valid 24-bit Session ID (`0x00FFFFFF`).
    public static var maxSessionId: UInt32 { MeepoConfiguration.Network.maxSessionId }

    /// Validates whether a Session ID falls within the non-zero 24-bit range (`0x000001...0xFFFFFF`).
    public static func isValidSessionId(_ sessionId: UInt32) -> Bool {
        sessionId >= 1 && sessionId <= maxSessionId
    }

    /// Encodes a 24-bit Session ID into 3 big-endian wire bytes.
    public static func encodeSessionId24(_ sessionId: UInt32) -> [UInt8] {
        let sid = sessionId & sessionIdMask
        return [
            UInt8((sid >> 16) & 0xFF),
            UInt8((sid >> 8) & 0xFF),
            UInt8(sid & 0xFF)
        ]
    }

    /// Formats a 24-bit Session ID canonically as 6 uppercase hexadecimal characters.
    public static func formatSessionId(_ sessionId: UInt32) -> String {
        String(format: "%06X", sessionId & sessionIdMask)
    }
}
```
- **Baris 42–46:** Mengekspos `sessionIdMask` (`0x00FFFFFF`) dan `maxSessionId` (16.777.215).
- **Baris 48–51:** `isValidSessionId` memverifikasi bahwa ID sesi tidak nol dan tidak melebihi $2^{24}-1$.
- **Baris 53–61:** `encodeSessionId24` menopeng integer, kemudian mengekstrak 3 bita big-endian:
  - Bita 0: `(sid >> 16) & 0xFF` (bit 16..23)
  - Bita 1: `(sid >> 8) & 0xFF` (bit 8..15)
  - Bita 2: `sid & 0xFF` (bit 0..7)
- **Baris 63–66:** `formatSessionId` menghasilkan string hex huruf besar 6-karakter (`"%06X"`).

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Mengapa ID Sesi 24-Bit:** Menggunakan 3 bita untuk ID sesi menghemat 1 bita per frame dibandingkan dengan integer standar 32-bit, sekaligus menyediakan lebih dari 16,7 juta saluran sesi unik—lebih dari cukup untuk menghilangkan risiko tabrakan antar kelompok zona bencana yang berdekatan.
- **Penopengan Bit Sebelum Pemformatan:** Selalu menerapkan `sessionId & sessionIdMask` mencegah tampilan bit tingkat tinggi yang salah jika integer 32-bit tanpa topeng diteruskan ke pemformat.

---

## 3. Teekum/Teekum/Core/Packets/CleartextEnvelope.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [CleartextEnvelope.swift](../../Teekum/Teekum/Core/Packets/CleartextEnvelope.swift) |
| **Jumlah Baris (`wc -l`)** | 178 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct CleartextEnvelope: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`; aman untuk transfer melintasi domain konkurensi. |
| **Peran Arsitektural** | Tajuk kawat tidak terenkripsi 10-bita yang membawa versi protokol, opcode paket, batas hop, ID sesi, dan nomor urut terpartisi. |

### Apa yang Dilakukan Berkas Ini
`CleartextEnvelope.swift` memodelkan dan membuat serialisasi tajuk kawat tidak terenkripsi 10-bita yang tetap (Bita 0..9) yang dibawa di bagian depan setiap datagram 56-bita. Hal ini memungkinkan relai mesh zona bencana perantara memeriksa versi paket, jenis paket, batas hop, ID sesi, dan nomor urut tanpa harus memiliki kunci kriptografi kelompok. Berkas ini membagi nomor urut 32-bit menjadi slot anggota 8-bit dan penghitung 24-bit, menyusun Associated Authenticated Data (AAD) 10-bita dengan jumlah hop bertopeng untuk verifikasi ChaCha20-Poly1305, dan membangun nonce AEAD 12-bita deterministik.

### Analogi Bahasa Awam (ELI5)
Bayangkan mengirimkan kotak uang logam lapis baja yang tersegel melalui rantai relawan zona bencana. Di bagian luar kotak terdapat kantong plastik bening (`CleartextEnvelope`) yang memegang slip pengiriman. Slip tersebut menunjukkan nomor kelompok tujuan kotak, hitung mundur hop pengiriman, dan slot anggota pengirim. Relawan mana pun di sepanjang jalan dapat membaca slip dan menaikkan jumlah hop tanpa membuka kunci lapis baja. Namun, jika ada relawan yang merusak nomor tujuan atau kode urutan, kunci lapis baja (`Poly1305 AAD`) akan macet secara permanen dan menolak untuk dibuka saat tiba di tujuan.

### Istilah Teknis yang Didefinisikan
- **Amplop Teks-Terbuka (*Cleartext Envelope*):** Bagian awal yang tidak dienkripsi dari paket kawat yang mengekspos metadata yang diperlukan untuk perutean relai perantara dan penekanan duplikasi.
- **Data Terkait yang Diotentikasi (*Associated Authenticated Data* / AAD):** Data tambahan yang dimasukkan ke dalam cipher AEAD (ChaCha20-Poly1305) yang diperiksa integritasnya dan terikat secara kriptografis pada ciphertext, tetapi ditransmisikan tanpa enkripsi.
- **Penopengan Hop Count AAD (*AAD Hop Count Masking*):** Teknik mengganti nilai bita `hopCount` aktif dengan `0x00` saat menghasilkan AAD kriptografis. Ini memungkinkan node perantara menaikkan nilai `hopCount` pada kawat tanpa merusak tag otentikasi Poly1305 16-bita milik pengirim.
- **Pemisahan Bit (*Bit-Partitioning*):** Membagi satu integer mesin menjadi beberapa sub-bidang logis. Di sini, integer 32-bit (`UInt32`) dibagi menjadi `memberSlot` 8-bit (8 bit atas) dan penghitung urutan monotonik 24-bit (24 bit bawah).
- **Buffer Underflow:** Kondisi galat yang terjadi selama deserialisasi ketika aliran data input berisi lebih sedikit bita daripada ukuran struktur tetap yang diperlukan (di sini $< 10$ bita).

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Deklarasi Struktur dan Properti (Baris 1–48)
```swift
// Baris 1-48
//
//  CleartextEnvelope.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct CleartextEnvelope: Equatable, Sendable {
    public var version: UInt8
    public var type: PacketType
    public var hopLimit: UInt8
    public var hopCount: UInt8
    /// Canonical 24-bit session identifier (`0x000000...0xFFFFFF`).
    public var sessionId: UInt32 {
        didSet { sessionId &= PacketConstants.sessionIdMask }
    }
    public var sequenceNumber: UInt32
    
    public var memberSlot: UInt8 {
        CleartextEnvelope.memberSlot(from: sequenceNumber)
    }
    
    public var counter: UInt32 {
        CleartextEnvelope.counter(from: sequenceNumber)
    }
    
    public init(
        version: UInt8 = PacketConstants.protocolVersion,
        type: PacketType,
        hopLimit: UInt8 = PacketConstants.defaultHopLimit,
        hopCount: UInt8 = 0,
        sessionId: UInt32,
        sequenceNumber: UInt32
    ) {
        self.version = version
        self.type = type
        self.hopLimit = min(max(1, hopLimit), PacketConstants.maxHopLimit)
        self.hopCount = min(hopCount, self.hopLimit)
        self.sessionId = sessionId & PacketConstants.sessionIdMask
        self.sequenceNumber = sequenceNumber
    }
```
- **Baris 10:** Mendeklarasikan `public struct CleartextEnvelope: Equatable, Sendable`.
- **Baris 11–17:** Properti tersimpan: `version` (UInt8), `type` (PacketType), `hopLimit` (UInt8), `hopCount` (UInt8), `sessionId` (UInt32 yang ditopeng ke 24 bit pada `didSet`), dan `sequenceNumber` (UInt32).
- **Baris 19–25:** Properti terhitung yang mengekstrak bidang terpartisi dari `sequenceNumber`: `memberSlot` dan `counter`.
- **Baris 27–47:** Penginisialisasi yang menjepit `hopLimit` antara 1 dan 15 (`PacketConstants.maxHopLimit`), menjepit `hopCount` ke `hopLimit`, dan menopeng `sessionId` dengan `sessionIdMask`.

#### Blok 2: Pemisahan Nomor Urut & Serialisasi Kawat (Baris 50–133)
```swift
// Baris 50-133
    // MARK: - Sequence Number Partitioning
    
    public static func makeSequenceNumber(memberSlot: UInt8, counter: UInt32) -> UInt32 {
        (UInt32(memberSlot) << 24) | (counter & 0x00FFFFFF)
    }
    
    public static func memberSlot(from sequenceNumber: UInt32) -> UInt8 {
        UInt8((sequenceNumber >> 24) & 0xFF)
    }
    
    public static func counter(from sequenceNumber: UInt32) -> UInt32 {
        sequenceNumber & 0x00FFFFFF
    }

    private var versionAndTypeByte: UInt8 {
        ((version & 0x0F) << 4) | (type.rawValue & 0x0F)
    }

    private var sessionIdBytes: [UInt8] {
        PacketConstants.encodeSessionId24(sessionId)
    }
    
    // MARK: - Serialization (10 Bytes)
    
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.cleartextEnvelopeSize)
        
        // Byte 0: version (high 4 bits) | type (low 4 bits)
        data.append(versionAndTypeByte)
        
        // Byte 1: hopLimit (UInt8)
        data.append(hopLimit)
        
        // Byte 2: hopCount (UInt8)
        data.append(hopCount)
        
        // Bytes 3..5: sessionId (3 bytes, 24-bit big-endian)
        data.append(contentsOf: sessionIdBytes)
        
        // Bytes 6..9: sequenceNumber (32-bit big-endian)
        var seqBE = sequenceNumber.bigEndian
        data.append(Data(bytes: &seqBE, count: 4))
        
        return data
    }
    
    public static func deserialize(from data: Data) throws -> CleartextEnvelope {
        guard data.count >= PacketConstants.cleartextEnvelopeSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let byte0 = data[data.startIndex]
        let version = (byte0 >> 4) & 0x0F
        guard version == PacketConstants.protocolVersion else {
            throw PacketCodecError.unsupportedVersion(version)
        }
        
        let typeRaw = byte0 & 0x0F
        guard let type = PacketType(rawValue: typeRaw) else {
            throw PacketCodecError.unknownPacketType(typeRaw)
        }
        
        let hopLimit = data[data.startIndex + 1]
        guard hopLimit >= 1 else {
            throw PacketCodecError.invalidHopLimit(hopLimit)
        }
        
        let hopCount = data[data.startIndex + 2]
        guard hopCount <= hopLimit else {
            throw PacketCodecError.hopCountExceededLimit(count: hopCount, limit: hopLimit)
        }
        
        let b3 = UInt32(data[data.startIndex + 3])
        let b4 = UInt32(data[data.startIndex + 4])
        let b5 = UInt32(data[data.startIndex + 5])
        let sid24 = (b3 << 16) | (b4 << 8) | b5
        
        let seq = data.subdata(in: (data.startIndex + 6)..<(data.startIndex + 10)).withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self).bigEndian
        }
        
        return CleartextEnvelope(
            version: version,
            type: type,
            hopLimit: hopLimit,
            hopCount: hopCount,
            sessionId: sid24,
            sequenceNumber: seq
        )
    }
```
- **Baris 52–62:** Pembantu partisi urutan:
  - `makeSequenceNumber`: `(UInt32(memberSlot) << 24) | (counter & 0x00FFFFFF)`.
  - `memberSlot`: `UInt8((sequenceNumber >> 24) & 0xFF)` menggeser turun 24 bit.
  - `counter`: `sequenceNumber & 0x00FFFFFF` menopeng 8 bit teratas.
- **Baris 64–70:** `versionAndTypeByte` mengemas versi 4-bit ke nibble tinggi dan tipe 4-bit ke nibble rendah: `((version & 0x0F) << 4) | (type.rawValue & 0x0F)`.
- **Baris 74–94:** `serialize()` membangun tepat 10 bita:
  - Bita 0: `versionAndTypeByte`
  - Bita 1: `hopLimit`
  - Bita 2: `hopCount`
  - Bita 3..5: `sessionId` big-endian 3-bita
  - Bita 6..9: `sequenceNumber` big-endian 4-bita
- **Baris 96–133:** `deserialize(from:)` membongkar 10 bita, memverifikasi ukuran minimum, memvalidasi versi protokol terhadap `0x01`, memvalidasi opcode terhadap `PacketType`, menegakkan `hopCount <= hopLimit`, merekonstruksi `sessionId` 24-bit, dan memuat `sequenceNumber` big-endian 32-bit.

#### Blok 3: Input Kriptografis AAD dan Pembentukan Nonce (Baris 135–178)
```swift
// Baris 135-178
    // MARK: - Cryptographic Inputs (10 Bytes AAD)
    
    public func authenticatedAssociatedData() -> Data {
        var aad = Data(capacity: PacketConstants.cleartextEnvelopeSize)
        
        // Byte 0: versionAndType
        aad.append(versionAndTypeByte)
        
        // Byte 1: hopLimit
        aad.append(hopLimit)
        
        // Byte 2: hopCount masked to 0x00
        aad.append(0x00)
        
        // Bytes 3..5: sessionId (3 bytes)
        aad.append(contentsOf: sessionIdBytes)
        
        // Bytes 6..9: sequenceNumber (4 bytes)
        var seqBE = sequenceNumber.bigEndian
        aad.append(Data(bytes: &seqBE, count: 4))
        
        return aad
    }
    
    /// Constructs the deterministic 12-byte (96-bit) AEAD Nonce:
    /// - Bytes 0..2: sessionId (3 bytes)
    /// - Bytes 3..6: sequenceNumber (4 bytes)
    /// - Byte 7: versionAndType (1 byte)
    /// - Bytes 8..11: Protocol Domain Tag "TKM3" ([0x54, 0x4B, 0x4D, 0x33])
    public func constructNonce() -> Data {
        var nonceData = Data(capacity: PacketConstants.nonceSize)
        
        nonceData.append(contentsOf: sessionIdBytes)
        
        var seqBE = sequenceNumber.bigEndian
        nonceData.append(Data(bytes: &seqBE, count: 4))
        
        nonceData.append(versionAndTypeByte)
        
        nonceData.append(contentsOf: PacketConstants.protocolDomainTag)
        return nonceData
    }
}
```
- **Baris 137–156:** `authenticatedAssociatedData()` menghasilkan AAD 10-bita: Bita 0 (version/type), Bita 1 (hopLimit), **Bita 2 secara ketat ditopeng ke `0x00`**, Bita 3..5 (sessionId), dan Bita 6..9 (sequenceNumber).
- **Baris 158–177:** `constructNonce()` menyusun Nonce AEAD 12-bita deterministik:
  - Bita 0..2: `sessionId` 3-bita
  - Bita 3..6: `sequenceNumber` 4-bita (big-endian)
  - Bita 7: `versionAndType` 1-bita
  - Bita 8..11: Tag domain 4-bita `[0x54, 0x4B, 0x4D, 0x33]` ("TKM3").

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Mengapa Menopeng `hopCount` ke `0x00` di AAD:** Dalam penerusan mesh multi-hop, node relai perantara harus menaikkan `hopCount` sebesar 1 sebelum menyiarkan paket ke hop berikutnya. Jika `hopCount` dimasukkan ke dalam AAD secara mentah, menaikkannya akan membatalkan tag MAC Poly1305 16-bita milik pengirim, menyebabkan node penerima menolak paket sebagai paket yang telah dirusak. Dengan menopeng Bita 2 menjadi `0x00` selama penyegelan dan pembukaan, jumlah hop tetap dapat diubah pada kawat sementara 9 bita lainnya (versi, tipe, batas hop, ID sesi, nomor urut) tetap sepenuhnya anti-perusakan.
- **Pemisahan Nomor Urut Slot Anggota:** Mengalokasikan 8 bit atas dari `sequenceNumber` ke `memberSlot` memastikan bahwa setiap peserta kelompok memelihara penghitung urutan 24-bit yang independen ($0$ hingga $16.777.215$). Bahkan jika dua anggota mentransmisikan secara bersamaan, nomor urut lengkap mereka tidak akan pernah bertabrakan, menjamin nonce AEAD yang selalu unik.

---

## 4. Teekum/Teekum/Core/Packets/RawWirePacket.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [RawWirePacket.swift](../../Teekum/Teekum/Core/Packets/RawWirePacket.swift) |
| **Jumlah Baris (`wc -l`)** | 54 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct RawWirePacket: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`; aman untuk penyaluran lintas aktor. |
| **Peran Arsitektural** | Wadah datagram kawat kanonik 56-bita yang mengikat CleartextEnvelope 10-bita, ciphertext 30-bita, dan tag otentikasi Poly1305 16-bita. |

### Apa yang Dilakukan Berkas Ini
`RawWirePacket.swift` mewakili datagram kawat 56-bita kanonik yang melintasi saluran radio fisik. Berkas ini mengikat tiga komponen bersebelahan menjadi satu tipe nilai yang tidak dapat bermutasi: `CleartextEnvelope` tidak terenkripsi 10-bita (Bita 0..9), muatan ciphertext terenkripsi 30-bita (Bita 10..39), dan tag otentikasi Poly1305 16-bita (Bita 40..55). Berkas ini menyediakan konversi dua arah antara paket terstruktur dan `Data` biner mentah.

### Analogi Bahasa Awam (ELI5)
Bayangkan `RawWirePacket` sebagai wadah pengiriman standar yang dibuat untuk kereta kargo khusus. Kereta hanya akan menerima wadah yang panjangnya tepat 56 sentimeter—tidak boleh lebih, tidak boleh kurang. Bagian depan 10 sentimeter adalah label pengiriman yang dapat dibaca siapa saja (`CleartextEnvelope`), bagian tengah 30 sentimeter adalah brankas baja terkunci yang memegang surat pribadi (`ciphertext`), dan bagian akhir 16 sentimeter adalah segel lilin anti-perusakan dengan lambang terukir (`authTag`).

### Istilah Teknis yang Didefinisikan
- **Datagram Kawat (*Wire Datagram*):** Entitas data yang mandiri dan independen yang membawa informasi yang cukup untuk dirutekan dari komputer sumber ke tujuan tanpa ketergantungan pada pertukaran sebelumnya.
- **Tag MAC Poly1305:** Pengotentikasi kriptografis sekali pakai 128-bit (16-bita) yang dihitung atas ciphertext dan AAD menggunakan kunci sekali pakai yang diturunkan dari ChaCha20.
- **Pemotongan Buffer (*Buffer Slicing* / `subdata`):** Mengekstrak potongan bita yang berurutan dari buffer `Data` tanpa menyalin memori jika memungkinkan.
- **Invarian Buffer Tetap (*Fixed-Buffer Invariant*):** Memastikan bahwa setiap pesan protokol yang valid dipetakan ke ukuran bita yang identik, mencegah analisis panjang paket dan buffer overrun.

### Penelusuran Blok Kode dan Baris demi Baris
```swift
// Baris 1-54
//
//  RawWirePacket.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct RawWirePacket: Equatable, Sendable {
    public var envelope: CleartextEnvelope
    public var ciphertext: Data // 30 bytes
    public var authTag: Data    // 16 bytes
    
    public init(envelope: CleartextEnvelope, ciphertext: Data, authTag: Data) {
        self.envelope = envelope
        self.ciphertext = ciphertext
        self.authTag = authTag
    }
    
    /// Combines envelope (10B), encrypted payload (30B), and auth tag (16B) into exactly 56 bytes.
    public func toWireData() throws -> Data {
        let envData = envelope.serialize()
        guard envData.count == PacketConstants.cleartextEnvelopeSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.cleartextEnvelopeSize, actual: envData.count)
        }
        guard ciphertext.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.encryptedPayloadSize, actual: ciphertext.count)
        }
        guard authTag.count == PacketConstants.authTagSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.authTagSize, actual: authTag.count)
        }
        
        var packet = Data(capacity: PacketConstants.wirePacketSize)
        packet.append(envData)
        packet.append(ciphertext)
        packet.append(authTag)
        return packet
    }
    
    /// Parses a 56-byte binary datagram from the network.
    public static func fromWireData(_ data: Data) throws -> RawWirePacket {
        guard data.count == PacketConstants.wirePacketSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.wirePacketSize, actual: data.count)
        }
        
        let envData = data.subdata(in: 0..<10)
        let envelope = try CleartextEnvelope.deserialize(from: envData)
        let ciphertext = data.subdata(in: 10..<40)
        let authTag = data.subdata(in: 40..<56)
        
        return RawWirePacket(envelope: envelope, ciphertext: ciphertext, authTag: authTag)
    }
}
```
- **Baris 1–8:** Header berkas dan impor Foundation.
- **Baris 10–13:** Mendeklarasikan `public struct RawWirePacket: Equatable, Sendable` dengan properti tersimpan: `envelope` (CleartextEnvelope), `ciphertext` (Data 30 bita), dan `authTag` (Data 16 bita).
- **Baris 15–19:** Penginisialisasi standar.
- **Baris 21–38:** `toWireData()`: membuat serialisasi amplop, melakukan pemeriksaan panjang yang ketat pada setiap komponen (`envData.count == 10`, `ciphertext.count == 30`, `authTag.count == 16`), mengalokasikan buffer `Data` 56-bita terlebih dahulu, menambahkan ketiga potongan secara berurutan, dan mengembalikan buffer yang digabungkan.
- **Baris 40–53:** `fromWireData(_ data:)`: memvalidasi bahwa `data.count == 56`. Memotong Bita 0..<10 untuk `CleartextEnvelope.deserialize`, Bita 10..<40 untuk `ciphertext`, dan Bita 40..<56 untuk `authTag`, mengembalikan `RawWirePacket` yang dirakit.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Pemeriksaan Ukuran Ketat Terhadap Kerusakan Memori:** Jika rutinitas enkripsi mengembalikan ciphertext 28-bita atau tag 15-bita, mentransmisikannya akan merusak perataan bita pada frame penerima. Memeriksa ketiga segmen secara individual dalam `toWireData()` menjamin bahwa paket yang salah format gagal secara lokal sebelum menyentuh radio.
- **Pemotongan Batas Offset:** Dalam `fromWireData`, offset `0..<10`, `10..<40`, dan `40..<56` dikodekan secara kaku (*hardcoded*) untuk mematuhi invarian spesifikasi protokol.

---

## 5. Teekum/Teekum/Core/Packets/PacketType.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [PacketType.swift](../../Teekum/Teekum/Core/Packets/PacketType.swift) |
| **Jumlah Baris (`wc -l`)** | 19 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum nilai (`public enum PacketType: UInt8, Sendable, CaseIterable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`; aman untuk thread. |
| **Peran Arsitektural** | Enumerasi opcode paket kawat yang mendefinisikan 8 jenis datagram aktif (0x01 hingga 0x08) dan serialisasi opcode. |

### Apa yang Dilakukan Berkas Ini
`PacketType.swift` mendefinisikan 8 opcode datagram aktif yang dikenali oleh tumpukan jaringan mesh Meepo. Setiap kasus didukung oleh integer 8-bit tanpa tanda (`UInt8`) yang menempati 4 bit bawah (nibble rendah) dari Bita 0 di amplop kawat. Enum ini memungkinkan penyalur paket masuk mengklasifikasikan lalu lintas menjadi ping lokasi, peringatan darurat, pembaruan titik temu, permintaan perutean AODV, tanda terima pengiriman, dan pesan obrolan.

### Analogi Bahasa Awam (ELI5)
Bayangkan `PacketType.swift` sebagai katalog prangko berkode warna yang digunakan oleh ruang surat zona bencana. Ketika sebuah amplop tiba, petugas surat melihat bagian bawah prangko pertama untuk mengetahui jenis surat apa yang ada di dalamnya: merah untuk SOS darurat (`0x02`), biru untuk koordinat lokasi (`0x01`), kuning untuk catatan obrolan (`0x07`), atau hijau untuk titik kumpul (`0x03`).

### Istilah Teknis yang Didefinisikan
- **Opcode (Operation Code):** Nilai numerik tersandi yang menentukan operasi yang dimaksudkan atau format pesan dalam protokol jaringan biner.
- **Nibble Rendah (*Low Nibble*):** 4 bit bawah dari satu bita 8-bit (`byte & 0x0F`), mampu mewakili nilai dari `0x0` hingga `0xF` (0 hingga 15).
- **`CaseIterable`:** Protokol pustaka standar Swift yang secara otomatis menyintesis koleksi `allCases` yang berisi setiap kasus dalam enumerasi, memfasilitasi pengujian unit yang komprehensif.
- **`RawRepresentable`:** Protokol Swift yang menyediakan konversi dua arah antara kasus enum kustom dan nilai primitif dasar (di sini `UInt8`).

### Penelusuran Blok Kode dan Baris demi Baris
```swift
// Baris 1-19
//
//  PacketType.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum PacketType: UInt8, CaseIterable, Sendable {
    case locationPing  = 0x01
    case sos           = 0x02
    case meetingUpdate = 0x03
    case routeReq      = 0x04
    case routeResp     = 0x05
    case ack           = 0x06
    case chatMessage   = 0x07
    case sosResolved   = 0x08
}
```
- **Baris 1–8:** Komentar header dan impor Foundation.
- **Baris 10:** Mendeklarasikan `public enum PacketType: UInt8, CaseIterable, Sendable`.
- **Baris 11:** `case locationPing = 0x01`: Koordinat GPS periodik, level baterai, kecepatan, dan inisial pengirim.
- **Baris 12:** `case sos = 0x02`: Suar darurat berprioritas tinggi yang menyiarkan koordinat darurat dan pemicu sirine.
- **Baris 13:** `case meetingUpdate = 0x03`: Lokasi titik kumpul kelompok, waktu target epoch, dan status kehadiran.
- **Baris 14:** `case routeReq = 0x04`: Datagram permintaan rute reaktif AODV yang mencari jalur multi-hop ke tujuan.
- **Baris 15:** `case routeResp = 0x05`: Datagram balasan rute reaktif AODV yang membangun jalur kembali.
- **Baris 16:** `case ack = 0x06`: Konfirmasi pengiriman ujung-ke-ujung (*end-to-end*) yang mengakui penerimaan frame obrolan atau bahaya.
- **Baris 17:** `case chatMessage = 0x07`: Muatan pesan teks efemeral 20-bita.
- **Baris 18:** `case sosResolved = 0x08`: Pembatalan darurat yang menyiarkan bahwa status bahaya telah berakhir.
- **Baris 19:** Menutup enumerasi.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Alokasi Nibble 4-Bit:** Karena Bita 0 di `CleartextEnvelope` mengalokasikan 4 bit atas untuk versi protokol dan 4 bit bawah untuk jenis paket, opcode dibatasi secara ketat pada `0x01` hingga `0x0F`.
- **Opcode Cadangan:** Opcode `0x00` dan `0x09` hingga `0x0F` dicadangkan. Paket apa pun yang tiba dengan opcode di luar `0x01...0x08` menyebabkan `CleartextEnvelope.deserialize` melempar `PacketCodecError.unknownPacketType`.

---

## 6. Teekum/Teekum/Core/Packets/PacketCodecError.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [PacketCodecError.swift](../../Teekum/Teekum/Core/Packets/PacketCodecError.swift) |
| **Jumlah Baris (`wc -l`)** | 55 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum nilai (`public enum PacketCodecError: Error, Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe galat `Sendable`; propagasi galat yang aman untuk thread. |
| **Peran Arsitektural** | Domain galat serialisasi dan deserialisasi yang mencakup underflow buffer, jumlah hop tidak valid, dan opcode paket tidak dikenal. |

### Apa yang Dilakukan Berkas Ini
`PacketCodecError.swift` mendefinisikan domain galat terpadu untuk semua kegagalan serialisasi paket, deserialisasi, buffer underflow, dan validasi dalam tumpukan jaringan mesh. Berkas ini menyediakan kasus kegagalan yang diketik dan deskriptif yang mencakup perbedaan ukuran buffer, versi protokol yang tidak didukung, opcode yang tidak dikenal, batas hop yang tidak valid, koordinat GPS di luar batas, inisial 3 huruf yang salah format, dan pelanggaran pengkodean UTF-8.

### Analogi Bahasa Awam (ELI5)
Bayangkan `PacketCodecError.swift` sebagai kit cap inspeksi kualitas yang digunakan oleh pemeriksa pabrik. Jika paket radio yang dirakit kurang 1 bita, berisi alamat terbalik, atau memiliki angka GPS yang mustahil, inspektur menolak paket tersebut dan mencapnya dengan alasan penolakan yang tepat sehingga teknisi tahu persis mengapa paket tersebut dibuang.

### Istilah Teknis yang Didefinisikan
- **`LocalizedError`:** Protokol Foundation yang memungkinkan tipe galat kustom menyediakan string deskripsi yang dapat dilokalkan dan ramah pengguna melalui properti `errorDescription`.
- **Buffer Underflow:** Galat yang dipicu ketika suatu operasi mencoba membaca lebih banyak bita dari buffer daripada yang sebenarnya tersedia.
- **Domain Galat Equatable:** Mematuhi `Equatable` memungkinkan pengujian unit menegaskan kasus galat yang diharapkan secara tepat menggunakan `#expect(error == PacketCodecError.bufferUnderflow)` tanpa pencocokan string.
- **Nilai Terkait (*Associated Values*):** Fitur bahasa Swift yang memungkinkan metadata kontekstual tertentu (misalnya jumlah bita yang diharapkan vs. aktual) diikat langsung ke kasus enum.

### Penelusuran Blok Kode dan Baris demi Baris
```swift
// Baris 1-55
//
//  PacketCodecError.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum PacketCodecError: Error, LocalizedError, Equatable {
    case invalidPacketSize(expected: Int, actual: Int)
    case unsupportedVersion(UInt8)
    case unknownPacketType(UInt8)
    case invalidHopLimit(UInt8)
    case hopCountExceededLimit(count: UInt8, limit: UInt8)
    case invalidCoordinateRange(latitude: Double, longitude: Double)
    case invalidBatteryLevel(UInt8)
    case payloadSerializationFailed
    case payloadDeserializationFailed
    case bufferUnderflow
    case invalidInitials(String)
    case invalidTextLength(Int)
    case invalidTextEncoding
    
    public var errorDescription: String? {
        switch self {
        case let .invalidPacketSize(expected, actual):
            return "Invalid packet size: expected \(expected) bytes, got \(actual) bytes."
        case let .unsupportedVersion(v):
            return "Unsupported protocol version: \(v)."
        case let .unknownPacketType(t):
            return "Unknown packet type identifier: \(t)."
        case let .invalidHopLimit(limit):
            return "Invalid hop limit \(limit): must be in range 1...15."
        case let .hopCountExceededLimit(count, limit):
            return "Hop count \(count) exceeded maximum hop limit \(limit)."
        case let .invalidCoordinateRange(lat, lon):
            return "Coordinate outside geographic boundaries: lat=\(lat), lon=\(lon)."
        case let .invalidBatteryLevel(b):
            return "Battery level \(b)% exceeds maximum valid range 0...100%."
        case .payloadSerializationFailed:
            return "Failed to serialize payload to exactly 30 bytes."
        case .payloadDeserializationFailed:
            return "Failed to deserialize 30-byte payload."
        case .bufferUnderflow:
            return "Buffer underflow while reading wire bytes."
        case let .invalidInitials(i):
            return "Invalid 3-letter initials: '\(i)'. Must be exactly 3 uppercase letters A-Z."
        case let .invalidTextLength(len):
            return "Invalid text length: \(len) bytes. Must be between 0 and 20 bytes."
        case .invalidTextEncoding:
            return "Invalid text encoding: string content is not valid UTF-8."
        }
    }
}
```
- **Baris 10:** Mendeklarasikan `public enum PacketCodecError: Error, LocalizedError, Equatable`.
- **Baris 11–23:** Menghitung 13 kasus galat eksplisit dengan nilai diagnostik terkait:
  - `invalidPacketSize`: Ketidakcocokan ukuran buffer.
  - `unsupportedVersion`: Bita versi protokol bukan `0x01`.
  - `unknownPacketType`: Opcode tidak dalam `0x01...0x08`.
  - `invalidHopLimit`: Batas hop `< 1` atau `> 15`.
  - `hopCountExceededLimit`: Jumlah hop aktif melebihi batas terkonfigurasi.
  - `invalidCoordinateRange`: Lintang di luar `[-90, 90]` atau bujur di luar `[-180, 180]`.
  - `invalidBatteryLevel`: Level baterai melebihi 100%.
  - `payloadSerializationFailed`: Muatan tidak dapat dikemas ke dalam 30 bita.
  - `payloadDeserializationFailed`: Bita muatan rusak atau tidak dapat diurai.
  - `bufferUnderflow`: Buffer data lebih pendek dari batas bita yang diperlukan.
  - `invalidInitials`: Inisial peserta bukan 3 karakter huruf besar A-Z.
  - `invalidTextLength`: Pesan obrolan melebihi 20 bita.
  - `invalidTextEncoding`: Bita obrolan bukan UTF-8 yang valid.
- **Baris 25–54:** `errorDescription` menyintesis string diagnostik bahasa yang jelas untuk setiap kasus.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Perlindungan Deserialisasi Menyeluruh:** Data radio yang tiba melalui Bluetooth Low Energy pada dasarnya tidak dapat dipercaya. Tanpa validasi kodek yang ketat, penyerang dapat menyuntikkan aliran bita acak yang memicu *integer overflow* atau kerusakan memori. Menyediakan kasus galat granular memastikan bahwa paket yang salah format dibuang secara bersih dengan telemetri diagnostik.

---

## 7. Teekum/Teekum/Core/Packets/ACKStatus.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [ACKStatus.swift](../../Teekum/Teekum/Core/Packets/ACKStatus.swift) |
| **Jumlah Baris (`wc -l`)** | 13 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum nilai (`public enum ACKStatus: UInt8, Sendable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`. |
| **Peran Arsitektural** | Enumerasi status konfirmasi pengiriman yang mengklasifikasikan hasil tanda terima (delivered, timedOut, failed). |

### Apa yang Dilakukan Berkas Ini
`ACKStatus.swift` mendefinisikan tahap-tahap konfirmasi pengiriman operasional yang dibawa di dalam struktur `ACKPayload` 30-bita. Berkas ini membedakan antara pengakuan relai perantara (mengonfirmasi bahwa hop mesh perantara meneruskan paket) dan pengakuan pengiriman rekan ujung-ke-ujung (mengonfirmasi bahwa perangkat rekan tujuan telah menerima, mendekripsi, dan menampilkan pesan).

### Analogi Bahasa Awam (ELI5)
Bayangkan `ACKStatus` sebagai dua tanda centang pada aplikasi perpesanan. Satu tanda centang berarti paket radio Anda diambil oleh stasiun relai relawan di sepanjang jalan (`relayedByMeshHop`). Dua tanda centang berarti paket tersebut secara fisik telah diantarkan langsung ke tangan rekan Anda (`deliveredToFriend`).

### Istilah Teknis yang Didefinisikan
- **ACK Hop Perantara (*Intermediate Hop ACK*):** Tanda terima yang dikembalikan oleh node perantara yang mengonfirmasi bahwa ia telah menerima paket dan berhasil meneruskannya ke hop berikutnya.
- **ACK Penerima Ujung-ke-Ujung (*End-to-End Recipient ACK*):** Konfirmasi kriptografis yang berasal secara ketat dari node tujuan akhir yang mengonfirmasi pengiriman pesan secara lengkap.
- **Opcode `RawRepresentable`:** Didukung oleh `UInt8`, memetakan langsung ke 1 bita dalam muatan kawat.

### Penelusuran Blok Kode dan Baris demi Baris
```swift
// Baris 1-13
//
//  ACKStatus.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum ACKStatus: UInt8, CaseIterable, Sendable {
    case deliveredToFriend = 0x01
    case relayedByMeshHop  = 0x02
}
```
- **Baris 1–8:** Komentar header dan impor Foundation.
- **Baris 10:** Mendeklarasikan `public enum ACKStatus: UInt8, CaseIterable, Sendable`.
- **Baris 11:** `case deliveredToFriend = 0x01`: Pengakuan ujung-ke-ujung dari penerima target.
- **Baris 12:** `case relayedByMeshHop = 0x02`: Pengakuan relai perantara yang mengonfirmasi penerusan hop.
- **Baris 13:** Menutup enumerasi.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Mengapa Memisahkan ACK Hop dan Rekan:** Dalam jaringan mesh ad-hoc, mengetahui bahwa sebuah paket berhasil melompat ke tetangga memberikan umpan balik perutean yang vital (mencegah coba ulang segera yang tidak perlu), tetapi tidak boleh disalahartikan oleh UI sebagai bukti bahwa penerima telah membaca pesan tersebut. Membedakan `0x01` dari `0x02` menjaga kebenaran pengiriman secara utuh.

---

## 8. Teekum/Teekum/Core/Packets/Payloads/ACKPayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [ACKPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ACKPayload.swift) |
| **Jumlah Baris (`wc -l`)** | 93 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct ACKPayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita yang mengonfirmasi penerimaan pesan dengan inisial penerima, penghitung urutan, dan stempel waktu milidetik. |

### Apa yang Dilakukan Berkas Ini
`ACKPayload.swift` mendefinisikan muatan biner 30-bita untuk paket Tipe `0x06` (`ack`). Berkas ini membawa konfirmasi pengiriman untuk pesan obrolan, peringatan darurat, dan pembaruan titik kumpul. Muatan ini mengemas nomor urut yang diakui (4 bita), inisial pengirim (2 bita), stempel waktu (4 bita), status ACK (1 bita), RSSI yang diterima (1 bita), ID peristiwa asli (4 bita), inisial penerima (2 bita), dan 12 bita bantalan nol cadangan.

### Analogi Bahasa Awam (ELI5)
Bayangkan `ACKPayload` sebagai tanda terima pos pengiriman bersertifikat. Ketika rekan Anda menerima peringatan darurat atau pesan obrolan Anda, ponsel mereka mengisi tanda terima kecil 30-bita ini: "Saya (inisial penerima) telah menerima pesan nomor #X dari Anda (inisial pengirim) pada waktu T dengan kekuatan radio -68 dBm," menandatanganinya, dan mengirimkannya kembali melintasi jaringan mesh sehingga ponsel Anda tahu pesan tersebut telah sampai dengan selamat.

### Istilah Teknis yang Didefinisikan
- **Stempel Waktu Unix Epoch (*Unix Epoch Timestamp*):** Waktu yang diukur sebagai jumlah detik yang berlalu sejak 1 Januari 1970 UTC (`ackTimestamp.timeIntervalSince1970`). Disimpan di sini sebagai integer big-endian 32-bit tanpa tanda.
- **RSSI Bertanda (*Signed RSSI* / `Int8`):** Indikasi Kekuatan Sinyal yang Diterima (*Received Signal Strength Indication*) yang dinyatakan sebagai integer 8-bit bertanda dalam dBm (misalnya `-75` dBm).
- **Bantalan Nol Cadangan (*Reserved Zero-Padding*):** Bita yang tidak terpakai di akhir muatan yang diisi secara ketat dengan angka nol (`0x00`) untuk menjamin bahwa muatan berukuran tepat 30 bita untuk enkripsi ChaCha20.

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Deklarasi Struktur dan Penginisialisasi (Baris 1–40)
```swift
// Baris 1-40
//
//  ACKPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct ACKPayload: Equatable, Sendable {
    public var ackedSeqNumber: UInt32
    public var ackedSenderInitials: String // 3 uppercase characters
    public var ackTimestamp: Date
    public var ackStatus: ACKStatus
    public var receivedRssi: Int8
    public var originalEventId: UInt32
    public var responderInitials: String   // 3 uppercase characters
    
    public init(
        ackedSeqNumber: UInt32,
        ackedSenderInitials: String,
        ackTimestamp: Date = Date(),
        ackStatus: ACKStatus,
        receivedRssi: Int8,
        originalEventId: UInt32,
        responderInitials: String
    ) {
        self.ackedSeqNumber = ackedSeqNumber
        self.ackedSenderInitials = InitialsCodec.sanitize(ackedSenderInitials)
        self.ackTimestamp = ackTimestamp
        self.ackStatus = ackStatus
        self.receivedRssi = receivedRssi
        self.originalEventId = originalEventId
        self.responderInitials = InitialsCodec.sanitize(responderInitials)
    }
```
- **Baris 10:** Mendeklarasikan `public struct ACKPayload: Equatable, Sendable`.
- **Baris 11–17:** Properti tersimpan: `ackedSeqNumber` (UInt32), `ackedSenderInitials` (String), `ackTimestamp` (Date), `ackStatus` (ACKStatus), `receivedRssi` (Int8), `originalEventId` (UInt32), dan `responderInitials` (String).
- **Baris 19–39:** Penginisialisasi membersihkan inisial melalui `InitialsCodec.sanitize` untuk menegakkan batas alfanumerik huruf besar.

#### Blok 2: Serialisasi dan Deserialisasi (Baris 42–93)
```swift
// Baris 42-93
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        var seq = ackedSeqNumber.bigEndian
        data.append(Data(bytes: &seq, count: 4))
        
        let ackedBytes = InitialsCodec.encode(ackedSenderInitials) ?? [0, 0]
        data.append(contentsOf: ackedBytes)
        
        var ts = UInt32(ackTimestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        data.append(ackStatus.rawValue)
        
        var rssi = receivedRssi
        data.append(Data(bytes: &rssi, count: 1))
        
        var eventId = originalEventId.bigEndian
        data.append(Data(bytes: &eventId, count: 4))
        
        let respBytes = InitialsCodec.encode(responderInitials) ?? [0, 0]
        data.append(contentsOf: respBytes)
        
        // 12 bytes reserved padding (30 - 18 = 12)
        data.append(Data(repeating: 0, count: 12))
        return data
    }
    
    public static func deserialize(from data: Data) throws -> ACKPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let seq = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let ackedBytes = [data[4], data[5]]
        let ackedInitials = InitialsCodec.decode(ackedBytes) ?? "UNK"
        
        let tsRaw = data.subdata(in: 6..<10).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let statusByte = data[10]
        let rssi = Int8(bitPattern: data[11])
        let eventId = data.subdata(in: 12..<16).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let respBytes = [data[16], data[17]]
        let respInitials = InitialsCodec.decode(respBytes) ?? "UNK"
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        let status = ACKStatus(rawValue: statusByte) ?? .deliveredToFriend
        
        return ACKPayload(
            ackedSeqNumber: seq,
            ackedSenderInitials: ackedInitials,
            ackTimestamp: date,
            ackStatus: status,
            receivedRssi: rssi,
            originalEventId: eventId,
            responderInitials: respInitials
        )
    }
}
```
- **Baris 42–64:** `serialize()` mengemas tepat 30 bita:
  - Bita 0..3: `ackedSeqNumber` (4 bita big-endian)
  - Bita 4..5: `ackedSenderInitials` (2 bita Base-27)
  - Bita 6..9: `ackTimestamp` (4 bita Unix epoch big-endian)
  - Bita 10: `ackStatus.rawValue` (1 bita)
  - Bita 11: `receivedRssi` (1 bita `Int8` bertanda)
  - Bita 12..15: `originalEventId` (4 bita big-endian)
  - Bita 16..17: `responderInitials` (2 bita Base-27)
  - Bita 18..29: 12 bita bantalan cadangan `0x00` ($4+2+4+1+1+4+2+12 = 30$ bita).
- **Baris 66–92:** `deserialize(from:)` menjaga `data.count >= 30`, mengekstrak bidang menggunakan pemuatan bita big-endian dan `InitialsCodec.decode`, serta mengembalikan struktur payload.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Anggaran Muatan Tepat 30-Bita:** ChaCha20-Poly1305 beroperasi pada muatan teks biasa 30-bita yang tetap. Data aktif menghabiskan 18 bita, menyisakan tepat 12 bita bantalan nol untuk ekstensi masa depan yang kompatibel (seperti metrik rute multi-hop).

---

## 9. Teekum/Teekum/Core/Packets/Payloads/AttendanceStatus.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [AttendanceStatus.swift](../../Teekum/Teekum/Core/Packets/Payloads/AttendanceStatus.swift) |
| **Jumlah Baris (`wc -l`)** | 22 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum nilai (`public enum AttendanceStatus: UInt8, Sendable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`. |
| **Peran Arsitektural** | Enumerasi status kehadiran titik kumpul (attending, declined, pending) untuk sinkronisasi titik temu. |

### Apa yang Dilakukan Berkas Ini
`AttendanceStatus.swift` mendefinisikan status tanggapan titik temu yang disiarkan oleh anggota kelompok dalam menanggapi usulan titik kumpul. Berkas ini menyandikan apakah anggota akan hadir (`0x01`), tidak dapat hadir (`0x02`), atau telah tiba secara fisik di koordinat titik temu (`0x09`).

### Analogi Bahasa Awam (ELI5)
Bayangkan `AttendanceStatus` sebagai tombol konfirmasi kehadiran (RSVP) tiga arah pada undangan acara: "Saya akan hadir", "Tidak bisa hadir", atau "Saya sudah sampai dan menunggu di sini".

### Istilah Teknis yang Didefinisikan
- **Opcode RSVP:** Bendera status 1-bita yang diserialisasikan di dalam paket titik kumpul untuk melaporkan kehadiran.
- **Deteksi Kedatangan (*Arrival Detection*):** Peningkatan status otomatis ke `atMeetingPoint` (`0x09`) yang dipicu oleh geofencing CoreLocation saat perangkat memasuki radius 25 meter dari titik kumpul.

### Penelusuran Blok Kode dan Baris demi Baris
```swift
// Baris 1-22
//
//  AttendanceStatus.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum AttendanceStatus: UInt8, CaseIterable, Codable, Sendable {
    case attending      = 0x01
    case cantMakeIt     = 0x02
    case atMeetingPoint = 0x09
    
    public var title: String {
        switch self {
        case .attending:      return "I'll be there"
        case .cantMakeIt:     return "Can't make it"
        case .atMeetingPoint: return "Arrived"
        }
    }
}
```
- **Baris 10:** Mendeklarasikan `public enum AttendanceStatus: UInt8, CaseIterable, Codable, Sendable`.
- **Baris 11–13:** Kasus enum: `attending = 0x01`, `cantMakeIt = 0x02`, dan `atMeetingPoint = 0x09`.
- **Baris 15–21:** Properti terhitung `title` mengembalikan label UI yang ramah pengguna.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Mengapa `atMeetingPoint` Bernilai `0x09`:** Mempertahankan keselarasan opcode dengan spesifikasi prototipe lama sembari membiarkan nilai `0x03...0x08` terbuka untuk status perantara di masa mendatang (seperti "Sedang Terlambat").

---

## 10. Teekum/Teekum/Core/Packets/Payloads/ChatMessagePayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [ChatMessagePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/ChatMessagePayload.swift) |
| **Jumlah Baris (`wc -l`)** | 146 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct ChatMessagePayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita yang mengemas inisial pengirim, nomor urut, dan hingga 20 bita teks UTF-8 dengan pemotongan batas bita. |

### Apa yang Dilakukan Berkas Ini
`ChatMessagePayload.swift` mengimplementasikan serialisasi biner 30-bita untuk paket Tipe `0x07` (`chatMessage`). Berkas ini membawa pesan mikro taktis efemeral antar anggota regu pencarian dan pertolongan, menegakkan batas maksimum 20 bita UTF-8 yang ketat. Muatan ini mengemas nomor urut monotonik (4 bita), inisial pengirim (2 bita), stempel waktu Unix epoch (4 bita), panjang teks aktual (1 bita), bita teks UTF-8 (hingga 20 bita), dan 3 bita bantalan cadangan nol. Berkas ini juga mencakup preset balasan cepat standar.

### Analogi Bahasa Awam (ELI5)
Bayangkan `ChatMessagePayload` sebagai pita teleks lapangan taktis atau pesan mikro radio darurat. Karena bandwidth radio melalui puing-puing beton dan reruntuhan bangunan sangat terbatas, setiap pesan dibatasi maksimal 20 bita UTF-8—dioptimalkan secara khusus untuk instruksi lapangan yang mendesak seperti "REGU 4 MENUJU LOKASI", "TRIASE ALPHA AMAN", "BUTUH TANDU", atau "BOCOR GAS SEKTOR B". Jika seorang petugas yang panik mengetik teks yang lebih panjang, kodek memotongnya secara bersih pada batas karakter Unicode yang sah, memastikan tidak ada karakter yang rusak atau terpotong tiba di ponsel anggota tim.

### Istilah Teknis yang Didefinisikan
- **Pemotongan Batas Bita UTF-8 (*UTF-8 Byte-Boundary Clamping*):** Proses memotong string agar sesuai dengan kuota bita (20 bita) tanpa membelah karakter Unicode multi-bita (seperti emoji atau huruf beraksen), yang jika terbelah akan menghasilkan karakter pengganti tanda tanya rusak (``).
- **Pesan Efemeral Hanya-RAM (*RAM-Only Ephemeral Messaging*):** Pesan yang didekripsi dan disimpan secara ketat di memori kerja selama aplikasi berjalan, tidak pernah disimpan ke disk, dan dibersihkan sepenuhnya saat keluar dari sesi.
- **Chip Preset (*Preset Chips*):** Balasan cepat 1-ketukan yang telah ditentukan sebelumnya yang pas di dalam batas 20 bita (misalnya `"I need help"`, `"Where are you?"`, `"I'm safe"`).

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Deklarasi Struktur, Konstanta & Preset (Baris 1–46)
```swift
// Baris 1-46
//
//  ChatMessagePayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct ChatMessagePayload: Equatable, Sendable {
    public static let maxTextBytes: Int = 20
    public static let reservedBytesCount: Int = 3
    
    // MARK: - Quick Replies
    public static let presetINeedHelp = "I need help"
    public static let presetWhereAreYou = "Where are you?"
    public static let presetImSafe = "I'm safe"
    public static let presetAtTheShelter = "At the shelter"
    public static let presetIveArrived = "I've arrived"
    public static let presetCallMe = "Call me"
    
    public static let allPresets: [String] = [
        presetINeedHelp,
        presetWhereAreYou,
        presetImSafe,
        presetAtTheShelter,
        presetIveArrived,
        presetCallMe
    ]
    
    public var sequenceNumber: UInt32
    public var senderInitials: String // 3 uppercase characters
    public var timestamp: Date
    public var text: String           // Up to 20 bytes UTF-8
```
- **Baris 10:** Mendeklarasikan `public struct ChatMessagePayload: Equatable, Sendable`.
- **Baris 11–12:** Konstanta: `maxTextBytes = 20` dan `reservedBytesCount = 3`.
- **Baris 15–29:** String preset dan array `allPresets` untuk pemilih chip horizontal di UI.
- **Baris 31–34:** Properti tersimpan: `sequenceNumber` (UInt32), `senderInitials` (String), `timestamp` (Date), dan `text` (String).

#### Blok 2: Penginisialisasi & Penjepitan UTF-8 (Baris 48–77)
```swift
// Baris 48-77
    public init(
        sequenceNumber: UInt32,
        senderInitials: String,
        timestamp: Date = Date(),
        text: String
    ) {
        self.sequenceNumber = sequenceNumber
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.timestamp = timestamp
        self.text = ChatMessagePayload.clampToByteBoundary(text, maxBytes: ChatMessagePayload.maxTextBytes)
    }
    
    public static func clampToByteBoundary(_ string: String, maxBytes: Int) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        if data.count <= maxBytes { return string }
        
        var clampedData = data.prefix(maxBytes)
        while !clampedData.isEmpty {
            if let validString = String(data: clampedData, encoding: .utf8) {
                return validString
            }
            clampedData = clampedData.dropLast()
        }
        return ""
    }
```
- **Baris 48–56:** Penginisialisasi membersihkan inisial pengirim dan memotong teks ke 20 bita UTF-8 menggunakan `clampToByteBoundary`.
- **Baris 58–76:** `clampToByteBoundary`: mengonversi string ke `Data` UTF-8. Jika `<= maxBytes`, mengembalikan string asli. Jika lebih, memotong awalan ke `maxBytes` dan melakukan perulangan mundur membuang bita terakhir hingga `String(data: clampedData, encoding: .utf8)` berhasil mendekode batas karakter Unicode yang sah.

#### Blok 3: Serialisasi & Deserialisasi Kawat (Baris 79–146)
```swift
// Baris 79-146
    public func serialize() throws -> Data {
        guard let textData = text.data(using: .utf8), textData.count <= Self.maxTextBytes else {
            throw PacketCodecError.invalidTextLength(text.utf8.count)
        }
        
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        
        // Bytes 0..3: sequenceNumber (4 bytes)
        var seq = sequenceNumber.bigEndian
        data.append(Data(bytes: &seq, count: 4))
        
        // Bytes 4..5: senderInitials (2 bytes)
        let initialsBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialsBytes)
        
        // Bytes 6..9: timestamp (4 bytes)
        var ts = UInt32(timestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        // Byte 10: textLength (1 byte)
        data.append(UInt8(textData.count))
        
        // Bytes 11..<11+textLength: textData
        data.append(textData)
        
        // Remaining bytes zero-padded up to 27 bytes (11 + 20 - 4 reserved = 27)
        let paddingNeeded = Self.maxTextBytes - textData.count
        if paddingNeeded > 0 {
            data.append(Data(repeating: 0, count: paddingNeeded))
        }
        
        // Bytes 27..29: 3 reserved bytes
        data.append(Data(repeating: 0, count: Self.reservedBytesCount))
        
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadSerializationFailed
        }
        return data
    }
    
    public static func deserialize(from data: Data) throws -> ChatMessagePayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let seq = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let initialsBytes = [data[4], data[5]]
        let initials = InitialsCodec.decode(initialsBytes) ?? "UNK"
        
        let tsRaw = data.subdata(in: 6..<10).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let textLen = Int(data[10])
        guard textLen <= Self.maxTextBytes else {
            throw PacketCodecError.invalidTextLength(textLen)
        }
        
        let textBytes = data.subdata(in: 11..<(11 + textLen))
        guard let text = String(data: textBytes, encoding: .utf8) else {
            throw PacketCodecError.invalidTextEncoding
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        return ChatMessagePayload(
            sequenceNumber: seq,
            senderInitials: initials,
            timestamp: date,
            text: text
        )
    }
}
```
- **Baris 79–110:** `serialize()`: memverifikasi panjang teks, menyandikan `sequenceNumber` 4-bita big-endian, `senderInitials` 2-bita Base-27, stempel waktu Unix 4-bita big-endian, `textLength` 1-bita, `textData` UTF-8 mentah, mengisi sisa ruang teks dengan angka nol hingga 20 bita, dan menambahkan 3 bita cadangan nol ($4+2+4+1+20+3 = 30$ bita).
- **Baris 112–145:** `deserialize(from:)`: membongkar 30 bita, membaca panjang di Bita 10, memotong Bita 11..<(11+textLen), mendekode UTF-8, dan memvalidasi batas.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Pemotongan Unicode Multi-Bita:** Memotong string Swift secara naif berdasarkan indeks karakter atau mengambil awalan bita mentah dapat membelah emoji 4-bita (seperti simbol api atau tanda peringatan). `clampToByteBoundary` secara iteratif membuang bita belakang sampai `String(data:encoding:.utf8)` berhasil, memastikan karakter yang salah bentuk tidak pernah mencapai transmisi kawat.
- **Invarian Buffer Tetap:** Terlepas dari apakah pesan obrolan berukuran 2 bita atau 20 bita, keluaran terserialisasi selalu diisi bantalan nol menjadi tepat 30 bita untuk mempertahankan frame kawat 56-bita yang invarian.

---

## 11. Teekum/Teekum/Core/Packets/Payloads/LocationPingPayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [LocationPingPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/LocationPingPayload.swift) |
| **Jumlah Baris (`wc -l`)** | 106 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct LocationPingPayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita yang mengemas lintang/bujur terkuantisasi (Int32), akurasi horizontal, status baterai, dan inisial pengirim. |

### Apa yang Dilakukan Berkas Ini
`LocationPingPayload.swift` mengimplementasikan serialisasi biner 30-bita untuk paket Tipe `0x01` (`locationPing`). Berkas ini menyandikan koordinat GPS periodik, akurasi horizontal, persentase baterai perangkat, kecepatan gerakan, arah kompas, dan inisial pengirim. Koordinat dikemas ke dalam bilangan bulat bertanda 32-bit (`Int32`) yang memberikan resolusi ~11cm di seluruh dunia, disertai dengan 11 bita bantalan cadangan nol.

### Analogi Bahasa Awam (ELI5)
Bayangkan `LocationPingPayload` sebagai suar radio otomatis yang dipancarkan ponsel Anda setiap beberapa detik. Suar ini memberi tahu semua orang di kelompok zona bencana Anda: "Ini NIC, saya berdiri di koordinat GPS tepat ini dalam akurasi 5 meter, kompas saya mengarah ke 180 derajat selatan, dan baterai saya berada di 74%."

### Istilah Teknis yang Didefinisikan
- **Faktor Skala Koordinat Titik-Tetap (*Fixed-Point Coordinate Scaling Factor*):** Mengalikan lintang dan bujur dengan $10^7$ (`10.000.000,0`) untuk mengubah derajat pecahan menjadi bilangan bulat 32-bit bertanda (`Int32`), mencapai presisi ~11mm di khatulistiwa.
- **Baterai Terjepit UInt8 (*Clamped Battery UInt8*):** Mengonversi desimal baterai ternormalisasi 0.0...1.0 menjadi integer tanpa tanda 8-bit yang dijepit antara `0` dan `100`.
- **Bita Kompas Terkuantisasi (*Quantized Compass Byte*):** Menskalakan 0..<360 derajat kompas menjadi 0...255 (`UInt8`) agar menempati tepat 1 bita.

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Deklarasi Struktur dan Properti (Baris 1–45)
```swift
// Baris 1-45
//
//  LocationPingPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CoreLocation

public struct LocationPingPayload: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var timestamp: Date
    public var accuracy: UInt8
    public var batteryLevel: UInt8
    public var speed: UInt8
    public var heading: UInt8
    public var senderInitials: String // 3 uppercase characters
    public var colorCode: UInt8
    
    public init(
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        accuracy: UInt8,
        batteryLevel: UInt8 = 100,
        speed: UInt8 = 0,
        heading: UInt8 = 0,
        senderInitials: String,
        colorCode: UInt8 = 0x00
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.accuracy = accuracy
        self.batteryLevel = min(batteryLevel, 100)
        self.speed = speed
        self.heading = heading
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.colorCode = colorCode
    }
```
- **Baris 1–11:** Header dan impor (`Foundation`, `CoreLocation`).
- **Baris 12–20:** Properti tersimpan: `coordinate` (CLLocationCoordinate2D), `timestamp` (Date), `accuracy` (UInt8 dalam meter), `batteryLevel` (UInt8 0...100), `speed` (UInt8 dalam m/s), `heading` (bita kompas terkuantisasi UInt8), `senderInitials` (String), dan `colorCode` (warna profil UInt8).
- **Baris 22–45:** Penginisialisasi menjepit `batteryLevel` ke `100` dan membersihkan `senderInitials`.

#### Blok 2: Serialisasi dan Deserialisasi (Baris 47–106)
```swift
// Baris 47-106
    public func serialize() throws -> Data {
        guard coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
              coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        
        var lat = coordinate.rawLatitude.bigEndian
        data.append(Data(bytes: &lat, count: 4))
        
        var lon = coordinate.rawLongitude.bigEndian
        data.append(Data(bytes: &lon, count: 4))
        
        var ts = UInt32(timestamp.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        data.append(accuracy)
        data.append(min(batteryLevel, 100))
        data.append(speed)
        data.append(heading)
        
        let initialBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialBytes)
        
        data.append(colorCode)
        
        // 11 bytes reserved padding (30 - 19 = 11)
        data.append(Data(repeating: 0, count: 11))
        
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadSerializationFailed
        }
        return data
    }
    
    public static func deserialize(from data: Data) throws -> LocationPingPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let latRaw = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let lonRaw = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let tsRaw = data.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let accuracy = data[12]
        let battery = data[13]
        let speed = data[14]
        let heading = data[15]
        
        let initialBytes = [data[16], data[17]]
        let initials = InitialsCodec.decode(initialBytes) ?? "UNK"
        let colorCode = data.count > 18 ? data[18] : 0
        
        let coord = CLLocationCoordinate2D.dequantize(latitudeRaw: latRaw, longitudeRaw: lonRaw)
        guard coord.latitude >= -90.0 && coord.latitude <= 90.0 && coord.longitude >= -180.0 && coord.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coord.latitude, longitude: coord.longitude)
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        
        return LocationPingPayload(
            coordinate: coord,
            timestamp: date,
            accuracy: accuracy,
            batteryLevel: min(battery, 100),
            speed: speed,
            heading: heading,
            senderInitials: initials,
            colorCode: colorCode
        )
    }
}
```
- **Baris 47–75:** `serialize()` memvalidasi garis lintang dalam `[-90, 90]` dan garis bujur dalam `[-180, 180]`. Mengemas 30 bita:
  - Bita 0..3: `lat` (4 bita `Int32` big-endian)
  - Bita 4..7: `lon` (4 bita `Int32` big-endian)
  - Bita 8..11: `timestamp` (4 bita Unix epoch big-endian)
  - Bita 12: `accuracy` (1 bita `UInt8`)
  - Bita 13: `batteryLevel` (1 bita `UInt8`)
  - Bita 14: `speed` (1 bita `UInt8`)
  - Bita 15: `heading` (1 bita `UInt8`)
  - Bita 16..17: `senderInitials` (2 bita Base-27)
  - Bita 18: `colorCode` (1 bita `UInt8`)
  - Bita 19..29: 11 bita bantalan cadangan `0x00` ($4+4+4+1+1+1+1+2+1+11 = 30$ bita).
- **Baris 77–105:** `deserialize(from:)` menjaga batas 30 bita, mengembalikan nilai bulat menjadi `CLLocationCoordinate2D`, memvalidasi batas geografis, mendekode inisial, dan mengembalikan struktur payload.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Validasi Batas Koordinat:** Mencegah garis lintang/bujur yang rusak menyuntikkan nilai NaN atau pin di luar batas ke proyeksi MapKit atau Radar Taktis.

---

## 12. Teekum/Teekum/Core/Packets/Payloads/MeetingAction.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MeetingAction.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingAction.swift) |
| **Jumlah Baris (`wc -l`)** | 15 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum nilai (`public enum MeetingAction: UInt8, Sendable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`. |
| **Peran Arsitektural** | Enumerasi tindakan mutasi titik kumpul (propose, update, cancel) yang mengatur siklus hidup titik temu. |

### Apa yang Dilakukan Berkas Ini
`MeetingAction.swift` mendefinisikan aksi-aksi siklus hidup mutasi untuk titik kumpul kelompok. Dibawa di dalam `MeetingUpdatePayload` (Tipe `0x03`), berkas ini memberi sinyal apakah paket mengusulkan titik kumpul baru (`0x01`), membatalkan titik kumpul yang ada (`0x02`), menerima usulan (`0x03`), atau menolak usulan (`0x04`).

### Analogi Bahasa Awam (ELI5)
Bayangkan `MeetingAction` sebagai kata kerja aksi pada undangan kalender zona bencana: "Usulkan Titik Kumpul", "Batalkan Titik Kumpul", "Terima", atau "Tolak".

### Istilah Teknis yang Didefinisikan
- **Kata Kerja Aksi Titik Kumpul (*Rendezvous Action Verb*):** Opcode 1-bita yang mengatur apakah titik kumpul dibuat, diubah, atau dihapus di seluruh jaringan mesh.
- **Mutasi Penguncian Pembuat (*Setter Lock Mutation*):** Hanya anggota yang memegang Setter Lock yang dapat mengeluarkan aksi `.propose` atau `.cancel`.

### Penelusuran Blok Kode dan Baris demi Baris
```swift
// Baris 1-15
//
//  MeetingAction.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum MeetingAction: UInt8, CaseIterable, Sendable {
    case propose = 0x01
    case cancel  = 0x02
    case accept  = 0x03
    case decline = 0x04
}
```
- **Baris 10:** Mendeklarasikan `public enum MeetingAction: UInt8, CaseIterable, Sendable`.
- **Baris 11–14:** Kasus: `propose = 0x01`, `cancel = 0x02`, `accept = 0x03`, `decline = 0x04`.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Determinisme Aksi:** Mengikat aksi titik temu ke nilai mentah 1-bita eksplisit mencegah penafsiran status titik temu yang bertentangan di berbagai versi build perangkat.

---

## 13. Teekum/Teekum/Core/Packets/Payloads/MeetingUpdatePayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MeetingUpdatePayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/MeetingUpdatePayload.swift) |
| **Jumlah Baris (`wc -l`)** | 147 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct MeetingUpdatePayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita yang menyandikan koordinat GPS titik temu, waktu target epoch, slot pembuat, dan opcode tindakan. |

### Apa yang Dilakukan Berkas Ini
`MeetingUpdatePayload.swift` mengimplementasikan serialisasi biner 30-bita untuk paket Tipe `0x03` (`meetingUpdate`). Berkas ini menyinkronkan titik kumpul darurat dan stasiun triase lapangan di seluruh jaringan mesh, menyandikan koordinat GPS pertemuan, waktu epoch target, nama pertemuan (hingga 12 bita UTF-8), inisial pengirim, slot anggota target, dan opcode tindakan. Berkas ini menegakkan arbitrasi Aturan Penguncian Pembuat (*Setter Lock Rule*) pada transmisi kawat.

### Analogi Bahasa Awam (ELI5)
Bayangkan `MeetingUpdatePayload` sebagai siaran resmi Titik Kumpul Taktis & Triase Lapangan yang dipancarkan oleh seorang Komandan Insiden. Siaran ini memberi tahu setiap anggota regu: "Kumpul di Titik Evakuasi Helipad Alpha pada pukul 14:30. Ditetapkan oleh KOMANDAN_REGU_01." Setiap perangkat petugas di dalam sesi menerima pesan 30-bita ini dan secara otomatis memperbarui kompas navigasi, target radar, dan pin petanya.

### Istilah Teknis yang Didefinisikan
- **Aturan Penguncian Pembuat (*Setter Lock Rule*):** Aturan arbitrasi terdistribusi yang menyatakan bahwa sekali seorang anggota menetapkan titik kumpul aktif, anggota lain tidak dapat menimpanya hingga pembuat asli membatalkannya atau waktu terjadwal telah berlalu.
- **Penargetan Slot Anggota (*Member Slot Targeting*):** Pengenal 8-bit yang menargetkan peserta kelompok tertentu saat mengeluarkan tindakan penerimaan atau penolakan pertemuan secara langsung.
- **Pemotongan Nama Pendek (*Short Name Clamping*):** Memotong nama lokasi pertemuan menjadi 12 bita UTF-8 (misalnya `"Posko Medis"`), agar pas di dalam muatan 30-bita yang ketat.

### Penelusuran Blok Kode dan Baris demi Baris

#### Blok 1: Deklarasi Struktur dan Properti (Baris 1–49)
```swift
// Baris 1-49
//
//  MeetingUpdatePayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CoreLocation

public struct MeetingUpdatePayload: Equatable, Sendable {
    public static let maxNameBytes: Int = 12
    
    public var coordinate: CLLocationCoordinate2D
    public var targetTime: Date
    public var name: String          // Up to 12 bytes UTF-8
    public var action: MeetingAction
    public var senderInitials: String // 3 uppercase characters
    public var targetMemberSlot: UInt8
    
    public init(
        coordinate: CLLocationCoordinate2D,
        targetTime: Date,
        name: String,
        action: MeetingAction,
        senderInitials: String,
        targetMemberSlot: UInt8 = 0
    ) {
        self.coordinate = coordinate
        self.targetTime = targetTime
        self.name = ChatMessagePayload.clampToByteBoundary(name, maxBytes: Self.maxNameBytes)
        self.action = action
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.targetMemberSlot = targetMemberSlot
    }
```
- **Baris 1–11:** Mengimpor Foundation dan CoreLocation.
- **Baris 12–19:** Properti tersimpan: `maxNameBytes = 12`, `coordinate` (CLLocationCoordinate2D), `targetTime` (Date), `name` (String hingga 12 bita UTF-8), `action` (MeetingAction), `senderInitials` (String), dan `targetMemberSlot` (UInt8).
- **Baris 21–48:** Penginisialisasi memotong `name` ke 12 bita UTF-8 dan membersihkan `senderInitials`.

#### Blok 2: Serialisasi dan Deserialisasi (Baris 51–147)
```swift
// Baris 51-147
    public func serialize() throws -> Data {
        guard coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
              coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
        guard let nameData = name.data(using: .utf8), nameData.count <= Self.maxNameBytes else {
            throw PacketCodecError.invalidTextLength(name.utf8.count)
        }
        
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        
        var lat = coordinate.rawLatitude.bigEndian
        data.append(Data(bytes: &lat, count: 4))
        
        var lon = coordinate.rawLongitude.bigEndian
        data.append(Data(bytes: &lon, count: 4))
        
        var ts = UInt32(targetTime.timeIntervalSince1970).bigEndian
        data.append(Data(bytes: &ts, count: 4))
        
        data.append(UInt8(nameData.count))
        data.append(nameData)
        
        let paddingNeeded = Self.maxNameBytes - nameData.count
        if paddingNeeded > 0 {
            data.append(Data(repeating: 0, count: paddingNeeded))
        }
        
        data.append(action.rawValue)
        
        let initialBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialBytes)
        
        data.append(targetMemberSlot)
        
        // 1 byte reserved padding (30 - 29 = 1)
        data.append(0x00)
        
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadSerializationFailed
        }
        return data
    }
    
    public static func deserialize(from data: Data) throws -> MeetingUpdatePayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        let latRaw = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let lonRaw = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let tsRaw = data.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let nameLen = Int(data[12])
        guard nameLen <= Self.maxNameBytes else {
            throw PacketCodecError.invalidTextLength(nameLen)
        }
        
        let nameBytes = data.subdata(in: 13..<(13 + nameLen))
        guard let name = String(data: nameBytes, encoding: .utf8) else {
            throw PacketCodecError.invalidTextEncoding
        }
        
        let actionByte = data[25]
        guard let action = MeetingAction(rawValue: actionByte) else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        
        let initialBytes = [data[26], data[27]]
        let initials = InitialsCodec.decode(initialBytes) ?? "UNK"
        let targetSlot = data[28]
        
        let coord = CLLocationCoordinate2D.dequantize(latitudeRaw: latRaw, longitudeRaw: lonRaw)
        guard coord.latitude >= -90.0 && coord.latitude <= 90.0 && coord.longitude >= -180.0 && coord.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coord.latitude, longitude: coord.longitude)
        }
        
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        
        return MeetingUpdatePayload(
            coordinate: coord,
            targetTime: date,
            name: name,
            action: action,
            senderInitials: initials,
            targetMemberSlot: targetSlot
        )
    }
}
```
- **Baris 51–87:** `serialize()` mengemas 30 bita:
  - Bita 0..3: `lat` (4 bita `Int32` big-endian)
  - Bita 4..7: `lon` (4 bita `Int32` big-endian)
  - Bita 8..11: `targetTime` (4 bita Unix epoch big-endian)
  - Bita 12: `nameLength` (1 bita `UInt8`)
  - Bita 13..<13+nameLen: `nameData` (bita UTF-8 mentah)
  - Bantalan nol untuk nama hingga 12 bita
  - Bita 25: `action.rawValue` (1 bita)
  - Bita 26..27: `senderInitials` (2 bita Base-27)
  - Bita 28: `targetMemberSlot` (1 bita)
  - Bita 29: 1 bita bantalan nol cadangan ($4+4+4+1+12+1+2+1+1 = 30$ bita).
- **Baris 89–146:** `deserialize(from:)` menjaga batas 30 bita, mengurai koordinat, nama, opcode aksi, inisial, dan slot target, mengembalikan struktur payload.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Perlindungan Kunci Pembuat pada Kawat:** Membawa `senderInitials` dan `action` di dalam muatan bersegel memungkinkan `MeetingPointService` penerima memverifikasi bahwa permintaan pembatalan berasal dari anggota yang sama yang mengusulkan titik kumpul tersebut, menegakkan integritas Aturan Penguncian Pembuat (*Setter Lock Rule*).

---

## 14. Teekum/Teekum/Core/Packets/Payloads/RouteReqPayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [RouteReqPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteReqPayload.swift) |
| **Jumlah Baris (`wc -l`)** | 59 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct RouteReqPayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita untuk penemuan rute AODV yang membawa inisial target, urutan inisiator, dan metrik akumulasi. |

### Apa yang Dilakukan Berkas Ini
`RouteReqPayload.swift` mengimplementasikan muatan biner untuk permintaan penemuan rute Ad hoc On-Demand Distance Vector (AODV) (`PacketType.routeReq`, opcode `0x05`). Ketika sebuah perangkat ingin mengirim lalu lintas unicast ke rekan yang relai hop berikutnya tidak diketahui atau usang, perangkat tersebut menyiarkan Permintaan Rute (RREQ) yang berisi inisial inisiator, inisial tujuan target, nonce penemuan 32-bit yang unik, dan penghitung akumulasi biaya hop.

### Analogi Bahasa Awam (ELI5)
Bayangkan Pemimpin Regu Alice perlu berkoordinasi dengan Petugas Medis Bob yang beroperasi di balik gedung parkir bertingkat yang runtuh di mana radio garis pandang langsung tidak dapat tembus. Alice menyiarkan Permintaan Rute AODV melintasi mesh: "Ini Alice mencari Medis Bob; Token Pencarian #74829." Node relai relawan terdekat menaikkan jumlah hop dan meneruskan pertanyaan tersebut melintasi sektor bencana. Jika sebuah node telah melihat token #74829 sebelumnya, ia langsung membuangnya untuk mencegah badai gema (*echo storm*). Ketika perangkat Bob menerima kueri tersebut, ia menghasilkan Respons Rute terotentikasi di sepanjang jalur kembali, membangun rute multi-hop yang terverifikasi kembali ke Alice.

### Istilah Teknis yang Didefinisikan
- **AODV (Ad hoc On-Demand Distance Vector):** Protokol perutean reaktif untuk jaringan ad-hoc bergerak di mana rute dibuat secara dinamis hanya saat dibutuhkan oleh upaya komunikasi aktif, meminimalkan overhead kontrol mesh saat menganggur.
- **RREQ (Route Request):** Pesan penemuan AODV yang disiarkan melintasi jaringan untuk mencari jalur ke node tujuan tertentu.
- **Nonce Penemuan (*Discovery Nonce*):** Angka acak 32-bit yang dihasilkan oleh inisiator rute yang, jika dipasangkan dengan identitas inisiator, secara unik mengidentifikasi upaya penemuan dan mencegah putaran siaran (*broadcast loops*).
- **Biaya Rute (*Route Cost* / Metrik Hop):** Bilangan bulat satu bita yang mewakili jarak tautan kumulatif (jumlah lompatan radio) dari inisiator ke node saat ini.
- **Pemuatan Memori Tanpa Perataan (*Unaligned Memory Loading* / `loadUnaligned`):** Membaca integer multi-bita dari batas bita memori sembarang tanpa mengharuskan alamat memori merupakan kelipatan tepat dari perataan bita integer tersebut.

### Penelusuran Blok Kode dan Baris demi Baris

#### Baris 1–26: Deklarasi Tipe dan Penginisialisasi
```swift
//
//  RouteReqPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct RouteReqPayload: Equatable, Sendable {
    public var originatorInitials: String
    public var targetInitials: String
    public var discoveryNonce: UInt32
    public var routeCost: UInt8
    
    public init(
        originatorInitials: String,
        targetInitials: String,
        discoveryNonce: UInt32 = UInt32.random(in: 1...UInt32.max),
        routeCost: UInt8 = 0
    ) {
        self.originatorInitials = InitialsCodec.sanitize(originatorInitials)
        self.targetInitials = InitialsCodec.sanitize(targetInitials)
        self.discoveryNonce = discoveryNonce
        self.routeCost = routeCost
    }
```
- **Baris 10:** Mendeklarasikan `RouteReqPayload` sebagai struktur nilai `Equatable`, `Sendable`.
- **Baris 11–14:** Menyimpan empat bidang penemuan AODV inti: `originatorInitials` (siapa yang memulai pencarian), `targetInitials` (siapa yang dicari), `discoveryNonce` (token pencarian unik 32-bit), dan `routeCost` (penghitung hop).
- **Baris 16–26:** Penginisialisasi publik membersihkan kedua inisial melalui `InitialsCodec.sanitize`. Jika tidak ditentukan, `discoveryNonce` secara default menghasilkan angka acak seragam kriptografis dalam `1...UInt32.max`, sementara `routeCost` default-nya adalah 0.

#### Baris 28–43: Serialisasi ke 30 Bita
```swift
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        let origBytes = InitialsCodec.encode(originatorInitials) ?? [0, 0]
        data.append(contentsOf: origBytes)
        
        let targetBytes = InitialsCodec.encode(targetInitials) ?? [0, 0]
        data.append(contentsOf: targetBytes)
        
        var nonce = discoveryNonce.bigEndian
        data.append(Data(bytes: &nonce, count: 4))
        data.append(routeCost)
        
        // 21 bytes reserved (30 - 9 = 21)
        data.append(Data(repeating: 0, count: 21))
        return data
    }
```
- **Baris 28–29:** Mengalokasikan buffer `Data` dengan kapasitas 30 (`PacketConstants.encryptedPayloadSize`).
- **Baris 30–31:** Menyandikan `originatorInitials` ke dalam 2 bita Base-27 di Bita 0..1.
- **Baris 33–34:** Menyandikan `targetInitials` ke dalam 2 bita Base-27 di Bita 2..3.
- **Baris 36–37:** Mengonversi `discoveryNonce` ke big-endian dan menambahkan 4 bita di Bita 4..7.
- **Baris 38:** Menambahkan `routeCost` satu bita di Bita 8.
- **Baris 40–42:** Menambahkan 21 bita bantalan nol di Bita 9..29 ($2 + 2 + 4 + 1 + 21 = 30$ bita). Mengembalikan muatan terserialisasi 30-bita.

#### Baris 45–58: Deserialisasi dari Aliran Bita Masuk
```swift
    public static func deserialize(from data: Data) throws -> RouteReqPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let origBytes = [data[0], data[1]]
        let orig = InitialsCodec.decode(origBytes) ?? "UNK"
        
        let targetBytes = [data[2], data[3]]
        let target = InitialsCodec.decode(targetBytes) ?? "UNK"
        
        let nonce = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let cost = data[8]
        return RouteReqPayload(originatorInitials: orig, targetInitials: target, discoveryNonce: nonce, routeCost: cost)
    }
}
```
- **Baris 46–48:** Memvalidasi bahwa muatan masuk memiliki setidaknya 30 bita, melempar `PacketCodecError.bufferUnderflow` jika kurang.
- **Baris 49–53:** Mengekstrak dan mendekode `origBytes` dari Bita 0..1 dan `targetBytes` dari Bita 2..3 via `InitialsCodec.decode`, menggunakan nilai default `"UNK"` jika gagal.
- **Baris 55:** Mengekstrak Bita 4..<8 dan memuat `UInt32` big-endian ke dalam `nonce` menggunakan `loadUnaligned`.
- **Baris 56:** Membaca Bita 8 sebagai `routeCost`.
- **Baris 57–58:** Menginstansiasi dan mengembalikan `RouteReqPayload` yang tervalidasi.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **21 Bita Bantalan Cadangan:** Lebih dari 70% ruang muatan ($21/30$ bita) adalah bantalan nol. Ini mempertahankan wadah kawat tetap 56-bita di semua jenis paket, mencegah pihak penyadap melakukan klasifikasi analisis lalu lintas berdasarkan ukuran datagram.
- **Pencegahan Putaran Melalui Nonce Penemuan:** Karena permintaan rute AODV disebarkan secara banjir di seluruh mesh, node perantara mengingat pasangan `(originatorInitials, discoveryNonce)` yang terlihat di cache perutean mereka. Setiap RREQ duplikat langsung dibuang sebelum disiarkan ulang.

---

## 15. Teekum/Teekum/Core/Packets/Payloads/RouteRespPayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [RouteRespPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/RouteRespPayload.swift) |
| **Jumlah Baris (`wc -l`)** | 59 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct RouteRespPayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita untuk balasan rute AODV yang membangun jalur kembali dengan urutan tujuan dan jumlah hop. |

### Apa yang Dilakukan Berkas Ini
`RouteRespPayload.swift` mendefinisikan muatan untuk paket respons rute AODV (`PacketType.routeResp`, opcode `0x06`). Ketika node tujuan (atau rekan perantara yang memegang rute segar ke tujuan) menerima Permintaan Rute, ia membalas dengan Respons Rute unicast. Respons ini memberi tahu inisiator bahwa jalur yang valid telah ditemukan, membawa nonce penemuan yang cocok dengan permintaan asli dan biaya rute awal.

### Analogi Bahasa Awam (ELI5)
Melanjutkan pencarian Alice atas Bob di zona bencana: Bob mendengar panggilan pencarian, menulis kartu pos balasan: "Alice, ini Bob menanggapi token pencarian #74829 Anda! Saya saat ini berjarak 0 hop dari respons ini." Bob menyerahkan kembali kartu tersebut ke rantai rekan yang membawa pesan pencarian kepadanya, membangun rute kembali untuk pesan-pesan Alice.

### Istilah Teknis yang Didefinisikan
- **RREP (Route Response):** Pesan unicast AODV yang dikirim mundur di sepanjang rute balik yang dibentuk oleh RREQ untuk mengonfirmasi keterjangkauan node target.
- **Jalur Balik (*Reverse Path*):** Urutan node relai perantara yang dicatat dalam tabel perutean balik saat RREQ berpindah dari inisiator ke target.
- **Penerusan Mesh Unicast:** Meneruskan paket ke ID/MAC tetangga hop berikutnya yang ditargetkan secara khusus alih-alih menyiarkannya ke semua radio di sekitarnya.
- **Gratuitous RREP:** Respons rute yang dihasilkan secara proaktif oleh relai perantara yang sudah mengetahui jalur ke tujuan yang diminta, menghindari banjir jaringan penuh.

### Penelusuran Blok Kode dan Baris demi Baris

#### Baris 1–26: Deklarasi Tipe dan Penginisialisasi
```swift
//
//  RouteRespPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public struct RouteRespPayload: Equatable, Sendable {
    public var originatorInitials: String
    public var targetInitials: String
    public var discoveryNonce: UInt32
    public var routeCost: UInt8
    
    public init(
        originatorInitials: String,
        targetInitials: String,
        discoveryNonce: UInt32,
        routeCost: UInt8
    ) {
        self.originatorInitials = InitialsCodec.sanitize(originatorInitials)
        self.targetInitials = InitialsCodec.sanitize(targetInitials)
        self.discoveryNonce = discoveryNonce
        self.routeCost = routeCost
    }
```
- **Baris 10:** Mendeklarasikan `RouteRespPayload` sebagai struktur `Equatable`, `Sendable`.
- **Baris 11–14:** Cocok dengan bidang `RouteReqPayload`: `originatorInitials` (pencari yang akan menerima balasan ini), `targetInitials` (target yang menjawab), `discoveryNonce` (token yang cocok), dan `routeCost` (akumulator hop).
- **Baris 16–26:** Penginisialisasi publik. Perhatikan bahwa tidak seperti `RouteReqPayload`, `discoveryNonce` tidak memiliki generator acak default karena RREP wajib secara ketat mencerminkan nonce persis yang diterima di RREQ terkait.

#### Baris 28–43: Serialisasi ke 30 Bita
```swift
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        let origBytes = InitialsCodec.encode(originatorInitials) ?? [0, 0]
        data.append(contentsOf: origBytes)
        
        let targetBytes = InitialsCodec.encode(targetInitials) ?? [0, 0]
        data.append(contentsOf: targetBytes)
        
        var nonce = discoveryNonce.bigEndian
        data.append(Data(bytes: &nonce, count: 4))
        data.append(routeCost)
        
        // 21 bytes reserved (30 - 9 = 21)
        data.append(Data(repeating: 0, count: 21))
        return data
    }
```
- **Baris 28–43:** Mencerminkan `RouteReqPayload.serialize()` secara identik:
  - Bita 0..1: `originatorInitials` (2 bita Base-27)
  - Bita 2..3: `targetInitials` (2 bita Base-27)
  - Bita 4..7: `discoveryNonce` (4 bita UInt32 big-endian)
  - Bita 8: `routeCost` (1 bita UInt8)
  - Bita 9..29: 21 bita nol cadangan bantalan.

#### Baris 45–58: Deserialisasi
```swift
    public static func deserialize(from data: Data) throws -> RouteRespPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let origBytes = [data[0], data[1]]
        let orig = InitialsCodec.decode(origBytes) ?? "UNK"
        
        let targetBytes = [data[2], data[3]]
        let target = InitialsCodec.decode(targetBytes) ?? "UNK"
        
        let nonce = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let cost = data[8]
        return RouteRespPayload(originatorInitials: orig, targetInitials: target, discoveryNonce: nonce, routeCost: cost)
    }
}
```
- **Baris 46–48:** Pemeriksaan buffer underflow yang membutuhkan minimal 30 bita.
- **Baris 49–57:** Mengekstrak inisial, memuat nonce big-endian unaligned 32-bit, dan mengekstrak biaya hop, membangun `RouteRespPayload`.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Jejak Kawat Simetris:** Dengan berbagi tata letak biner yang identik dengan `RouteReqPayload`, logika kodek menjadi sangat dapat diprediksi. Opcode protokol dalam amplop teks-terbuka (`PacketType.routeResp` vs `PacketType.routeReq`) memberi tahu router apakah memperlakukan paket sebagai lalu lintas banjir siaran atau penerusan unicast jalur balik.
- **Persyaratan Nonce yang Cocok:** Jika inisiator menerima RREP yang `discoveryNonce`-nya tidak cocok dengan tabel pencarian aktifnya, paket dibuang sebagai respons basi atau palsu.

---

## 16. Teekum/Teekum/Core/Packets/Payloads/SOSPayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SOSPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSPayload.swift) |
| **Jumlah Baris (`wc -l`)** | 103 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct SOSPayload: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita yang menyiarkan peringatan darurat bahaya dengan koordinat GPS, akurasi horizontal, dan inisial pengirim. |

### Apa yang Dilakukan Berkas Ini
`SOSPayload.swift` mengimplementasikan muatan siaran darurat prioritas tinggi (`PacketType.sos`, opcode `0x03`). Ketika seorang pengguna memicu peringatan darurat, muatan ini mengemas koordinat GPS terkuantisasi, stempel waktu, akurasi horizontal, ID peristiwa SOS yang unik, inisial pengirim, jenis kategorisasi darurat (`SOSType`), persentase baterai, dan kode warna profil UI ke dalam slot muatan tersegel 30-bita. Muatan ini melewati antrean kemacetan mesh biasa, mengaktifkan audio sirene, peringatan haptik, dan hamparan UI darurat di semua perangkat kelompok.

### Analogi Bahasa Awam (ELI5)
Bayangkan menarik tuas alarm kebakaran merah menyala di stadion yang penuh sesak. Seketika, suar darurat ditembakkan ke langit dengan suar tahan air terpasang. Tertulis pada suar tersebut: koordinat GPS Anda, waktu krisis, label triase medis Anda ("Bantuan Medis"), sisa baterai radio Anda (84%), dan ID suar yang berkedip sehingga semua orang tahu ini adalah keadaan darurat keselamatan jiwa yang aktif.

### Istilah Teknis yang Didefinisikan
- **ID Peristiwa SOS (*SOS Event ID*):** Pengenal unik 32-bit yang dihasilkan pada saat keadaan darurat dimulai. Semua pembaruan lokasi darurat berikutnya yang disiarkan selama insiden yang sama menggunakan kembali ID ini hingga diselesaikan secara eksplisit.
- **Bita Penanda Status Tetap (*Fixed Status Marker Byte*):** Bita 13 dalam muatan SOS, dikodekan secara kaku ke `0x01` untuk menunjukkan status SOS yang mendesak dan aktif.
- **Kategorisasi Darurat (`SOSType`):** Pengklasifikasi triase 1-bita yang mengidentifikasi sifat bahaya (`.general`, `.medical`, `.separated`, `.security`, atau `.inactivity`).
- **Penjepitan Baterai (*Battery Clamping*):** Menegakkan `min(batteryLevel, 100)` untuk memastikan pembacaan sensor yang rusak atau salah tidak dapat melebihi rentang persentase yang valid.

### Penelusuran Blok Kode dan Baris demi Baris

#### Baris 1–39: Deklarasi Tipe dan Penginisialisasi
```swift
//
//  SOSPayload.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CoreLocation

public struct SOSPayload: Equatable, Sendable {
    public var coordinate: CLLocationCoordinate2D
    public var timestamp: Date
    public var accuracy: UInt8
    public var sosEventId: UInt32
    public var senderInitials: String // 3 uppercase characters
    public var emergencyType: SOSType
    public var batteryLevel: UInt8
    public var colorCode: UInt8       // MemberColor code
    
    public init(
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        accuracy: UInt8,
        sosEventId: UInt32 = UInt32.random(in: 1...UInt32.max),
        senderInitials: String,
        emergencyType: SOSType = .general,
        batteryLevel: UInt8,
        colorCode: UInt8 = 0
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.accuracy = accuracy
        self.sosEventId = sosEventId
        self.senderInitials = InitialsCodec.sanitize(senderInitials)
        self.emergencyType = emergencyType
        self.batteryLevel = min(batteryLevel, 100)
        self.colorCode = colorCode
    }
```
- **Baris 11–20:** Mendefinisikan struktur yang mematuhi `Equatable` dan `Sendable`. Menyimpan koordinat GPS, stempel waktu, akurasi, `sosEventId` 32-bit, inisial pengirim, `emergencyType` (`SOSType`), level baterai, dan `colorCode`.
- **Baris 21–39:** Penginisialisasi kustom membersihkan inisial, menjepit baterai ke $\le 100$, dan menghasilkan `sosEventId` bukan nol secara acak jika belum ditentukan.

#### Baris 41–66: Serialisasi ke dalam 30 Bita
```swift
    public func serialize() -> Data {
        var data = Data(capacity: PacketConstants.encryptedPayloadSize)
        let latRaw = coordinate.rawLatitude.bigEndian
        let lonRaw = coordinate.rawLongitude.bigEndian
        let tsRaw = UInt32(timestamp.timeIntervalSince1970).bigEndian
        
        var lat = latRaw; data.append(Data(bytes: &lat, count: 4))
        var lon = lonRaw; data.append(Data(bytes: &lon, count: 4))
        var ts = tsRaw; data.append(Data(bytes: &ts, count: 4))
        data.append(accuracy)
        data.append(0x01) // Fixed urgent SOS status marker byte
        
        var eventId = sosEventId.bigEndian
        data.append(Data(bytes: &eventId, count: 4))
        
        let initialBytes = InitialsCodec.encode(senderInitials) ?? [0, 0]
        data.append(contentsOf: initialBytes)
        
        data.append(emergencyType.rawValue)
        data.append(min(batteryLevel, 100))
        data.append(colorCode)
        
        // 7 bytes reserved padding (30 - 23 = 7)
        data.append(Data(repeating: 0, count: 7))
        return data
    }
```
- **Baris 43–49:** Menguantisasi koordinat ke titik-tetap `Int32` dan stempel waktu ke detik Unix `UInt32` big-endian:
  - Bita 0..3: `rawLatitude` (4 bita `Int32` bertanda)
  - Bita 4..7: `rawLongitude` (4 bita `Int32` bertanda)
  - Bita 8..11: `timestamp` (4 bita `UInt32` tanpa tanda)
- **Baris 50:** Menambahkan `accuracy` di Bita 12 (1 bita UInt8).
- **Baris 51:** Menambahkan `0x01` di Bita 13 (bita penanda status darurat mendesak).
- **Baris 53–54:** Menambahkan `sosEventId` dalam big-endian di Bita 14..17 (4 bita).
- **Baris 56–57:** Menambahkan `senderInitials` tersandi sebagai 2 bita Base-27 di Bita 18..19.
- **Baris 59:** Menambahkan `emergencyType.rawValue` di Bita 20 (1 bita).
- **Baris 60:** Menambahkan `batteryLevel` terjepit di Bita 21 (1 bita).
- **Baris 61:** Menambahkan `colorCode` di Bita 22 (1 bita).
- **Baris 63–65:** Menambahkan 7 bita bantalan nol di Bita 23..29 ($4 + 4 + 4 + 1 + 1 + 4 + 2 + 1 + 1 + 1 + 7 = 30$ bita). Mengembalikan buffer data 30-bita.

#### Baris 68–102: Deserialisasi dan Verifikasi
```swift
    public static func deserialize(from data: Data) throws -> SOSPayload {
        guard data.count >= PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.bufferUnderflow
        }
        let latRaw = data.subdata(in: 0..<4).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let lonRaw = data.subdata(in: 4..<8).withUnsafeBytes { $0.loadUnaligned(as: Int32.self).bigEndian }
        let tsRaw = data.subdata(in: 8..<12).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let accuracy = data[12]
        let eventId = data.subdata(in: 14..<18).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        
        let initialBytes = [data[18], data[19]]
        let initials = InitialsCodec.decode(initialBytes) ?? "UNK"
        
        let emergencyByte = data[20]
        let battery = data[21]
        let colorCode = data.count > 22 ? data[22] : 0
        
        let coord = CLLocationCoordinate2D.dequantize(latitudeRaw: latRaw, longitudeRaw: lonRaw)
        guard coord.latitude >= -90.0 && coord.latitude <= 90.0 && coord.longitude >= -180.0 && coord.longitude <= 180.0 else {
            throw PacketCodecError.invalidCoordinateRange(latitude: coord.latitude, longitude: coord.longitude)
        }
        let date = Date(timeIntervalSince1970: TimeInterval(tsRaw))
        let emergency = SOSType(rawValue: emergencyByte) ?? .general
        
        return SOSPayload(
            coordinate: coord,
            timestamp: date,
            accuracy: accuracy,
            sosEventId: eventId,
            senderInitials: initials,
            emergencyType: emergency,
            batteryLevel: min(battery, 100),
            colorCode: colorCode
        )
    }
}
```
- **Baris 69–71:** Menjaga dari underflow ($< 30$ bita).
- **Baris 72–76:** Membongkar koordinat, stempel waktu, akurasi, dan ID peristiwa menggunakan pemuatan bita big-endian. Bita 13 diverifikasi secara implisit sebagai bagian dari struktur aliran.
- **Baris 78–83:** Mendekode inisial dari Bita 18..19, membaca `emergencyByte` dari Bita 20, baterai dari Bita 21, dan mengakses `colorCode` dengan aman dari Bita 22.
- **Baris 85–88:** Mendekuantisasi koordinat menjadi IEEE 754 `CLLocationCoordinate2D` dan secara tegas menegaskan batas planet yang valid: $-90 \le \text{lat} \le 90$ dan $-180 \le \text{lon} \le 180$, melempar `PacketCodecError.invalidCoordinateRange` jika dilanggar.
- **Baris 89–101:** Membangun dan mengembalikan `SOSPayload`.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Membawa Kode Warna di SOS:** Dalam situasi darurat yang padat, petugas pertolongan pertama dan rekan harus segera mengidentifikasi pin korban di peta. Mengemas `colorCode` di Bita 22 memastikan UI peta menampilkan warna avatar neon AMOLED yang dipersonalisasi milik korban bahkan sebelum metadata daftar lengkap disinkronkan.
- **Pemeriksaan Batas Koordinat Aman:** Satu bit yang rusak dalam decoding koordinat titik-tetap dapat menghasilkan lokasi yang tidak valid (seperti garis lintang 140°). Deserializer secara eksplisit memeriksa hal ini sebelum meneruskan koordinat ke CoreLocation.

---

## 17. Teekum/Teekum/Core/Packets/Payloads/SOSResolvedPayload.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SOSResolvedPayload.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSResolvedPayload.swift) |
| **Jumlah Baris (`wc -l`)** | 41 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe nilai (`public struct SOSResolvedPayload: Hashable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Muatan biner 30-bita yang menyiarkan pembatalan dan resolusi dari keadaan darurat SOS yang aktif. |

### Apa yang Dilakukan Berkas Ini
`SOSResolvedPayload.swift` mengimplementasikan muatan untuk menyelesaikan dan menutup peringatan SOS aktif (`PacketType.sosResolved`, opcode `0x08`). Ketika kondisi darurat telah berakhir (misalnya ketika anggota yang hilang bersatu kembali dengan kelompoknya atau bantuan medis telah tiba), anggota pembuat menyiarkan muatan resolusi ini. Setelah diterima, semua perangkat penerima membungkam alarm sirene yang terdengar, menutup banner darurat layar penuh, dan memulihkan navigasi UI normal.

### Analogi Bahasa Awam (ELI5)
Setelah alarm kebakaran ditarik dan petugas pemadam kebakaran memastikan bahwa api telah padam, kepala pemadam kebakaran membuka kotak alarm dan memasukkan kode "Aman Terkendali" (*All Clear*) #91823. Seketika itu juga, sirene gedung yang memekakkan telinga berhenti, lampu strobo yang berkedip mati, dan orang-orang kembali ke tempat duduk mereka secara normal.

### Istilah Teknis yang Didefinisikan
- **Resolusi SOS (*SOS Resolution*):** Transisi status otoritatif dalam mesin status darurat dari siaran alarm aktif kembali ke operasi mesh normal.
- **Siaran Aman Terkendali (*All-Clear Broadcast*):** Pesan ke seluruh jaringan mesh yang dipancarkan dengan prioritas tinggi untuk membungkam efek suara sirene dan loop peringatan haptik di semua rekan yang terhubung.
- **Pengikatan ID Peristiwa (*Event ID Binding*):** Menegaskan bahwa paket resolusi mencantumkan `eventId` 32-bit yang tepat yang ingin ditutup sehingga pembatalan lama atau yang tidak cocok tidak secara sengaja membungkam krisis lain yang lebih baru.

### Penelusuran Blok Kode dan Baris demi Baris

#### Baris 1–17: Deklarasi Tipe dan Penginisialisasi
```swift
//
//  SOSResolvedPayload.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 13/11/26.
//

import Foundation

public struct SOSResolvedPayload: Hashable, Sendable {
    public let senderInitials: String
    public let eventId: UInt32

    public init(senderInitials: String, eventId: UInt32) {
        self.senderInitials = senderInitials
        self.eventId = eventId
    }
```
- **Baris 10:** Mematuhi `Hashable` dan `Sendable`. Memegang properti `let` yang tidak dapat diubah: `senderInitials` (siapa yang membatalkan) dan `eventId` (insiden darurat mana yang dibatalkan).
- **Baris 14–17:** Penginisialisasi standar.

#### Baris 19–28: Serialisasi ke dalam 30 Bita
```swift
    func serialize() throws -> Data {
        guard eventId != 0, let initials = InitialsCodec.encode(senderInitials) else {
            throw PacketCodecError.payloadSerializationFailed
        }
        var bigEndianId = eventId.bigEndian
        var data = Data(bytes: &bigEndianId, count: 4)
        data.append(contentsOf: initials)
        data.append(Data(repeating: 0, count: PacketConstants.encryptedPayloadSize - 6))
        return data
    }
```
- **Baris 20–22:** Memastikan bahwa `eventId != 0` (nol adalah nilai sentinal tidak valid) dan inisial berhasil disandikan ke dalam 2 bita Base-27. Melempar `PacketCodecError.payloadSerializationFailed` jika gagal.
- **Baris 23–24:** Mengemas `eventId` ke dalam Bita 0..3 dalam urutan big-endian.
- **Baris 25:** Menambahkan inisial Base-27 2-bita di Bita 4..5.
- **Baris 26:** Menambahkan 24 bita nol cadangan (`30 - 6 = 24`) di Bita 6..29. Mengembalikan data 30-bita.

#### Baris 30–40: Deserialisasi
```swift
    static func deserialize(from data: Data) throws -> Self {
        guard data.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        let eventId = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let initials = Array(data.dropFirst(4).prefix(2))
        guard eventId != 0, let sender = InitialsCodec.decode(initials) else {
            throw PacketCodecError.payloadDeserializationFailed
        }
        return Self(senderInitials: sender, eventId: eventId)
    }
}
```
- **Baris 31–33:** Secara ketat mengharuskan `data.count == PacketConstants.encryptedPayloadSize` (tepat 30 bita), melempar `PacketCodecError.payloadDeserializationFailed` jika panjang bita tidak cocok.
- **Baris 34:** Membongkar `UInt32` big-endian dari Bita 0..<4.
- **Baris 35:** Mengambil Bita 4..<6 untuk 2 bita inisial.
- **Baris 36–38:** Memastikan `eventId != 0` dan decoding Base-27 berhasil.
- **Baris 39:** Mengembalikan `SOSResolvedPayload` yang tervalidasi.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Pemeriksaan Kesetaraan Buffer yang Ketat:** Tidak seperti beberapa muatan yang menggunakan `>= 30`, `SOSResolvedPayload` menegakkan kesetaraan yang ketat (`data.count == 30`), memastikan kesesuaian format kawat mutlak sebelum mematikan alarm keselamatan.
- **Pemeriksaan ID Peristiwa Bukan Nol:** Menegakkan `eventId != 0` baik di serializer maupun deserializer, mencegah buffer memori yang ter-nol-kan disalahartikan sebagai perintah resolusi yang sah.

---

## 18. Teekum/Teekum/Core/Packets/Payloads/SOSType.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SOSType.swift](../../Teekum/Teekum/Core/Packets/Payloads/SOSType.swift) |
| **Jumlah Baris (`wc -l`)** | 27 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Enum nilai (`public enum SOSType: UInt8, CaseIterable, Codable, Sendable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`. |
| **Peran Arsitektural** | Enumerasi klasifikasi peringatan darurat yang membedakan usapan SOS manual dari pemicu ketidakaktifan otomatis. |

### Apa yang Dilakukan Berkas Ini
`SOSType.swift` mendefinisikan kategori taksonomi darurat yang dibawa di dalam `SOSPayload` (Bita 20). Berkas ini memetakan situasi darurat ke dalam representasi mentah 1-bita yang ringkas untuk transmisi radio, menyediakan string deskriptif yang ramah pengguna untuk banner darurat, pengumuman aksesibilitas, dan log pengiriman darurat.

### Analogi Bahasa Awam (ELI5)
Saat menanggapi insiden korban massal atau terjebak di bawah reruntuhan struktural, klasifikasi triase yang cepat menyelamatkan nyawa. `SOSType` adalah label darurat 1-bita yang dipilih oleh petugas penyelamat atau korban untuk menyiarkan status bahaya mereka melintasi mesh: `medical` (cedera tertimpa reruntuhan, pendarahan parah, gagal napas), `separated` (penyelamat terputus dari regu akibat naiknya air banjir atau runtuhnya struktur), `security` (zona bahaya, kebakaran listrik aktif, ketidakstabilan struktural), atau `inactivity` (deteksi korban tak bergerak yang dipicu oleh sensor akselerometer yang menandakan ketidaksadaran).

### Istilah Teknis yang Didefinisikan
- **RawRepresentable:** Protokol Swift yang memungkinkan enum dikonversi ke dan dari tipe primitif dasar (`UInt8` pada transmisi kawat).
- **CaseIterable:** Protokol Swift yang menyediakan koleksi `allCases` yang berisi semua kasus enum yang dideklarasikan, memungkinkan pembuatan UI pemilih dinamis.
- **Penjaga Ketidakaktifan ("Man Down" / *Inactivity Guard*):** Mekanisme deteksi darurat otomatis yang memantau sensor gerak perangkat dan menandai keadaan darurat jika pengguna tetap diam untuk waktu yang lama setelah dicurigai terjatuh.

### Penelusuran Blok Kode dan Baris demi Baris

#### Baris 1–27: Deklarasi Enum Lengkap
```swift
//
//  SOSType.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free emergency category codes carried in SOS alerts.
public enum SOSType: UInt8, CaseIterable, Codable, Sendable {
    case general   = 0x00
    case medical   = 0x01
    case separated = 0x02
    case security  = 0x03
    case inactivity = 0x04

    public var title: String {
        switch self {
        case .general:   return "General Emergency"
        case .medical:   return "Medical Assistance"
        case .separated: return "Lost / Separated"
        case .security:  return "Security Concern"
        case .inactivity: return "Inactivity / Man Down"
        }
    }
}
```
- **Baris 11:** Mendeklarasikan `SOSType` yang didukung oleh `UInt8`, mematuhi `CaseIterable`, `Codable`, dan `Sendable`.
- **Baris 12–16:** Mendefinisikan 5 kategori darurat:
  - `0x00`: `.general` (krisis umum atau faktor ganda yang tidak ditentukan)
  - `0x01`: `.medical` (cedera, dehidrasi parah, asma, serangan medis)
  - `0x02`: `.separated` (disorientasi atau terpisah secara fisik di zona bencana)
  - `0x03`: `.security` (ancaman keamanan fisik, ancaman bahaya aktif)
  - `0x04`: `.inactivity` (dipicu oleh detektor ketidakaktifan akselerometer/CoreMotion otomatis)
- **Baris 18–26:** Properti terhitung `title` yang mengembalikan judul tampilan untuk hamparan peringatan.

### Dasar Pemikiran Rekayasa dan Kasus Batas (*Edge Cases*)
- **Jejak Satu Bita Tunggal:** Menggunakan `UInt8` memuat seluruh taksonomi darurat ke dalam satu bita tunggal pada transmisi kawat, menghemat ruang berharga dalam slot muatan 30-bita yang tersegel.
- **Penanganan Nilai RawValue Cadangan:** Jika klien yang lebih lama menemui opcode masa depan (seperti `0x05`), `SOSPayload.deserialize` menanganinya dengan aman menggunakan nilai mundur via `SOSType(rawValue: emergencyByte) ?? .general`.

---
## 19. Teekum/Teekum/Core/Session/GroupSession.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [GroupSession.swift](../../Teekum/Teekum/Core/Session/GroupSession.swift) |
| **Jumlah Baris (`wc -l`)** | 185 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Nilai (`public struct GroupSession: Identifiable, Equatable, Sendable, Codable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Model domain inti yang merepresentasikan grup *mesh* zona bencana aktif dengan ID sesi 24-bit, kunci simetris, dan profil anggota lokal. |

### Apa yang Dilakukan Berkas Ini
`GroupSession.swift` mendefinisikan model domain yang merepresentasikan sesi grup *mesh* efemeral yang aktif. Berkas ini merangkum pengidentifikasi sesi 24-bit (`sessionId`), nama sesi yang mudah dibaca manusia, kunci enkripsi simetris 256-bit ChaCha20-Poly1305 (`symmetricKeyData`), inisial pengguna lokal, kode warna profil preferensi, dan stempel waktu pembuatan sesi. Selain pemodelan *state*, berkas ini menyediakan pembuatan tautan undangan tanpa server (*serverless invite link*) (`meepo://join#...`) dan penguraian ekspresi reguler (regex) URL untuk memungkinkan bergabung ke grup tanpa memerlukan server autentikasi terpusat apa pun.

### Analogi Sederhana (ELI5)
Bayangkan `GroupSession` sebagai manifes misi taktis terenkripsi dan kredensial regu. Ini mendefinisikan identitas regu penyelamat, inisial tanda panggil taktis (*tactical callsign*, misal "SAR"), warna tim yang ditetapkan, dan kunci enkripsi simetris 256-bit berentropi tinggi (`groupKey`). Saat dua unit penyelamat berpasangan di area persiapan (*staging area*), mereka saling bertukar profil penugasan ini melalui pemindaian QR di luar jaringan (*out-of-band*) atau URL luring (*offline*) yang kunci kriptografisnya diisolasi secara aman di dalam `#fragment` URL. Tidak ada pihak luar—bahkan musuh, menara seluler yang disusupi, atau pemantau radio ilegal—yang dapat mendekripsi telemetri atau status triase regu.

### Definisi Istilah Teknis
- **Pengidentifikasi Sesi 24-bit (`sessionId`):** Bilangan bulat 3-bita ringkas yang mengidentifikasi sesi *mesh* pada kabel jaringan (`0x000001` hingga `0xFFFFFF`), mencocokkan bidang SID pada amplop *cleartext*.
- **Data Kunci Simetris (*Symmetric Key Data*):** Urutan bita pseudorandom kuat secara kriptografis sepanjang 32-bita (256-bit) yang digunakan sebagai kunci akar untuk penyegelan dan verifikasi *payload* ChaCha20-Poly1305 AEAD.
- **Benih Rahasia AutoMesh (*AutoMesh Secret Seed*):** Frasa sandi prabagi deterministik (`"TeeKum-disaster zone-AutoMesh-v2-SecretSeed"`) yang di-hash melalui SHA-256 untuk memungkinkan jaringan *mesh* ad-hoc nir-konfigurasi (*zero-configuration*) antar perangkat yang belum dikonfigurasi.
- **Tautan Undangan Tanpa Server (*Serverless Invite Link*):** Skema URL (`meepo://join#...`) yang membawa kredensial sesi sepenuhnya di sisi klien.
- **Fragmen URL (`#`):** Bagian dari URL setelah simbol `#`. RFC 3986 menetapkan bahwa fragmen diproses secara eksklusif pada klien lokal dan tidak pernah dikirim ke server web HTTP jarak jauh selama penjelajahan web, menjamin privasi kunci kriptografis.
- **Sidik Jari Kunci (*Key Fingerprint*):** Prefiks intisari heksadesimal 4-bita pendek yang diturunkan dari SHA-256 kunci simetris, ditampilkan di UI untuk verifikasi visual antar rekan (*peer*) di luar jaringan (*out-of-band*).

### Pembahasan Kode Baris demi Baris
#### Baris 1–47: Deklarasi Tipe dan Properti
```swift
//
//  GroupSession.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CryptoKit

/// Active ephemeral group session model representing local participation.
/// Auto-mesh enabled: connects to nearby peers on a shared disaster zone key.
public struct GroupSession: Identifiable, Equatable, Sendable, Codable {
    public var id: UInt32 { sessionId }
    
    /// 24-bit session hash identifying the active disaster zone network.
    public let sessionId: UInt32
    
    /// Human-friendly name for the session (e.g., "disaster zone Mesh").
    public let sessionName: String
    
    /// 256-bit symmetric key bytes used for authenticated payload encryption.
    public let symmetricKeyData: Data
    
    /// Local user's 3-letter initials (e.g. "DNA").
    public var localInitials: String
    
    /// Local user's preferred 1-byte color code (MemberColor).
    public var localColorCode: UInt8
    
    /// Backward-compatibility alias for display name.
    public var localMemberName: String { localInitials }

    public var localMemberId: MemberID { .fromInitials(localInitials) }
    
    /// True if the user initiated the session (or host role).
    public let isHost: Bool
    
    /// Backward-compatibility slot calculation.
    public var memberSlot: UInt8 {
        let bytes = InitialsCodec.encode(localInitials) ?? [0, 0]
        return bytes[0] ^ bytes[1]
    }
    
    /// Timestamp when session was established.
    public let createdAt: Date
```
- **Baris 13–15:** Mendeklarasikan `GroupSession` yang mematuhi `Identifiable`, `Equatable`, `Sendable`, dan `Codable`. Kepatuhan terhadap `Identifiable` menggunakan `sessionId` sebagai ID unik.
- **Baris 17–23:** Kredensial inti yang tidak dapat diubah (*immutable*): `sessionId` (bilangan bulat 24-bit), `sessionName` (String), dan `symmetricKeyData` (kunci biner mentah 256-bit).
- **Baris 25–29:** Properti identitas lokal: `localInitials` (inisial 3 karakter yang telah disanitasi) dan `localColorCode` (nilai mentah 1-bita `MemberColor`).
- **Baris 31–37:** Pengakses kenyamanan (*convenience accessors*): `localMemberName`, `localMemberId`, dan `isHost`.
- **Baris 40–43:** `memberSlot` dihitung dengan melakukan operasi XOR terhadap 2 bita hasil pengkodean Base-27 dari `localInitials`, menghasilkan derivasi *slot* yang deterministik.
- **Baris 45–46:** `createdAt` mencatat waktu pembentukan sesi.

#### Baris 48–74: Konstanta Default dan Inisialisator
```swift
    /// Default shared disaster zone key for auto-mesh.
    public static let defaultSymmetricKeyData: Data = {
        let seed = "TeeKum-disaster zone-AutoMesh-v2-SecretSeed"
        return Data(SHA256.hash(data: Data(seed.utf8)))
    }()
    
    /// Default 24-bit session identifier for the public disaster zone Mesh; matches the three-byte wire SID field.
    public static let defaultSessionId: UInt32 = 0x7E3AF5
    
    public init(
        sessionId: UInt32 = GroupSession.defaultSessionId,
        sessionName: String = "disaster zone Mesh",
        symmetricKeyData: Data = GroupSession.defaultSymmetricKeyData,
        localInitials: String,
        localColorCode: UInt8 = 0x00,
        memberSlot: UInt8? = nil,
        isHost: Bool = true,
        createdAt: Date = Date()
    ) {
        self.sessionId = sessionId & PacketConstants.sessionIdMask
        self.sessionName = sessionName
        self.symmetricKeyData = symmetricKeyData
        self.localInitials = InitialsCodec.sanitize(localInitials)
        self.localColorCode = localColorCode
        self.isHost = isHost
        self.createdAt = createdAt
    }
```
- **Baris 49–55:** Mendefinisikan kredensial statis default untuk auto-mesh nir-sentuh (*zero-touch*): `defaultSymmetricKeyData` diturunkan melalui SHA-256 terhadap `"TeeKum-disaster zone-AutoMesh-v2-SecretSeed"`, dan `defaultSessionId = 0x7E3AF5`.
- **Baris 57–74:** Inisialisator berbasis anggota (*memberwise initializer*). Melakukan operasi *masking* pada `sessionId` dengan `PacketConstants.sessionIdMask` (`0x00FFFFFF`) untuk secara ketat membatasinya pada 24 bit, serta menyanitasi inisial.

#### Baris 76–103: Pembuatan URL Undangan Tanpa Server
```swift
    // MARK: - Serverless Share Link & QR Encoding

    /// Short display fingerprint derived from the key's digest.
    var keyFingerprint: String {
        let prefix = SHA256.hash(data: symmetricKeyData).prefix(4)
        return "0x" + prefix.map { String(format: "%02X", $0) }.joined()
    }
    
    /// Generates a serverless invite URL where the 256-bit key is packed into the URL fragment (#).
    /// Using the URL fragment guarantees that if tapped on the web, the key is never transmitted
    /// to any remote HTTP web server.
    public func inviteURL() -> URL {
        var components = URLComponents()
        components.scheme = "meepo"
        components.host = "join"
        
        var payload = URLComponents()
        payload.queryItems = [
            URLQueryItem(name: "key", value: symmetricKeyData.base64EncodedString()),
            URLQueryItem(name: "sid", value: PacketConstants.formatSessionId(sessionId)),
            URLQueryItem(name: "name", value: sessionName)
        ]
        components.percentEncodedFragment = payload.percentEncodedQuery
        guard let url = components.url else {
            preconditionFailure("Unable to encode a Meepo invite URL.")
        }
        return url
    }
```
- **Baris 79–82:** Menghasilkan sidik jari heksadesimal 8-karakter (`"0x..."`) dari 4 bita pertama *hash* SHA-256 kunci.
- **Baris 87–103:** Membangun URL `meepo://join` di mana `key` (kunci 32-bita terenkode base64), `sid` (string heksadesimal terformat), dan `name` dikemas secara ketat ke dalam `percentEncodedFragment` (`#`). Hal ini mencegah kebocoran kredensial melalui proksi HTTP.

#### Baris 105–185: Ekstraksi Tautan Regex dan Penguraian URL
```swift
    public static func extractInviteURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Direct URL parse if the string itself is a clean teekum URL
        if let directURL = URL(string: trimmed),
           let scheme = directURL.scheme?.lowercased(),
           scheme == "meepo" {
            return directURL
        }
        
        // Regex extraction to find meepo:// URL inside any arbitrary text
        let pattern = #"(?i)meepo://join[^\s<>"'\(\)\[\]\{\}]+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        
        var rawMatched = String(text[range])
        
        // Trim trailing sentence punctuation if accidentally attached
        let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?")
        while let last = rawMatched.unicodeScalars.last, trailingPunctuation.contains(last) {
            rawMatched.removeLast()
        }
        
        return URL(string: rawMatched)
    }
    
    public static func parseInvite(from text: String) -> GroupSessionInvite? {
        guard let url = extractInviteURL(from: text) else { return nil }
        return parseInvite(from: url)
    }
    
    public static func parseInvite(from url: URL) -> GroupSessionInvite? {
        guard let scheme = url.scheme?.lowercased(), scheme == "meepo" else { return nil }
        let host = (url.host ?? "").lowercased()
        guard host == "join" || url.path.lowercased().contains("join") else { return nil }
        
        let rawPayload = (url.fragment?.isEmpty == false ? url.fragment : url.query) ?? ""
        guard !rawPayload.isEmpty else { return nil }
        
        var keyData: Data?
        var sessionId: UInt32?
        var sessionName: String?
        
        let pairs = rawPayload.split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0])
            let value = String(parts[1])
            
            switch key {
            case "key":
                let clean = value.removingPercentEncoding ?? value
                keyData = Data(base64Encoded: clean) ?? Data(base64Encoded: clean.replacingOccurrences(of: " ", with: "+"))
            case "sid":
                let clean = value.removingPercentEncoding ?? value
                sessionId = UInt32(clean, radix: 16) ?? UInt32(clean)
            case "name":
                sessionName = value.removingPercentEncoding ?? value
            default:
                break
            }
        }
        
        guard let validKey = keyData, validKey.count == 32,
              let validSid = sessionId, PacketConstants.isValidSessionId(validSid),
              let validName = sessionName else {
            return nil
        }
        
        return GroupSessionInvite(sessionId: validSid, sessionName: validName, keyData: validKey)
    }
```
- **Baris 108–135:** `extractInviteURL(from:)` menangani string hasil tempelan yang mengandung teks *boilerplate* (misalnya `"Deploy SAR Squad Alpha: meepo://join#..."`). Menggunakan regex yang tidak peka huruf besar-kecil `(?i)meepo://join[^\s<>"'\(\)\[\]\{\}]+` dan memangkas tanda baca kalimat di akhir (`.,;:!?`).
- **Baris 138–141:** Jembatan kenyamanan yang mengurai dari string teks sembarang.
- **Baris 144–184:** `parseInvite(from:)` memverifikasi skema `meepo` dan *host* `join`. Mengekstrak string *query* atau fragmen, mengiterasi pasangan kunci-nilai (`key`, `sid`, `name`), mendekode kunci base64, mengurai ID sesi sebagai heksadesimal atau bilangan bulat, dan memvalidasi:
  - `validKey.count == 32` (kebutuhan 256-bit)
  - `PacketConstants.isValidSessionId(validSid)` ($1 \le \text{sid} \le 0xFFFFFF$)
  - Nama sesi tidak bernilai nil. Mengembalikan struktur `GroupSessionInvite`.

### Rasional Rekayasa dan Kasus Batas
- **Arsitektur Privasi Fragmen (*Fragment Privacy Architecture*):** Menempatkan kredensial di fragmen URL (`#key=...`) dan bukan parameter *query* (`?key=...`) merupakan pola keamanan *zero-trust* yang esensial. Jika pengguna menempelkan tautan undangan ke dalam peramban web, server web hanya menerima jalur dasar (`/join`), tidak pernah menerima fragmen, mencegah pemanenan kunci oleh pihak ketiga.
- **Sanitasi Space-Plus Base64:** Saat string URL disalin lintas aplikasi perpesanan (WhatsApp, iMessage, Slack), karakter `+` dalam string base64 sering kali diubah menjadi spasi secara tidak sengaja. Baris 166 secara defensif menangani hal ini melalui `.replacingOccurrences(of: " ", with: "+")`.

---

---

## 20. Teekum/Teekum/Core/Session/GroupSessionInvite.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [GroupSessionInvite.swift](../../Teekum/Teekum/Core/Session/GroupSessionInvite.swift) |
| **Jumlah Baris (`wc -l`)** | 22 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Nilai (`public struct GroupSessionInvite: Equatable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Tipe nilai yang merepresentasikan kredensial undangan dan *payload* kode QR yang berisi ID sesi, sidik jari kunci, dan nama grup. |

### Apa yang Dilakukan Berkas Ini
`GroupSessionInvite.swift` mendefinisikan representasi terurai dari undangan sesi grup masuk yang diterima melalui *deep link* URL, pemindaian kode batang QR, atau tempelan papan klip (*clipboard*). Berkas ini menyimpan pengidentifikasi 24-bit sesi target (`sessionId`), nama yang ramah pengguna (`sessionName`), dan data kunci simetris 32-bita mentah (`keyData`) yang siap diterima oleh pengguna.

### Analogi Sederhana (ELI5)
Bayangkan `GroupSessionInvite` sebagai paket taklimat misi taktis bersegel yang diserahkan kepada relawan penyelamat sebelum mereka secara resmi diterjunkan ke sektor operasional. Paket tersebut merinci zona insiden operasional (ID sesi), nama penugasan regu (misal, "Tim Pencari Sektor 4"), dan kunci misi ChaCha20-Poly1305. Setelah relawan mengonfirmasi penugasan dengan mengetuk "Gabung Misi", `SessionStore` mengonversi undangan tersebut menjadi `GroupSession` aktif dan menyimpan kunci rahasia tersebut dengan aman di dalam iOS Keychain.

### Definisi Istilah Teknis
- **Undangan Sesi Efemeral (*Ephemeral Session Invite*):** Kontainer data sementara yang menyimpan kredensial yang diekstraksi dari saluran di luar jaringan (kode QR, AirDrop, NFC, tautan universal) yang menunggu konfirmasi pengguna.
- **Penerimaan Deep Link (*Deep Link Ingestion*):** Proses penangkapan skema URI kustom (`meepo://`) dari aplikasi eksternal atau pemindai kode batang dan merutekannya ke dalam mesin status (*state machine*) internal aplikasi.

### Pembahasan Kode Baris demi Baris
#### Baris 1–22: Deklarasi Struct Lengkap
```swift
//
//  GroupSessionInvite.swift
//  Teekum
//
//  Created by Nicho on 07/11/26.
//

import Foundation

/// Decoded details from a serverless share link or QR barcode invite.
public struct GroupSessionInvite: Equatable, Sendable {
    /// 24-bit session identifier (`0x000001...0xFFFFFF`).
    public let sessionId: UInt32
    public let sessionName: String
    public let keyData: Data
    
    public init(sessionId: UInt32, sessionName: String, keyData: Data) {
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.keyData = keyData
    }
}
```
- **Baris 11:** Mendeklarasikan `GroupSessionInvite` yang mematuhi `Equatable` dan `Sendable`.
- **Baris 13–15:** Mendeklarasikan tiga properti *immutable*: `sessionId` (UInt32), `sessionName` (String), dan `keyData` (Data).
- **Baris 17–21:** Inisialisator publik standar berbasis anggota.

### Rasional Rekayasa dan Kasus Batas
- **Model Konfirmasi Terpisah (*Decoupled Confirmation Model*):** `GroupSessionInvite` sengaja dipisahkan dari `GroupSession`. Aplikasi menghindari langsung mengganti sesi aktif pengguna saat sebuah tautan diklik; alih-alih, ia mengisi `SessionStore.pendingInvite` sehingga UI dapat menampilkan konfirmasi eksplisit ("Apakah Anda ingin meninggalkan grup saat ini dan bergabung dengan 'Tim Pencari Sektor 4'?").

---

---

## 21. Teekum/Teekum/Core/Session/MeetingAttendance.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MeetingAttendance.swift](../../Teekum/Teekum/Core/Session/MeetingAttendance.swift) |
| **Jumlah Baris (`wc -l`)** | 34 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Nilai enum (`public enum MeetingAttendance: UInt8, CaseIterable, Codable, Sendable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`. |
| **Peran Arsitektural** | Model domain yang melacak konfirmasi kehadiran (RSVP) anggota dan status kedatangan untuk titik temu grup yang aktif. |

### Apa yang Dilakukan Berkas Ini
`MeetingAttendance.swift` mendefinisikan status kehadiran tingkat domain untuk titik temu grup aktif. Berkas ini menyediakan judul yang ramah dibaca manusia dan pengidentifikasi ikon SF Symbols untuk presentasi SwiftUI, dengan nilai mentah `UInt8` yang diselaraskan dengan kode protokol kabel biner `AttendanceStatus`.

### Analogi Sederhana (ELI5)
Ketika seseorang di grup zona bencana Anda mengusulkan untuk berkumpul di pos logistik pada pukul 19:00, enum ini mewakili opsi RSVP Anda di layar: ikon jam untuk "Menunggu", tanda centang hijau untuk "Saya akan hadir", tanda silang merah untuk "Tidak bisa hadir", dan pin penanda untuk "Tiba".

### Definisi Istilah Teknis
- **SF Symbols:** Pustaka ikon sistem yang disediakan oleh Apple yang terintegrasi langsung ke SwiftUI melalui `Image(systemName:)`.
- **Status Kehadiran Titik Temu (*Rendezvous Attendance State*):** Status lokal dan jarak jauh dari seorang rekan (*peer*) relatif terhadap proposal titik temu yang disepakati.

### Pembahasan Kode Baris demi Baris
#### Baris 1–34: Deklarasi Enum Lengkap
```swift
//
//  MeetingAttendance.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free attendance choices for the active group meeting point.
public enum MeetingAttendance: UInt8, CaseIterable, Codable, Sendable {
    case pending  = 0x00
    case accepted = 0x01
    case declined = 0x02
    case arrived  = 0x09

    public var title: String {
        switch self {
        case .pending:  return "Pending"
        case .accepted: return "I'll be there"
        case .declined: return "Can't make it"
        case .arrived:  return "Arrived"
        }
    }

    public var systemImage: String {
        switch self {
        case .pending:  return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .arrived:  return "mappin.and.ellipse"
        }
    }
}
```
- **Baris 11:** Didukung oleh `UInt8`, mematuhi `CaseIterable`, `Codable`, dan `Sendable`.
- **Baris 12–15:** Mendeklarasikan empat status:
  - `0x00`: `.pending`
  - `0x01`: `.accepted`
  - `0x02`: `.declined`
  - `0x09`: `.arrived`
- **Baris 17–24:** Properti terhitung `title` yang menyediakan string bersih yang ditampilkan kepada pengguna.
- **Baris 26–33:** Properti terhitung `systemImage` yang mengembalikan nama standar SF Symbols (`clock.fill`, `checkmark.circle.fill`, `xmark.circle.fill`, `mappin.and.ellipse`).

### Rasional Rekayasa dan Kasus Batas
- **Paritas Kode Jaringan Kabel (*Wire Code Parity*):** Nilai mentah (`0x00`, `0x01`, `0x02`, `0x09`) cocok bita-demi-bita dengan `AttendanceStatus.swift`, memungkinkan *typecasting* nir-translasi antara paket jaringan dan penyimpanan domain.

---

---

## 22. Teekum/Teekum/Core/Session/MeetingPoint.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MeetingPoint.swift](../../Teekum/Teekum/Core/Session/MeetingPoint.swift) |
| **Jumlah Baris (`wc -l`)** | 66 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Nilai (`public struct MeetingPoint: Identifiable, Equatable, Hashable, Codable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Model domain yang merepresentasikan titik temu grup dengan koordinat GPS, jadwal waktu pertemuan, dan kepemilikan kunci penetap (*setter lock ownership*). |

### Apa yang Dilakukan Berkas Ini
`MeetingPoint.swift` memodelkan satu-satunya proposal titik temu aktif dalam sesi grup Meepo. Berkas ini menyimpan koordinat geografis titik temu, waktu target pertemuan, inisial pengusul dan `MemberID`, asosiasi penanda (*landmark*), pemetaan kehadiran masing-masing anggota (`[MemberID: MeetingAttendance]`), ambang radius kedatangan, dan status kedaluwarsa.

### Analogi Sederhana (ELI5)
Bayangkan `MeetingPoint` sebagai bendera reli digital yang ditancapkan pada peta zona bencana grup Anda. Bendera tersebut memiliki label ("Posko Logistik"), waktu pertemuan yang dijadwalkan (20:30), daftar tamu yang menunjukkan siapa yang menerima atau menolak, dan lingkaran *geofence* tak terlihat selebar 25 meter di sekelilingnya. Saat Anda berjalan masuk ke dalam lingkaran itu, status Anda secara otomatis beralih menjadi "Tiba".

### Definisi Istilah Teknis
- **Aturan Titik Temu Aktif Tunggal (*Single Active Meeting Point Rule*):** Invarian produk inti di Meepo yang menyatakan bahwa hanya satu titik temu grup yang dapat aktif pada waktu tertentu, menghindari kebingungan koordinasi di lingkungan yang kacau.
- **Radius Kedatangan Geofence (*Geofence Arrival Radius*):** Batas jarak melingkar dalam meter (antara 5m dan 100m) di sekitar koordinat pertemuan. Saat CoreLocation melaporkan jarak yang lebih kecil dari ambang batas ini, status kedatangan akan terpicu.
- **Penambatan ke GPS Pengusul (*Anchor to Proposer GPS*):** Mode titik temu dinamis di mana titik pertemuan mengikuti lokasi bergerak pengguna pengusul secara *real-time*, bukan terpaku pada koordinat statis.
- **Jendela Kedaluwarsa (*Expiry Window*):** Masa tenggang 1 jam ($3.600$ detik) setelah waktu pertemuan yang dijadwalkan, setelah itu titik temu secara otomatis bertransisi menjadi kedaluwarsa.

### Pembahasan Kode Baris demi Baris
#### Baris 1–35: Deklarasi Tipe dan Properti Terhitung
```swift
//
//  MeetingPoint.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

// Active proposal identity, coordinate, author and attendance data.
// Enforces the single active meeting point rule per group session.
public struct MeetingPoint: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UInt32
    public var name: String
    public var latitude: CLLocationDegrees
    public var longitude: CLLocationDegrees
    public var targetTime: Date?
    public let proposerId: MemberID
    public let proposerInitials: String
    public var landmarkId: UInt32?
    public var attendance: [MemberID: MeetingAttendance]
    public let createdAt: Date
    public var isRightNow: Bool
    public var anchorToProposerGPS: Bool
    public var arrivalRadiusMeters: Double

    public var meetupTime: Date { targetTime ?? createdAt }
    public var isExpired: Bool { Date.now.timeIntervalSince(meetupTime) > 3600 }
    public var formattedTitle: String { "\(proposerInitials)'s Rendezvous" }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
```
- **Baris 13:** Mematuhi `Identifiable`, `Equatable`, `Hashable`, `Codable`, dan `Sendable`.
- **Baris 14–26:** Mendeklarasikan properti termasuk `id` (UInt32), `name` (String), `latitude`/`longitude`, `targetTime` opsional, `proposerId` (`MemberID`), `proposerInitials`, `landmarkId` opsional, kamus `attendance`, `createdAt`, bendera `isRightNow`, bendera `anchorToProposerGPS`, dan `arrivalRadiusMeters`.
- **Baris 28:** `meetupTime` mengevaluasi ke `targetTime` jika disetel, atau kembali ke waktu pembuatan untuk pertemuan mendesak ("saat ini juga").
- **Baris 29:** `isExpired` mengevaluasi apakah waktu saat ini telah melewati lebih dari 3.600 detik (1 jam) dari `meetupTime`.
- **Baris 30:** `formattedTitle` menghasilkan string judul seperti `"NIC's Rendezvous"`.
- **Baris 32–34:** `coordinate` menyusun struktur `CLLocationCoordinate2D` dari derajat garis lintang (*latitude*) dan garis bujur (*longitude*) yang tersimpan.

#### Baris 36–66: Inisialisator dengan Pembatasan Rentang (Clamping)
```swift
    public init(
        id: UInt32 = UInt32.random(in: 1...UInt32.max),
        name: String,
        coordinate: CLLocationCoordinate2D,
        targetTime: Date? = nil,
        proposerId: MemberID? = nil,
        proposerInitials: String,
        landmarkId: UInt32? = nil,
        attendance: [MemberID: MeetingAttendance] = [:],
        createdAt: Date = .now,
        isRightNow: Bool = false,
        anchorToProposerGPS: Bool = false,
        arrivalRadiusMeters: Double = 25
    ) {
        let cleanInitials = MemberID.sanitizeInitials(proposerInitials)
        let resolvedProposerId = proposerId ?? MemberID.fromInitials(cleanInitials)
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.targetTime = targetTime
        self.proposerId = resolvedProposerId
        self.proposerInitials = cleanInitials
        self.landmarkId = landmarkId
        self.attendance = attendance
        self.createdAt = createdAt
        self.isRightNow = isRightNow
        self.anchorToProposerGPS = anchorToProposerGPS
        self.arrivalRadiusMeters = min(100, max(5, arrivalRadiusMeters))
    }
}
```
- **Baris 36–49:** Daftar parameter dengan nilai default yang masuk akal: ID 32-bit acak, radius kedatangan default 25m, tabel kehadiran kosong.
- **Baris 50–51:** Menyanitasi `proposerInitials` dan menentukan `proposerId` melalui `MemberID.fromInitials`.
- **Baris 52–63:** Menetapkan properti.
- **Baris 64:** Membatasi `arrivalRadiusMeters` secara ketat antara 5 meter hingga 100 meter menggunakan `min(100, max(5, arrivalRadiusMeters))`.

### Rasional Rekayasa dan Kasus Batas
- **Pembatasan Rentang Radius Kedatangan (*Arrival Radius Clamping*):** Menetapkan radius kedatangan di bawah 5 meter akan menyebabkan *false negative* di lingkungan zona bencana di mana interferensi *multipath* GPS menciptakan ketidakpastian 5–10m. Sebaliknya, menyetelnya di atas 100 meter akan menandai pengguna sebagai "Tiba" padahal masih berada di seberang area evakuasi bencana.
- **Dukungan Perlindungan Setter Lock:** Dengan menyimpan `proposerInitials` secara langsung, komponen UI dan layanan dapat dengan mudah memverifikasi apakah pengguna lokal memiliki wewenang untuk mengedit atau membatalkan titik temu tersebut.

---

---

## 23. Teekum/Teekum/Core/Session/Member.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [Member.swift](../../Teekum/Teekum/Core/Session/Member.swift) |
| **Jumlah Baris (`wc -l`)** | 136 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Nilai (`public struct Member: Identifiable, Equatable, Hashable, Sendable`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Model domain yang merepresentasikan rekan dalam grup zona bencana, termasuk telemetri, pembacaan GPS terbaru, arah hadap (*heading*), dan status keterjangkauan tautan. |

### Apa yang Dilakukan Berkas Ini
`Member.swift` merepresentasikan anggota rekan (*peer*) yang berpartisipasi dalam sesi grup Meepo yang aktif. Berkas ini melacak inisial rekan yang telah disanitasi, nama tampilan, stempel waktu penerimaan paket terbaru (`lastSeen`), stempel waktu pengukuran GPS perangkat keras pengirim (`measurementTimestamp`), koordinat geografis, akurasi horizontal, status darurat marabahaya (*SOS*), persentase baterai, arah hadap kompas, status tautan 1-hop langsung (`isDirectPeer`), RSSI radio langsung, dan `MemberColor` yang dipersonalisasi. Berkas ini juga memuat logika deteksi data basi (*stale*) multi-tahap untuk memicu penemuan ulang rute AODV sesuai kebutuhan (*on-demand*).

### Analogi Sederhana (ELI5)
Bayangkan `Member` sebagai kartu roster regu taktis waktu nyata (*real-time*) untuk setiap penyelamat yang diterjunkan ke lapangan. Bagian depan kartu menampilkan inisial tanda panggil, warna lencana taktis, persentase baterai langsung (misalnya 84%), arah hadap kompas magnetik, dan jarak radial. Bagian belakang melacak kesehatan telemetri radio: apakah perangkat mereka terdengar melalui tautan langsung 1-hop (`isDirectPeer`) dengan RSSI yang kuat (-58 dBm) atau dirutekan melalui simpul relai multi-hop, bersama dengan usia pasti dari ping terakhir mereka. Jika kartu penyelamat menjadi gelap selama lebih dari 45 detik, sistem secara otomatis menandai mereka sebagai basi (*stale*) dan memulai permintaan pencarian rute AODV berdasarkan kebutuhan di seluruh jaringan *mesh*.

### Definisi Istilah Teknis
- **Stempel Waktu Pengukuran Perangkat Keras vs. Waktu Terakhir Terlihat (*Hardware Measurement Timestamp vs. Last Seen Time*):** `measurementTimestamp` adalah saat perangkat keras GPS rekan benar-benar memperoleh koordinat. `lastSeen` adalah saat perangkat lokal menerima paket melalui radio *mesh*. Memisahkan kedua hal ini mencegah paket usang yang tertunda di antrean menimpa pembacaan GPS yang masih baru.
- **Peer 1-Hop Langsung (*Direct 1-Hop Peer*):** Perangkat tetangga yang berada dalam jangkauan radio Bluetooth/Wi-Fi langsung (`envelope.hopCount == 0`).
- **RSSI (Received Signal Strength Indicator):** Daya sinyal radio yang diamati dalam dBm (biasanya $-30$ dBm jika sangat dekat dengan ponsel hingga $-90$ dBm pada batas jangkauan penerimaan).
- **Jendela Deteksi Basi Dua Tahap (*Two-Stage Stale Detection Window*):** Mesin status pemulihan cerdas:
  - *Tahap 1 (Peringatan Pasif):* $t > 30\text{ dtk}$ (`stalePeerThreshold`).
  - *Tahap 2 (Penemuan Rute AODV):* $45\text{ dtk} \le t \le 90\text{ dtk}$ (`staleRouteReqDelay` hingga `staleRecoveryTimeout`), memicu siaran Permintaan Rute (*Route Request*) aktif.
  - *Tidak Terjangkau:* $t > 90\text{ dtk}$, rekan ditandai sebagai kontak hilang.

### Pembahasan Kode Baris demi Baris
#### Baris 1–80: Deklarasi Struct, Properti, dan Inisialisator
```swift
//
//  Member.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation

/// Represents a peer member participating in an active TeeKum group session.
/// Uses the prototype's sanitized initials identity within a session.
public struct Member: Identifiable, Equatable, Hashable, Sendable {
    /// 3-letter uppercase initials identifying the member.
    public let id: String
    
    /// Display name / initials.
    public var name: String
    
    /// Initials accessor.
    public var initials: String { id }
    
    /// Latest local timestamp when a valid authenticated packet was received from this member.
    public var lastSeen: Date

    /// Hardware measurement time, kept separate from packet/peer receipt time.
    public var measurementTimestamp: Date?
    
    /// Latest reported geographical coordinate.
    public var coordinate: CLLocationCoordinate2D?
    
    /// Latest reported horizontal accuracy uncertainty radius in meters.
    public var horizontalAccuracy: CLLocationAccuracy?
    
    /// True if the member has an active Emergency SOS broadcast.
    public var isEmergency: Bool
    
    /// Latest reported battery percentage (0.0 to 1.0).
    public var batteryLevel: Float?
    
    /// Latest reported magnetic compass heading in degrees (0..<360).
    public var heading: CLLocationDirection?
    
    /// True if currently discovered within direct 1-hop radio range; false if reached via multi-hop relay.
    public var isDirectPeer: Bool
    
    /// Signal strength observed on the direct link in dBm (e.g. -65 dBm), if directly connected.
    public var rssi: Int8?
    
    /// Chosen or deterministically resolved personal member color.
    public var color: MemberColor
    
    public init(
        id: String,
        name: String? = nil,
        lastSeen: Date = Date(),
        coordinate: CLLocationCoordinate2D? = nil,
        horizontalAccuracy: CLLocationAccuracy? = nil,
        isEmergency: Bool = false,
        batteryLevel: Float? = nil,
        heading: CLLocationDirection? = nil,
        isDirectPeer: Bool = false,
        rssi: Int8? = nil,
        color: MemberColor? = nil,
        measurementTimestamp: Date? = nil
    ) {
        let cleanId = InitialsCodec.sanitize(id)
        self.id = cleanId
        self.name = name ?? cleanId
        self.lastSeen = lastSeen
        self.measurementTimestamp = measurementTimestamp
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.isEmergency = isEmergency
        self.batteryLevel = batteryLevel
        self.heading = heading
        self.isDirectPeer = isDirectPeer
        self.rssi = rssi
        self.color = color ?? MemberColor.deterministicColor(for: cleanId)
    }
```
- **Baris 13–15:** Mendeklarasikan `Member` yang mematuhi `Identifiable`, `Equatable`, `Hashable`, dan `Sendable`. Kepatuhan terhadap `Identifiable` menggunakan inisial `id` yang telah disanitasi.
- **Baris 17–51:** Properti yang mencakup identifikasi (`name`, `initials`), stempel waktu (`lastSeen`, `measurementTimestamp`), kondisi spasial (`coordinate`, `horizontalAccuracy`, `heading`), bendera darurat (`isEmergency`), telemetri (`batteryLevel`), status tautan (`isDirectPeer`, `rssi`), dan penataan gaya UI (`color`).
- **Baris 53–80:** Inisialisator yang menyanitasi `id` melalui `InitialsCodec.sanitize`. Jika `color` tidak disediakan secara eksplisit, inisialisator menghitung warna stabil yang deterministik menggunakan `MemberColor.deterministicColor(for: cleanId)`.

#### Baris 82–109: Deteksi Status Basi dan Pemulihan Bertahap
```swift
    /// Determines whether the member's last seen time is older than the given threshold.
    public func isStale(threshold: TimeInterval = MeepoConfiguration.Timing.stalePeerThreshold) -> Bool {
        Date().timeIntervalSince(lastSeen) > threshold
    }
    
    /// Determines whether the member's last seen time is within the active stale probe recovery window.
    /// Active recovery begins after `stalePeerThreshold` (30s) and expires after `stalePeerThreshold + recoveryTimeout` (90s).
    public func isWithinStaleRecoveryWindow(
        now: Date = Date(),
        staleThreshold: TimeInterval = MeshTimingConfiguration.default.stalePeerThreshold,
        recoveryTimeout: TimeInterval = MeshTimingConfiguration.default.staleRecoveryTimeout
    ) -> Bool {
        let age = now.timeIntervalSince(lastSeen)
        return age > staleThreshold && age <= (staleThreshold + recoveryTimeout)
    }
    
    /// Determines whether the member is eligible for Stage 2 on-demand AODV route discovery.
    /// Stage 2 initiates after `stalePeerThreshold + routeReqDelay` (45s) and within recovery timeout (90s).
    public func isEligibleForStaleRouteDiscovery(
        now: Date = Date(),
        staleThreshold: TimeInterval = MeshTimingConfiguration.default.stalePeerThreshold,
        routeReqDelay: TimeInterval = MeshTimingConfiguration.default.staleRouteReqDelay,
        recoveryTimeout: TimeInterval = MeshTimingConfiguration.default.staleRecoveryTimeout
    ) -> Bool {
        let age = now.timeIntervalSince(lastSeen)
        return age >= (staleThreshold + routeReqDelay) && age <= (staleThreshold + recoveryTimeout)
    }
```
- **Baris 83–85:** `isStale(threshold:)` mengembalikan nilai true jika usia $> 30\text{ dtk}$ (`MeepoConfiguration.Timing.stalePeerThreshold`).
- **Baris 89–96:** `isWithinStaleRecoveryWindow` memeriksa apakah $30\text{ dtk} < \text{usia} \le 90\text{ dtk}$ ($30 + 60$).
- **Baris 100–108:** `isEligibleForStaleRouteDiscovery` menguji apakah usia telah mencapai ambang Tahap 2 sebesar 45 detik ($30 + 15\text{ dtk}$) namun tetap berada dalam batas jendela pemulihan 90 detik. Ketika bernilai true, perute latar belakang menerbitkan siaran otomatis `RouteReqPayload` untuk mencari jalur multi-hop alternatif.

#### Baris 110–136: Implementasi Kustom Equatable dan Hashable
```swift
    public static func == (lhs: Member, rhs: Member) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.lastSeen == rhs.lastSeen &&
        lhs.measurementTimestamp == rhs.measurementTimestamp &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude &&
        lhs.horizontalAccuracy == rhs.horizontalAccuracy &&
        lhs.isEmergency == rhs.isEmergency &&
        lhs.batteryLevel == rhs.batteryLevel &&
        lhs.heading == rhs.heading &&
        lhs.isDirectPeer == rhs.isDirectPeer &&
        lhs.rssi == rhs.rssi &&
        lhs.color == rhs.color
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(lastSeen)
        if let coordinate {
            hasher.combine(coordinate.latitude)
            hasher.combine(coordinate.longitude)
        }
        hasher.combine(isEmergency)
    }
}
```
- **Baris 110–124:** Komparator kesetaraan mendalam yang memverifikasi identitas, waktu, telemetri, dan bidang status tautan.
- **Baris 126–135:** Operasi *hashing* yang efisien berfokus pada `id`, `name`, `lastSeen`, komponen koordinat, dan `isEmergency` untuk pencarian cepat di dalam `Set` dan `Dictionary`.

### Rasional Rekayasa dan Kasus Batas
- **Mengapa Koordinat Titik Mengambang CoreLocation Dihash Secara Manual:** `CLLocationCoordinate2D` tidak mematuhi protokol `Hashable` secara bawaan (*out of the box*) di Foundation. `Member.hash(into:)` secara eksplisit menggabungkan nilai ganda (*double*) `latitude` dan `longitude` ke dalam pembuat *hash* (*hasher*), memungkinkan anggota disimpan dalam struktur `Set` Swift.
- **Penjadwalan Tahap Penemuan Ulang Rute pada 45 Detik:** Jika permintaan rute langsung dikirim pada saat rekan melewatkan satu suar (*beacon*) berdurasi 10 detik, jaringan *mesh* akan jenuh dengan spam penemuan rute di tengah kerumunan yang padat. Menunggu hingga 45 detik ($30\text{ dtk} + 15\text{ dtk}$) memastikan penemuan rute hanya terpicu saat terjadi kehilangan tautan yang persisten.

---

---

## 24. Teekum/Teekum/Core/Session/MemberColor.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MemberColor.swift](../../Teekum/Teekum/Core/Session/MemberColor.swift) |
| **Jumlah Baris (`wc -l`)** | 84 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Nilai enum (`public enum MemberColor: UInt8, CaseIterable, Identifiable, Sendable`) |
| **Domain Konkurensi** | Enum primitif `Sendable`. |
| **Peran Arsitektural** | Enum domain yang mendefinisikan 8 warna identitas anggota yang dapat dipilih dengan serialisasi heksadesimal dan jembatan warna SwiftUI. |

### Apa yang Dilakukan Berkas Ini
`MemberColor.swift` mengelola kode warna anggota personal di seluruh aplikasi Meepo. Dirancang untuk mode gelap hitam pekat AMOLED (`#000000`), berkas ini mendefinisikan palet zona bencana neon yang cerah sekaligus secara ketat mengecualikan dan mencadangkan warna Merah Murni (*Pure Red*) untuk Darurat SOS. Berkas ini menangani pengkodean *wire* (1 bita), pemetaan `Color` SwiftUI, kompatibilitas mundur dengan palet warna lama yang telah dipensiunkan, opsi pemilih warna pengguna, dan *hashing* deterministik djb2 untuk penetapan warna otomatis saat seorang rekan (*peer*) tidak memilih warna secara eksplisit.

### Analogi Sederhana (ELI5)
Bayangkan menugaskan penanda tim taktis dengan visibilitas tinggi kepada para pemimpin tim SAR selama pencarian malam dengan jarak pandang nol: Pemimpin Regu 1 mendapatkan warna Amber kontras tinggi, Pemimpin Regu 2 mendapatkan warna Zamrud taktis, dan Pemimpin Regu 3 mendapatkan warna Biru penyelamat. Setiap regu terlihat jelas di peta satelit taktis dan layar radar terarah. Yang paling krusial, tidak ada anggota regu yang diberi warna Merah Sirine (`alertRedFire`)—merah berintensitas tinggi dicadangkan secara ketat di seluruh sistem untuk suar bahaya SOS dan alarm korban jiwa yang kritis.

### Definisi Istilah Teknis
- **Optimasi Mode Gelap AMOLED (*AMOLED Dark Mode Optimization*):** Warna neon jenuh kontras tinggi yang dipadukan dengan latar belakang hitam pekat (`#000000`), mengurangi konsumsi daya layar pada panel OLED sekaligus mempertahankan visibilitas tinggi di luar ruangan.
- **Aturan Reservasi Merah Murni (*Pure Red Reservation Rule*):** Batasan desain keselamatan yang mencadangkan rumpun warna merah secara eksklusif untuk peringatan dan *banner* darurat SOS, mencegah kerancuan visual selama insiden kritis.
- **Fungsi Hash djb2 (*djb2 Hash Function*):** Algoritma *hashing* string non-kriptografis yang cepat dan terdistribusi tinggi yang aslinya dibuat oleh Daniel J. Bernstein (`hash = ((hash << 5) + hash) + c`), menggunakan benih awal 5381.
- **Kompatibilitas Mundur Kode Wire (*Wire Code Backward Compatibility*):** Memastikan bahwa kode *wire* yang ditetapkan sebelumnya (seperti sampel warna pensiun `0x02` orangeSalmon atau `0x04` apricot) tetap dapat didekode dengan baik dan dipetakan ke profil visual modern.

### Pembahasan Kode Baris demi Baris
#### Baris 1–45: Deklarasi Enum dan Penamaan
```swift
//
//  MemberColor.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import SwiftUI

/// 1-byte coded color enum for personal member color-coding in TeeKum.
/// Optimized for AMOLED #000000 dark mode with vibrant neon disaster zone colors.
/// Pure Red is intentionally excluded and strictly reserved for Emergency SOS.
public enum MemberColor: UInt8, CaseIterable, Identifiable, Sendable {
    case unset            = 0x00
    case reddish          = 0x01
    case orangeSalmon     = 0x02
    case artyClickOrange  = 0x03
    case apricot          = 0x04
    case sandrift         = 0x05
    case paleBlueLily     = 0x06
    case darkSkyBlue      = 0x07
    case greenishTeal     = 0x08
    case yellow           = 0x09
    case purple           = 0x0A
    case pink             = 0x0B
    
    public var id: UInt8 { rawValue }
    
    public var name: String {
        switch self {
        case .unset:          return "Automatic"
        case .reddish:        return "Reddish"
        case .orangeSalmon:   return "Orange Salmon"
        case .artyClickOrange:return "ArtyClick Orange"
        case .apricot:        return "Apricot"
        case .sandrift:       return "Sandrift"
        case .paleBlueLily:   return "Pale Blue Lily"
        case .darkSkyBlue:    return "Dark Sky Blue"
        case .greenishTeal:   return "Greenish Teal"
        case .yellow:         return "Yellow"
        case .purple:         return "Purple"
        case .pink:           return "Pink"
        }
    }
```
- **Baris 13:** Mendeklarasikan `MemberColor` yang didukung oleh `UInt8`, mematuhi `CaseIterable`, `Identifiable`, dan `Sendable`.
- **Baris 14–25:** Mendeklarasikan 12 kasus warna (`0x00` hingga `0x0B`), termasuk `.unset` (`0x00`).
- **Baris 27:** Kepatuhan terhadap `Identifiable` menggunakan `rawValue` sebagai `id`.
- **Baris 29–44:** Properti terhitung `name` yang mengembalikan string deskriptif (misal `"Automatic"`, `"Greenish Teal"`).

#### Baris 46–64: Pemetaan Warna SwiftUI dan Palet yang Dapat Dipilih
```swift
    /// The display color in SwiftUI.
    public var swiftUIColor: Color {
        switch self {
        case .unset:
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        case .reddish: return .redProfile
        // Retired swatches keep their wire codes so saved and incoming profiles still decode.
        case .orangeSalmon, .pink: return .pinkProfile
        case .artyClickOrange, .apricot, .yellow: return .yellowProfile
        case .sandrift, .paleBlueLily, .darkSkyBlue, .purple: return .purpleProfile
        case .greenishTeal: return .greenProfile
        }
    }
    
    /// Explicit profile colors available to select.
    public static var selectableColors: [MemberColor] {
        [.yellow, .reddish, .greenishTeal, .purple, .pink]
    }
```
- **Baris 47–58:** `swiftUIColor` memetakan kasus enum mentah ke warna UI. `.unset` dipetakan ke *cyan* terang (`Color(red: 0.0, green: 0.85, blue: 1.0)`). Kasus lainnya dipetakan ke token profil warna katalog aset (`.redProfile`, `.pinkProfile`, `.yellowProfile`, `.purpleProfile`, `.greenProfile`). Sampel warna yang dipensiunkan dikonsolidasikan ke dalam token aktif untuk menjaga kompatibilitas mundur.
- **Baris 61–63:** `selectableColors` mendefinisikan 5 warna terkurasi yang disajikan kepada pengguna di pengaturan profil (`.yellow`, `.reddish`, `.greenishTeal`, `.purple`, `.pink`).

#### Baris 65–84: Resolusi Dinamis dan Hashing Deterministik djb2
```swift
    /// Resolves the color code into a specific `MemberColor`.
    /// If `code == 0x00` (unset / legacy zero-padding) or invalid, deterministically hashes `initials` mod 8.
    public static func resolve(code: UInt8, initials: String) -> MemberColor {
        if let specific = MemberColor(rawValue: code), specific != .unset {
            return specific
        }
        return deterministicColor(for: initials)
    }
    
    /// Uses the original eight-color palette to keep automatic colors stable.
    public static func deterministicColor(for initials: String) -> MemberColor {
        let clean = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return .reddish }
        
        let hash = clean.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
        let index = abs(hash) % 8 // 0...7
        let raw = UInt8(index + 1) // 1...8
        return MemberColor(rawValue: raw) ?? .reddish
    }
}
```
- **Baris 67–72:** `resolve(code:initials:)` memeriksa apakah `code` adalah kasus enum non-unset yang valid. Jika valid, mengembalikannya; jika `0x00` (tidak disetel / sisa versi terdahulu), memanggil `deterministicColor(for: initials)`.
- **Baris 75–83:** `deterministicColor(for:)` membersihkan inisial dan mengimplementasikan algoritma *hashing* djb2:
  - Nilai benih awal adalah 5381.
  - Untuk setiap bita UTF-8 $c$, mengakumulasi `(($0 << 5) &+ $0 &+ Int(c))`.
  - Menghitung `index = abs(hash) % 8` (menghasilkan rentang $0..7$).
  - Memetakan ke nilai mentah `raw = UInt8(index + 1)` (menghasilkan rentang $1..8$).
  - Mengembalikan `MemberColor` yang sesuai, menggunakan default `.reddish` jika string kosong.

### Rasional Rekayasa dan Kasus Batas
- **Mengapa Hashing djb2 Digunakan untuk Warna:** Menggunakan djb2 memberikan dua properti penting: (1) Menghasilkan warna yang identik di semua perangkat untuk setiap string inisial tertentu tanpa memerlukan negosiasi jaringan, dan (2) Mencapai dispersi tinggi di seluruh palet 8 warna, meminimalkan benturan (*collision*) warna di antara kelompok kecil.
- **Keamanan Bita Nol (*Zero Byte Safety*):** Ketika sebuah paket dari klien yang lebih lama memiliki `0x00` pada bita kode warna (sisa *zero-padding* versi lama), metode `resolve` secara otomatis mencegatnya dan menghitung warna deterministik alih-alih merender *state* yang tidak ditetapkan.

---

---

## 25. Teekum/Teekum/Core/Session/MemberID.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [MemberID.swift](../../Teekum/Teekum/Core/Session/MemberID.swift) |
| **Jumlah Baris (`wc -l`)** | 41 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Nilai (`public struct MemberID: Hashable, Codable, Sendable, CustomStringConvertible`) |
| **Domain Konkurensi** | Tipe nilai `Sendable`. |
| **Peran Arsitektural** | Tipe nilai pengidentifikasi anggota ringkas yang mengikat inisial 1 hingga 3 karakter dengan *slot* anggota yang terpartisi. |

### Apa yang Dilakukan Berkas Ini
`MemberID.swift` mendefinisikan identitas anggota yang stabil dan unik dalam sesi grup yang aktif. Berkas ini merangkum representasi string (diturunkan dari inisial yang disanitasi) dan `memberSlot` 8-bit (`0...255`) yang dimanfaatkan untuk partisi bit nomor urut pada amplop *cleartext*. Dengan memisahkan identitas anggota dari sekadar string tampilan, berkas ini menyediakan kunci kamus (*dictionary key*) yang konsisten untuk pelacakan kehadiran, perutean pesan, dan pencatatan peristiwa kontak yang terputus.

### Analogi Sederhana (ELI5)
Bayangkan `MemberID` sebagai lencana kredensial resmi zona bencana Anda. Nama panggilan Anda ("NIC") dicetak di bagian depan dengan huruf tebal agar teman-teman Anda mengenali Anda, tetapi lencana tersebut juga memiliki nomor slot magnetik terenkode yang tercap di sudut bawah. Nomor slot tersebut memberi tahu jaringan *mesh* jalur transmisi mana yang secara spesifik menjadi milik Anda.

### Definisi Istilah Teknis
- **Partisi Bit Nomor Urut (*Sequence Number Bit Partitioning*):** Mengalokasikan 8 bit teratas dari nomor urut paket 32-bit (`sequenceNumber >> 24`) untuk menyimpan *slot* anggota pengirim, memastikan ruang urutan monotonik yang independen hingga untuk 256 rekan (*peer*).
- **CustomStringConvertible:** Protokol pustaka standar Swift yang memungkinkan tipe kustom memberikan deskripsi string eksplisit saat dicetak atau diinterpolasi dalam string literal.
- **Derivasi Slot Deterministik (*Deterministic Slot Derivation*):** Menghitung nomor *slot* 8-bit dengan melakukan operasi XOR terhadap dua bita terenkode Base-27 dari inisial anggota yang telah disanitasi (`bytes[0] ^ bytes[1]`).

### Pembahasan Kode Baris demi Baris
#### Baris 1–23: Deklarasi Struct dan Inisialisator
```swift
//
//  MemberID.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Stable session member identifier; independent of display initials.
public struct MemberID: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Unique identifier string within the active session (e.g. derived from slot + initials or UUID).
    public let rawValue: String

    /// Assigned 8-bit member slot (0...255) used for sequence-number partitioning.
    public let memberSlot: UInt8

    public var description: String { rawValue }

    public init(rawValue: String, memberSlot: UInt8 = 0) {
        self.rawValue = rawValue
        self.memberSlot = memberSlot
    }
```
- **Baris 11:** Mendeklarasikan `MemberID` yang mematuhi `Hashable`, `Codable`, `Sendable`, dan `CustomStringConvertible`.
- **Baris 13–16:** Mendefinisikan properti *immutable*: `rawValue` (String) yang mewakili string pengidentifikasi dan `memberSlot` (UInt8) yang mewakili *slot* partisi urutan.
- **Baris 18:** Mematuhi `CustomStringConvertible` dengan mengembalikan `rawValue`.
- **Baris 20–23:** Inisialisator berbasis anggota dengan nilai default `memberSlot` bernilai 0.

#### Baris 25–41: Metode Pabrik (Factory Methods) dan Derivasi Slot
```swift
    /// Creates a deterministic MemberID from sanitized 1-to-3 letter initials and optional slot.
    public static func fromInitials(_ initials: String, slot: UInt8? = nil) -> MemberID {
        let clean = Self.sanitizeInitials(initials)
        let resolvedSlot = slot ?? Self.deriveSlot(from: clean)
        return MemberID(rawValue: clean, memberSlot: resolvedSlot)
    }

    /// Sanitizes arbitrary user input into 1 to 3 uppercase alphanumeric characters (A...Z, 0...9).
    public static func sanitizeInitials(_ input: String) -> String {
        InitialsCodec.sanitize(input)
    }

    private static func deriveSlot(from cleanInitials: String) -> UInt8 {
        let bytes = InitialsCodec.encode(cleanInitials) ?? [0, 0]
        return bytes[0] ^ bytes[1]
    }
}
```
- **Baris 26–30:** `fromInitials(_:slot:)` menyanitasi karakter masukan dan menentukan *slot*: jika `slot` diabaikan, metode memanggil `deriveSlot(from:)`.
- **Baris 33–35:** `sanitizeInitials(_:)` menjembatani ke `InitialsCodec.sanitize(input)` untuk menghasilkan 1 hingga 3 karakter huruf kapital.
- **Baris 37–40:** `deriveSlot(from:)` mengodekan inisial bersih ke dalam 2 bita Base-27 dan mengembalikan hasil operasi XOR bitwise-nya (`bytes[0] ^ bytes[1]`).

### Rasional Rekayasa dan Kasus Batas
- **Mengapa Derivasi XOR Bersifat Deterministik:** Dalam jaringan *mesh* luring terdesentralisasi tanpa koordinator terpusat untuk menetapkan nomor *slot*, melakukan operasi XOR terhadap bita Base-27 inisial memungkinkan semua simpul penerima menurunkan nomor *slot* yang identik tanpa pertukaran jabat tangan (*handshake*) protokol tambahan.

---

---

## 26. Teekum/Teekum/Core/Session/SessionHolder.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SessionHolder.swift](../../Teekum/Teekum/Core/Session/SessionHolder.swift) |
| **Jumlah Baris (`wc -l`)** | 19 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Referensi (`final class SessionHolder: @unchecked Sendable`) |
| **Domain Konkurensi** | Keamanan thread `@unchecked Sendable` yang disinkronkan melalui `NSLock` internal. |
| **Peran Arsitektural** | Kontainer *observable* yang memegang instans GroupSession aktif untuk observasi tampilan SwiftUI yang reaktif. |

### Apa yang Dilakukan Berkas Ini
`SessionHolder.swift` menyediakan cuplikan sinkron yang aman untuk *thread* (*thread-safe synchronous snapshot*) dari `GroupSession` yang aktif bagi aktor latar belakang, delegasi *transport*, dan penutup (*closures*) pengiriman paket tingkat rendah. Karena aktor Swift dapat mengalami penundaan *reentrancy* dan penangguhan asinkron (*async suspension*), `SessionHolder` memungkinkan rutinitas perutean dan kriptografi yang kritis terhadap performa memeriksa kredensial sesi saat ini secara sinkron tanpa melintasi batas-batas isolasi aktor.

### Analogi Sederhana (ELI5)
Bayangkan antrean pemeriksaan keamanan bandara yang serba cepat. Jika setiap petugas harus berhenti dan menggunakan radio panggil ke penyelia utama di seberang gedung hanya untuk memeriksa nomor penerbangan, seluruh antrean akan terhenti total. Sebagai gantinya, penyelia menulis nomor penerbangan saat ini di papan tulis kecil di dalam kotak kunci kaca tepat di samping gerbang (`NSLock`). Petugas mana pun dapat melihat sekilas melalui kaca dalam sekejap milidetik untuk memverifikasi kredensial secara instan.

### Definisi Istilah Teknis
- **`@unchecked Sendable`:** Atribut konkurensi Swift yang memberi tahu kompilator bahwa sebuah kelas tidak memenuhi verifikasi kompilator otomatis untuk `Sendable`, tetapi pemrogram menjamin keamanan *thread* secara manual melalui primitif sinkronisasi internal (seperti `NSLock`).
- **`NSLock`:** Kunci dasar Foundation yang menyinkronkan akses ke bagian kritis (*critical section*) di beberapa *thread* POSIX, memblokir *thread* pemanggil hingga kunci diperoleh.
- **Reentransi Aktor (*Actor Reentrancy*):** Perilaku dalam Swift Concurrency di mana sebuah aktor dapat menyelingi eksekusi tugas lain saat menunggu panggilan asinkron, yang berpotensi memodifikasi *state* internal aktor sebelum panggilan awal dilanjutkan.

### Pembahasan Kode Baris demi Baris
#### Baris 1–19: Deklarasi Kelas Lengkap
```swift
//
//  SessionHolder.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Synchronous session snapshots for Sendable closures used by actors.
final class SessionHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var value: GroupSession?

    var session: GroupSession? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
```
- **Baris 11:** Mendeklarasikan `SessionHolder` sebagai `final class` yang mematuhi `@unchecked Sendable`.
- **Baris 12–13:** Memegang instans `NSLock` privat dan `value: GroupSession?` opsional.
- **Baris 15–18:** Properti terhitung `session` menyediakan pengakses get dan set yang aman untuk *thread* menggunakan `lock.withLock { ... }`.

### Rasional Rekayasa dan Kasus Batas
- **Mengapa Akses Sinkron Sangat Diperlukan:** *Handler* pengiriman paket jaringan latar belakang (seperti loop penerimaan `Network.framework`) berjalan pada antrean pengiriman (*dispatch queue*) tingkat rendah dan harus segera mendekripsi datagram. Menunggu panggilan aktor pada aktor utama atau manajer tingkat tinggi dapat menimbulkan *jitter* antrean dan penumpukan memori; `SessionHolder` menghadirkan pembacaan cuplikan dalam waktu sub-mikrodetik.

---

---

## 27. Teekum/Teekum/Core/Session/SessionPersistence.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SessionPersistence.swift](../../Teekum/Teekum/Core/Session/SessionPersistence.swift) |
| **Jumlah Baris (`wc -l`)** | 43 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Referensi (`@MainActor final class SessionPersistence`) |
| **Domain Konkurensi** | Koordinator persistensi yang terisolasi pada `@MainActor`. |
| **Peran Arsitektural** | Aktor yang mengelola persistensi aman pada disk untuk kredensial sesi grup aktif dan metadata peserta. |

### Apa yang Dilakukan Berkas Ini
`SessionPersistence.swift` mengelola penyimpanan persisten dan pemulihan status sesi grup di seluruh peluncuran aplikasi. Berkas ini mengimplementasikan arsitektur penyimpanan terpisah (*split-storage architecture*): metadata sesi non-sensitif (ID sesi, nama sesi, inisial pengguna, kode warna, peran *host*, dan tanggal pembuatan) diserialisasi sebagai JSON di `UserDefaults`, sementara kunci enkripsi simetris 256-bit yang sangat sensitif disimpan dengan aman di iOS Keychain yang didukung perangkat keras melalui `KeychainStore`.

### Analogi Sederhana (ELI5)
Bayangkan mengamankan perlengkapan operasional Anda di pos persiapan darurat lapangan. Anda menuliskan tanda panggil unit, penunjukan regu, dan sektor operasional Anda pada papan tugas berlaminasi yang disematkan di papan pengumuman tenda komando (`UserDefaults`). Tetapi Anda mengambil kunci master kriptografis terenkripsi Anda dan menguncinya di dalam brankas baja biometrik yang tertanam di sasis kendaraan komando (`iOS Keychain`). Jika pihak yang tidak berwenang masuk ke area persiapan, mereka mungkin melihat nama unit Anda, tetapi mereka tidak dapat mengakses atau mencuri kunci komunikasi kriptografis Anda.

### Definisi Istilah Teknis
- **Arsitektur Penyimpanan Terpisah (*Split-Storage Architecture*):** Pola keamanan yang memisahkan metadata konfigurasi publik dari rahasia kriptografis sensitif di berbagai subsistem penyimpanan dengan tingkat keamanan yang berbeda.
- **Layanan Keychain (*Keychain Services*):** Basis data aman Apple yang didukung perangkat keras untuk menyimpan rahasia kecil dan sensitif (kata sandi, kunci privat, token simetris) yang dilindungi oleh enkripsi perangkat keras dan kode sandi perangkat.
- **`UserDefaults`:** Penyimpanan persistensi daftar properti (*property-list*) yang ringan dan tidak terenkripsi, hanya cocok untuk preferensi pengguna dan bendera konfigurasi non-sensitif.
- **Rekonstitusi Sesi (*Session Reconstitution*):** Proses pemuatan metadata dari `UserDefaults`, pengambilan kunci simetris dari Keychain, dan rekonstruksi model `GroupSession` yang valid.

### Pembahasan Kode Baris demi Baris
#### Baris 1–20: Deklarasi Kelas dan Dependensi
```swift
//
//  SessionPersistence.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
import Foundation

@MainActor
final class SessionPersistence {
    private let defaults: UserDefaults
    private let keys: KeychainStore
    private let storageKey = "com.teekum.sessionMetadata"

    init(defaults: UserDefaults = .standard, keys: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keys = keys
    }
```
- **Baris 11:** Terisolasi pada `@MainActor`, dideklarasikan sebagai `final class`.
- **Baris 13–15:** Menginjeksikan `UserDefaults`, `KeychainStore`, dan mendefinisikan kunci penyimpanan `"com.teekum.sessionMetadata"`.
- **Baris 17–20:** Inisialisator yang menyediakan instans default (`.standard` dan `KeychainStore()`).

#### Baris 22–42: Operasi Simpan, Muat, dan Bersihkan
```swift
    func save(_ session: GroupSession) async throws {
        let data = try JSONEncoder().encode(SessionRecord(session))
        try await keys.storeKeyInKeychain(SymmetricKey(data: session.symmetricKeyData), forSessionId: session.sessionId)
        defaults.set(data, forKey: storageKey)
    }

    func load() async throws -> GroupSession? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        let record = try JSONDecoder().decode(SessionRecord.self, from: data)
        guard let key = try await keys.loadKeyFromKeychain(forSessionId: record.sessionId) else {
            defaults.removeObject(forKey: storageKey)
            return nil
        }
        return record.session(key: key.withUnsafeBytes { Data($0) })
    }

    func clear() async throws {
        let record = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(SessionRecord.self, from: $0) }
        defaults.removeObject(forKey: storageKey)
        if let record { try await keys.purgeKeyFromKeychain(forSessionId: record.sessionId) }
    }
}
```
- **Baris 22–26:** `save(_:)`: Mengodekan `SessionRecord(session)` ke JSON. Mengonversi `session.symmetricKeyData` menjadi `CryptoKit.SymmetricKey` dan menulisnya ke Keychain dengan kunci `session.sessionId`. Terakhir, menulis JSON metadata ke `UserDefaults`.
- **Baris 28–36:** `load()`: Membaca JSON metadata dari `UserDefaults`. Jika tidak ada, mengembalikan `nil`. Mendekode `SessionRecord`. Menunggu pengambilan kunci dari Keychain untuk `record.sessionId`. Jika kunci hilang dari Keychain (misal, dibersihkan oleh OS atau kegagalan biometrik), metode membersihkan rekaman `UserDefaults` dan mengembalikan `nil`. Jika berhasil, merekonstitusi dan mengembalikan `GroupSession`.
- **Baris 38–42:** `clear()`: Membaca rekaman metadata yang ada untuk mengekstrak `record.sessionId`, menghapus entri dari `UserDefaults`, dan membersihkan kunci dari Keychain melalui `keys.purgeKeyFromKeychain`.

### Rasional Rekayasa dan Kasus Batas
- **Status Rusak yang Pulih Sendiri (*Self-Healing Broken State*):** Jika aplikasi mengalami *crash* saat pembersihan sesi sebelumnya, atau jika item Keychain terhapus, `load()` mendeteksi bahwa `UserDefaults` memiliki metadata tetapi Keychain kehilangan kuncinya. Alih-alih mengalami *crash*, metode ini membersihkan rekaman yatim di `UserDefaults` dan mengembalikan `nil`, menampilkan layar pemasangan (*pairing*) yang bersih.
- **Nol Data Sensitif dalam Cadangan (*Zero Sensitive Data in Backups*):** Karena `UserDefaults` dapat dicadangkan ke iCloud atau cadangan iTunes yang tidak terenkripsi, menghilangkan kunci simetris mencegah kunci sesi masuk ke dalam berkas cadangan.

---

---

## 28. Teekum/Teekum/Core/Session/SessionRecord.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SessionRecord.swift](../../Teekum/Teekum/Core/Session/SessionRecord.swift) |
| **Jumlah Baris (`wc -l`)** | 33 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Nilai (`struct SessionRecord: Codable`) |
| **Domain Konkurensi** | Tipe nilai implisit `Sendable`. |
| **Peran Arsitektural** | Skema persistensi Codable yang digunakan untuk membuat serialisasi dan memulihkan status sesi aktif di seluruh proses muat ulang aplikasi. |

### Apa yang Dilakukan Berkas Ini
`SessionRecord.swift` mendefinisikan objek transfer data (*data transfer object* / DTO) persis yang digunakan oleh `SessionPersistence` untuk membuat serialisasi metadata sesi grup ke dalam `UserDefaults`. Berdasarkan rancangan, `SessionRecord` hanya menyimpan properti pemulihan publik (`sessionId`, `sessionName`, `localInitials`, `localColorCode`, `isHost`, `createdAt`) dan secara eksplisit mengecualikan kunci enkripsi simetris, roster anggota, jejak lokasi, dan riwayat pesan.

### Analogi Sederhana (ELI5)
Saat Anda meninggalkan kamar hotel, `SessionRecord` adalah label bagasi yang diikatkan pada koper Anda. Label tersebut menunjukkan nama, nomor kamar, dan tanggal *check-in* Anda. Label tersebut tidak berisi kunci kamar Anda, foto-foto pribadi Anda, atau percakapan yang Anda lakukan di dalam kamar.

### Definisi Istilah Teknis
- **Data Transfer Object (DTO):** Objek yang membawa data antar proses atau subsistem tanpa mengandung logika bisnis, disesuaikan secara ketat untuk serialisasi.
- **Serialisasi Nir-Kunci (*Key-less Serialization*):** Menghilangkan kunci kriptografis secara sengaja dari model berseri untuk memenuhi prinsip hak istimewa terendah (*least privilege*) dan penyimpanan nir-pengetahuan (*zero-knowledge storage*).
- **Pelindung Rekonstitusi (*Reconstitution Guard*):** Memvalidasi bahwa semua bidang yang dimuat mematuhi invarian protokol domain sebelum membuat ulang entitas *runtime*.

### Pembahasan Kode Baris demi Baris
#### Baris 1–33: Deklarasi Struct Lengkap
```swift
//
//  SessionRecord.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Recovery metadata contains no key, location, roster or conversation history.
struct SessionRecord: Codable {
    let sessionId: UInt32
    let sessionName: String
    let localInitials: String
    let localColorCode: UInt8
    let isHost: Bool
    let createdAt: Date

    init(_ session: GroupSession) {
        sessionId = session.sessionId
        sessionName = session.sessionName
        localInitials = session.localInitials
        localColorCode = session.localColorCode
        isHost = session.isHost
        createdAt = session.createdAt
    }

    func session(key: Data) -> GroupSession? {
        guard PacketConstants.isValidSessionId(sessionId), key.count == 32, InitialsCodec.isValid(localInitials) else { return nil }
        return GroupSession(sessionId: sessionId, sessionName: sessionName, symmetricKeyData: key,
            localInitials: localInitials, localColorCode: localColorCode, isHost: isHost, createdAt: createdAt)
    }
}
```
- **Baris 11–17:** Mendeklarasikan `SessionRecord` yang mematuhi `Codable`. Memegang 6 properti *immutable* yang mewakili metadata sesi.
- **Baris 19–26:** Inisialisator yang menyalin bidang metadata dari `GroupSession` yang aktif.
- **Baris 28–32:** `session(key:)` menggabungkan metadata yang tersimpan dengan kunci 32-bita yang dimuat secara aman:
  - Memvalidasi `PacketConstants.isValidSessionId(sessionId)` ($1 \le \text{sid} \le 0xFFFFFF$).
  - Memvalidasi `key.count == 32` (kebutuhan 256-bit).
  - Memvalidasi `InitialsCodec.isValid(localInitials)`.
  - Merekonstitusi dan mengembalikan struktur `GroupSession` lengkap, atau `nil` jika validasi gagal.

### Rasional Rekayasa dan Kasus Batas
- **Pertahanan Berlapis (*Defense in Depth*):** Bahkan jika penyerang memperoleh akses ke `UserDefaults` melalui cadangan perangkat yang tidak terenkripsi atau *dump* pengawakutuan (*debugging dump*), `SessionRecord` sama sekali tidak mengandung materi kriptografis. Tanpa akses fisik ke perangkat untuk membuka Keychain, komunikasi sesi tidak dapat didekripsi.

---

---

## 29. Teekum/Teekum/Core/Session/SessionStore.swift

### Metadata Berkas
| Atribut | Spesifikasi |
| :--- | :--- |
| **Jalur Relatif Repositori** | [SessionStore.swift](../../Teekum/Teekum/Core/Session/SessionStore.swift) |
| **Jumlah Baris (`wc -l`)** | 192 baris |
| **Tipe Berkas** | Berkas Sumber Swift |
| **Target Kompilasi** | `Teekum` (Target Aplikasi) |
| **Semantik Tipe** | Tipe Referensi (`@MainActor @Observable public final class SessionStore`) |
| **Domain Konkurensi** | Penyimpan status domain *observable* pada `@MainActor`. |
| **Peran Arsitektural** | Penyimpan status *observable* pusat yang melacak roster peserta, titik temu aktif, peristiwa kehilangan kontak, dan keberadaan rekan (*presence*). |

### Apa yang Dilakukan Berkas Ini
`SessionStore.swift` adalah sumber kebenaran *observable* pusat untuk semua status sesi aktif di lapisan UI Meepo. Didukung oleh kerangka kerja Modern Swift Observation (`@Observable`), berkas ini mengelola `GroupSession` yang sedang diikuti, undangan yang tertunda, URL *deep link*, daftar anggota rekan (`[Member]`), pelacakan anggota yang tidak terjangkau, log audit kehilangan kontak, dan proposal titik temu grup aktif tunggal (`MeetingPoint`). Berkas ini menerapkan pembaruan paket masuk (`LocationPingPayload`, `SOSPayload`, dan cuplikan rekan *transport*) ke status anggota, menerapkan pelindung stempel waktu monotonik untuk mencegah pemunduran status akibat paket yang datang terlambat.

### Analogi Sederhana (ELI5)
Bayangkan papan status taktis utama di Pos Komando Insiden. Papan tersebut melacak setiap penyelamat yang diterjunkan ke sektor operasional: koordinat GPS tepat mereka, kekuatan sinyal tautan radio langsung, tingkat cadangan baterai, dan apakah ada unit yang memicu suar marabahaya SOS darurat. Saat petugas radio menerima telemetri masuk, mereka memperbarui papan tersebut. Karena papan tersebut menggunakan pelacakan reaktif otomatis (`@Observable`), setiap layar penyelamat dan peta situasional langsung diperbarui begitu ada perubahan yang dicatat.

### Definisi Istilah Teknis
- **`@Observable` (Kerangka Kerja Observasi):** Makro Swift 5.9+ yang memungkinkan pelacakan tingkat properti untuk pembatalan tampilan SwiftUI tanpa memerlukan pembungkus `@Published` atau *boilerplate* protokol `ObservableObject`.
- **Pelindung Pengukuran Monotonik (*Monotonic Measurement Guard*):** Aturan validasi pembaruan yang memastikan sampel lokasi dan arah hadap yang masuk hanya diterima jika stempel waktu pengukuran perangkat kerasnya lebih baru daripada data yang tercatat, mencegah pengiriman *mesh* yang tidak berurutan memundurkan lokasi pengguna ke waktu lampau.
- **Invarian Visibilitas Darurat (*Emergency Visibility Invariant*):** Aturan yang menyatakan bahwa anggota rekan dengan status darurat aktif (`$0.isEmergency == true`) tidak pernah disembunyikan dari pandangan, bahkan jika sinyal radio mereka telah hilang melewati ambang batas pemutusan tidak terjangkau.
- **Audit Kehilangan Kontak (*Contact Loss Auditing*):** Mencatat stempel waktu yang tepat saat seorang rekan bertransisi dari terjangkau menjadi tidak terjangkau, memelihara antrean FIFO terbatas hingga 100 peristiwa kehilangan kontak historis untuk inspeksi diagnostik.

### Pembahasan Kode Baris demi Baris
#### Baris 1–49: Deklarasi Kelas, Tipe Bersarang, dan Properti
```swift
//
//  SessionStore.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation
import CoreLocation
import Observation

/// Accepted session state shared by feature ViewModels; owns no background work.
@MainActor
@Observable
public final class SessionStore {
    struct MemberContactLoss: Identifiable, Equatable {
        let id = UUID()
        let initials: Member.ID
        let timestamp: Date
    }

    /// Active group session; nil when unpaired (AppRootView shows Pairing).
    public var activeSession: GroupSession?
    public var pendingInvite: GroupSessionInvite?
    public var pendingDeepLink: URL?

    /// Accepted peer members in the current group session.
    public var members: [Member]

    private var unreachableMemberIDs: Set<Member.ID> = []
    private(set) var memberContactLog: [MemberContactLoss] = []

    var visibleMembers: [Member] {
        members.filter { $0.isEmergency || !unreachableMemberIDs.contains($0.id) }
    }

    /// Single active group meeting point proposal, if any.
    public var activeMeetingPoint: MeetingPoint?

    public var hasActiveSession: Bool {
        activeSession != nil
    }

    func profileColor(for initials: String) -> MemberColor {
        if let activeSession, activeSession.localInitials == initials {
            return .resolve(code: activeSession.localColorCode, initials: initials)
        }
        return members.first { $0.id == initials }?.color ?? .deterministicColor(for: initials)
    }
```
- **Baris 13–15:** Dianotasi dengan `@MainActor` dan `@Observable`, dideklarasikan sebagai `public final class`.
- **Baris 16–20:** Model `MemberContactLoss` yang mencatat ID anggota dan stempel waktu.
- **Baris 23–29:** Properti *observable* inti: `activeSession`, `pendingInvite`, `pendingDeepLink`, dan larik `members`.
- **Baris 30–31:** Status internal yang melacak ID anggota yang tidak terjangkau dan log audit kehilangan kontak.
- **Baris 33–35:** `visibleMembers` memfilter anggota secara dinamis: anggota darurat dijamin tetap terlihat, sementara anggota yang tidak terjangkau tanpa keadaan darurat difilter.
- **Baris 38–42:** `activeMeetingPoint` dan properti terhitung `hasActiveSession`.
- **Baris 44–49:** `profileColor(for:)` menentukan warna untuk setiap anggota, memprioritaskan warna sesi lokal aktif, lalu warna roster, lalu warna djb2 deterministik.

#### Baris 51–100: Mutasi Status dan Penerimaan Paket
```swift
    public init(
        activeSession: GroupSession? = nil,
        members: [Member] = [],
        activeMeetingPoint: MeetingPoint? = nil
    ) {
        self.activeSession = activeSession
        self.members = members
        self.activeMeetingPoint = activeMeetingPoint
    }

    // MARK: - State Mutations

    func setEmergency(_ isEmergency: Bool, for initials: Member.ID) {
        guard let index = members.firstIndex(where: { $0.id == initials }) else { return }
        members[index].isEmergency = isEmergency
    }

    func applyLocationPing(_ ping: LocationPingPayload, inbound: InboundPacket) {
        let existing = members.first { $0.id == ping.senderInitials }
        upsertMember(Member(id: ping.senderInitials, lastSeen: inbound.receivedAt, coordinate: ping.coordinate,
            horizontalAccuracy: Double(ping.accuracy), isEmergency: existing?.isEmergency ?? false,
            batteryLevel: Float(ping.batteryLevel) / 100, heading: ping.headingDegrees,
            isDirectPeer: inbound.rawPacket.envelope.hopCount == 0, rssi: inbound.receivedRssi,
            color: .resolve(code: ping.colorCode, initials: ping.senderInitials), measurementTimestamp: ping.timestamp))
    }

    func applySOSLocation(_ payload: SOSPayload, inbound: InboundPacket) {
        let existing = members.first { $0.id == payload.senderInitials }
        let hasLocation = payload.timestamp.timeIntervalSince1970 > 0
        upsertMember(Member(id: payload.senderInitials, lastSeen: inbound.receivedAt,
            coordinate: hasLocation ? payload.coordinate : nil,
            horizontalAccuracy: hasLocation ? Double(payload.accuracy) : nil,
            isEmergency: existing?.isEmergency ?? false, batteryLevel: Float(payload.batteryLevel) / 100,
            heading: existing?.heading, isDirectPeer: inbound.rawPacket.envelope.hopCount == 0,
            rssi: inbound.receivedRssi, color: .resolve(code: payload.colorCode, initials: payload.senderInitials),
            measurementTimestamp: hasLocation ? payload.timestamp : nil))
    }

    func applyPeerSnapshot(_ peers: [PeerInfo], connected: Set<String>) {
        for index in members.indices {
            members[index].isDirectPeer = connected.contains(members[index].id)
        }
        for peer in peers where peer.isGroupMember && peer.isDirectLink && peer.id != activeSession?.localInitials {
            var member = members.first { $0.id == peer.id } ?? Member(id: peer.id, lastSeen: peer.lastSeen)
            member.isDirectPeer = true
            member.rssi = peer.rssi
            member.lastSeen = max(member.lastSeen, peer.lastSeen)
            upsertMember(member)
        }
    }
```
- **Baris 51–59:** Inisialisator dengan *state* awal opsional.
- **Baris 63–66:** `setEmergency(_:for:)` memodifikasi bendera darurat untuk ID anggota tertentu.
- **Baris 68–75:** `applyLocationPing(_:inbound:)` memetakan bidang ping masuk ke struktur `Member`: mengekstrak koordinat, akurasi, baterai, arah hadap, status rekan langsung (`hopCount == 0`), RSSI, dan menentukan kode warna sebelum memanggil `upsertMember`.
- **Baris 77–87:** `applySOSLocation(_:inbound:)` menerima telemetri darurat, mempertahankan arah hadap yang ada dan memperbarui koordinat.
- **Baris 89–100:** `applyPeerSnapshot(_:connected:)` menyinkronkan bendera konektivitas radio langsung dari lapisan *transport*.

#### Baris 102–152: Penyegaran Visibilitas, Upsert dengan Pelindung Monotonik, dan Reset
```swift
    func refreshMemberVisibility(now: Date, peers: [PeerInfo]) -> [MemberContactLoss] {
        let timing = MeshTimingConfiguration.default
        let cutoff = now.addingTimeInterval(-(timing.stalePeerThreshold + timing.staleRecoveryTimeout))
        let connected = Set(peers.lazy.filter { $0.isGroupMember && $0.isDirectLink }.map(\.id))
        let unreachable = Set(members.lazy.filter {
            $0.lastSeen < cutoff && !connected.contains($0.id)
        }.map(\.id))
        guard unreachable != unreachableMemberIDs else { return [] }
        let losses = unreachable.subtracting(unreachableMemberIDs).sorted().map {
            MemberContactLoss(initials: $0, timestamp: now)
        }
        unreachableMemberIDs = unreachable
        if !losses.isEmpty {
            memberContactLog.append(contentsOf: losses)
            if memberContactLog.count > 100 {
                memberContactLog.removeFirst(memberContactLog.count - 100)
            }
        }
        return losses
    }

    /// Inserts or updates a member record only if the incoming sample is not older than existing state.
    public func upsertMember(_ incoming: Member) {
        if let index = members.firstIndex(where: { $0.id == incoming.id }) {
            let existing = members[index]
            var accepted = incoming
            if let existingTime = existing.measurementTimestamp,
               incoming.measurementTimestamp.map({ $0 < existingTime }) ?? true {
                accepted.coordinate = existing.coordinate
                accepted.horizontalAccuracy = existing.horizontalAccuracy
                accepted.measurementTimestamp = existingTime
                accepted.heading = existing.heading
            }
            accepted.lastSeen = max(existing.lastSeen, incoming.lastSeen)
            members[index] = accepted
        } else {
            members.append(incoming)
        }
    }

    /// Resets all in-memory session state on leave or expiry.
    public func resetSessionState() {
        activeSession = nil
        pendingInvite = nil
        pendingDeepLink = nil
        members.removeAll()
        unreachableMemberIDs.removeAll()
        memberContactLog.removeAll()
        activeMeetingPoint = nil
    }
}
```
- **Baris 102–121:** `refreshMemberVisibility(now:peers:)` menghitung ambang batas pemutusan sebagai $30\text{ dtk} + 60\text{ dtk} = 90\text{ dtk}$ yang lalu. Mengidentifikasi rekan yang tidak terjangkau yang tidak terhubung secara langsung. Jika ada anggota baru yang menjadi tidak terjangkau, metode mencatat rekaman `MemberContactLoss` (dibatasi pada penyangga FIFO 100 entri) dan mengembalikannya untuk memicu peringatan pengguna.
- **Baris 124–140:** `upsertMember(_:)` mengimplementasikan Pelindung Pengukuran Monotonik. Jika rekaman sudah ada, ia memeriksa apakah `incoming.measurementTimestamp < existing.measurementTimestamp`. Jika telemetri yang masuk lebih lama (karena keterlambatan jaringan), data spasial yang masuk (`coordinate`, `horizontalAccuracy`, `heading`) dibuang, mempertahankan posisi terbaru yang sudah ada sembari tetap memperbarui `lastSeen` menjadi `max(existing.lastSeen, incoming.lastSeen)`.
- **Baris 143–151:** `resetSessionState()` membersihkan semua status sesi, anggota, dan titik temu di memori saat keluar atau sesi berakhir.

#### Baris 154–192: Fixture Pratinjau SwiftUI
```swift
// MARK: - Preview Fixtures for UI Migration

extension SessionStore {
    /// Ready-to-use fixture store for MainMapView, MeetingPointsView, and FriendDetailView previews.
    public static var preview: SessionStore {
        let baseCoord = CLLocationCoordinate2D(latitude: -6.1988, longitude: 106.8225) // Thamrin / Central Jakarta area

        let session = GroupSession(
            sessionId: 0x4321,
            sessionName: "Fantasix disaster zone Crew",
            localInitials: "DAF",
            isHost: true
        )

        let adiat = Member(id: "ADI", name: "Adiat", coordinate: .init(latitude: baseCoord.latitude + 0.0004, longitude: baseCoord.longitude + 0.0003), horizontalAccuracy: 6, batteryLevel: 0.84, heading: 90, isDirectPeer: true, rssi: -62, measurementTimestamp: .now.addingTimeInterval(-8))
        let nicho = Member(id: "NIC", name: "Nicho", coordinate: .init(latitude: baseCoord.latitude - 0.0005, longitude: baseCoord.longitude + 0.0006), horizontalAccuracy: 12, batteryLevel: 0.65, heading: 180, isDirectPeer: true, rssi: -74, measurementTimestamp: .now.addingTimeInterval(-95))
        let hasan = Member(id: "HAS", name: "Hasan", coordinate: .init(latitude: baseCoord.latitude + 0.0008, longitude: baseCoord.longitude - 0.0004), horizontalAccuracy: 25, batteryLevel: 0.42, heading: 270, measurementTimestamp: .now.addingTimeInterval(-360))

        var meeting = MeetingPoint(
            name: "Main Stage Sound Booth",
            coordinate: CLLocationCoordinate2D(
                latitude: baseCoord.latitude + 0.0002,
                longitude: baseCoord.longitude - 0.0002
            ),
            targetTime: .now.addingTimeInterval(1800),
            proposerInitials: "ADI",
            landmarkId: 1
        )
        meeting.attendance[.fromInitials(adiat.id)] = .accepted
        meeting.attendance[.fromInitials(nicho.id)] = .accepted
        meeting.attendance[.fromInitials(hasan.id)] = .pending

        return SessionStore(
            activeSession: session,
            members: [adiat, nicho, hasan],
            activeMeetingPoint: meeting
        )
    }
}
```
- **Baris 158–191:** *Fixture* statis `preview` yang dikonfigurasi dengan koordinat Jakarta Pusat (`-6.1988, 106.8225`), membuat anggota tiruan yang realistis ("Adiat", "Nicho", "Hasan") dengan variasi baterai, akurasi, arah hadap, dan titik temu aktif di "Main Stage Sound Booth".

### Rasional Rekayasa dan Kasus Batas
- **Perlindungan Pengiriman Multi-Hop yang Tidak Berurutan (*Out-of-Order Multi-Hop Delivery Protection*):** Dalam jaringan nirkabel *mesh*, paket A (dikirim pada 12:00:00) mungkin menempuh jalur 3-hop dan tiba pada 12:00:03, sedangkan paket B (dikirim pada 12:00:01) menempuh jalur langsung 1-hop dan tiba pada 12:00:02. Tanpa pemeriksaan monotonik `upsertMember`, kedatangan paket A akan menimpa paket B, menyebabkan penanda peta UI melompat mundur ke masa lalu.
- **Log Audit Terbatas (100 Entri):** Untuk mencegah konsumsi memori tak terbatas selama operasi bencana berhari-hari dengan konektivitas yang fluktuatif, `memberContactLog` memangkas rekaman tertua saat jumlah entri melebihi 100.

---

---

## Navigasi Catatan Kaki (Footer Navigation)

| Target Navigasi | Jalur |
| :--- | :--- |
| **Volume Sebelumnya** | [Volume 01: Application Lifecycle, Architecture & Shared UI](01_app_lifecycle.md) |
| **Indeks Utama** | [Volume 00: Index and System Architecture](00_index_and_architecture.md) |
| **Volume Berikutnya** | [Volume 03: Transport Layer, Stream Framing & Security](03_transport_and_security.md) |
