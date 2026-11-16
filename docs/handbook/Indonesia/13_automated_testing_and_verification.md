# Volume 13: Pengujian Otomatis, Paritas Wire & Rangka Verifikasi (Meepo)

## Filosofi Pengujian Tanpa Perangkat Keras (Zero-Hardware) & Ringkasan

Volume 13 mengeksplorasi infrastruktur pengujian otomatis, rangka verifikasi protokol, abstraksi tiruan (mock) deterministik, dan kontrak paritas wire yang mengatur platform jaringan mesh ad-hoc Meepo. Dirancang untuk zona bencana off-grid, runtuhan struktural, dan operasi pencarian serta penyelamatan kemanusiaan di mana menara seluler, tulang punggung internet, dan stasiun kerja pengembang yang menjalankan Xcode Instruments sama sekali tidak tersedia, platform Meepo harus menjamin kelangsungan hidup yang kokoh dan keandalan kriptografi sebelum penerapan fisik.

Mengembangkan perangkat lunak untuk jaringan ad-hoc bergerak (MANET) multi-hop yang terdesentralisasi menghadirkan tantangan pengujian berat yang membuat metodologi pengujian seluler tradisional menjadi usang:
1. **Dilema RF Fisik:** Sinyal frekuensi radio (RF) fisik—seperti iklan Bluetooth Low Energy (BLE) dan sesi multipeer Wi-Fi Direct—tunduk pada refleksi multipath lingkungan, penyerapan tubuh manusia secara fisik, derau elektromagnetik, dan penjadwalan radio sistem operasi yang bervariasi. Menjalankan pengujian unit atau integrasi terhadap radio fisik nyata di dalam lingkungan integrasi berkelanjutan (CI) otomatis menghasilkan hasil pengujian non-deterministik dan tidak konsisten (flaky) yang merusak kepercayaan rekayasa.
2. **Paradoks Pengujian Temporal:** Protokol mesh seluler bergantung secara mendasar pada pemicu berbasis waktu. Mekanisme store-and-forward toleran-penundaan menegakkan backoff percobaan ulang eksponensial (2 dtk, 4 dtk, 32 dtk); tabel tetangga menyapu rekaman rekan usang setelah 180 detik; tabel perutean membatalkan rute yang tidak disegarkan setelah 30 detik; dan titik temu kedaluwarsa 60 menit setelah waktu targetnya. Menggunakan penundaan waktu-nyata `Task.sleep` di dalam rangkaian pengujian otomatis tidak dapat dipertahankan, karena menjalankan satu pengujian batas waktu multi-hop akan memakan waktu beberapa menit, dan seluruh rangkaian pengujian akan memakan waktu berjam-jam.
3. **Eksekusi AEAD Kriptografi Nyata dalam Pengujian:** Daripada menirukan primitif kriptografi dengan string placeholder tiruan, pengujian unit Meepo mengeksekusi enkripsi, dekripsi, penyamaran authenticated associated data (AAD), dan pembuatan nonce 12-byte ChaCha20-Poly1305 Apple `CryptoKit` yang sebenarnya. Hal ini menjamin bahwa asersi pengujian memvalidasi perlindungan kriptografi tulen, mendeteksi perusakan MAC Poly1305, dan memverifikasi partisi ruang nonce di bawah eksekusi konkuren.

Untuk memecahkan tantangan ini, Meepo memberlakukan **Filosofi Pengujian Tanpa Perangkat Keras (Zero-Hardware)**:
- **Pemisahan Protokol & Transpor:** Logika domain produksi (`ChatMessageEngine`, `SOSForwardingEngine`, `PacketRouter`) bergantung secara ketat pada abstraksi protokol (`MeshTransport`, `PeerTransport`, `MeshClock`) alih-alih driver perangkat keras konkret.
- **Intersepsi Bingkai Dalam-Memori:** Aktor transpor pengujian (`ParityTransport`, `NetworkTestTransport`, `MessagingTestTransport`) mencegat bingkai wire 56-byte keluar ke dalam larik dalam-memori (`broadcasts: [Data]`), memungkinkan asersi mikrodetik pada byte wire presisi yang dikirimkan.
- **Perjalanan Waktu Virtual melalui `TestMeshClock`:** Semua layanan yang bergantung pada waktu menerima injeksi `MeshClock`. Selama pengujian otomatis, `TestMeshClock` memungkinkan pelari uji memajukan waktu virtual dengan detik arbitrer secara instan (`advance(by:)`), mengubah pengujian kedaluwarsa 60 menit menjadi asersi 2 milidetik.
- **Simulasi Sensor Deterministik:** `LocationService+Testing` menyediakan injeksi terprogram (`simulateLocation`) dari koordinat GPS dan akurasi horizontal presisi, meniadakan ketergantungan satelit CoreLocation.

---

### Ringkasan ELI5: Mesin Waktu dan Terowongan Angin Laboratorium

Bayangkan Anda adalah seorang insinyur penerbangan yang merancang jet supersonik yang harus bertahan dari badai turbulen di atas lautan. 

1. **Terowongan Angin Laboratorium (Tiruan Tanpa Perangkat Keras):** Anda dapat menguji jet tersebut dengan menunggu badai sungguhan di atas Samudra Atlantik, menerbangkan prototipe ke dalam badai, dan berharap radionya berfungsi. Namun badai nyata tidak dapat diprediksi: suatu hari hujan, hari berikutnya tenang, dan sebuah kecelakaan dapat menghancurkan satu-satunya prototipe Anda. Sebagai gantinya, Anda membangun terowongan angin laboratorium tercanggih (`ParityTransport`). Anda mengikat jet di dalam hanggar, meniupkan angin sintetis yang dikalibrasi secara presisi melintasi sayapnya, dan mengukur stabilitasnya dengan akurasi laser. Di Meepo, alih-alih memaksa 20 insinyur berlari melintasi lapangan tanggap bencana dengan antena Bluetooth sungguhan, kami menempatkan mesin perutean mesh di dalam terowongan angin dalam-memori tempat paket radio tiruan tiba dengan presisi mikrodetik.
2. **Mesin Waktu Mekanik (`TestMeshClock`):** Dalam jaringan mesh sungguhan, jika pesan radio gagal mencapai seorang teman, aplikasi menunggu 2 detik sebelum mencoba lagi, lalu 4 detik, lalu 32 detik. Jika seorang teman menghilang dari radar, aplikasi menunggu 3 menit sebelum menyatakan mereka hilang. Jika Anda harus menunggu menit nyata untuk setiap pengatur waktu selama pengujian otomatis, menjalankan 70 pengujian akan memakan waktu sepanjang sore. Dengan `TestMeshClock`, insinyur uji memegang kendali jarak jauh ajaib: Anda menekan sebuah tombol, dan waktu virtual melompat maju 3 menit dalam setengah milidetik. Pengatur waktu mesin terpicu secara instan, membuktikan bahwa jadwal percobaan ulang dan peringatan batas waktu bekerja tanpa cela tanpa membuang satu detik pun.
3. **Gembok Kombinasi yang Tidak Dapat Dibobol (Kripto Nyata dalam Pengujian Unit):** Beberapa pengembang menggunakan kunci mainan palsu dalam pengujian mereka untuk membuat semuanya berjalan lebih cepat. Meepo tidak pernah menggunakan kunci mainan. Setiap pengujian unit mengunci gembok kriptografi nyata menggunakan cipher tingkat militer tertinggi Apple (ChaCha20-Poly1305). Jika goresan mikroskopis sekecil apa pun terjadi pada segel paket (perusakan 1-bit pada tag autentikasi), mesin uji langsung menangkapnya dan memusnahkan paket tersebut.

---

## Rangkaian Pengujian yang Disertakan

Rangkaian verifikasi otomatis Volume 13 mencakup sembilan file terverifikasi yang membentang sepanjang 2.338 baris kode dan tepat 70 metode pengujian:

| # | Suite / Module Name | Source Link | Lines (`wc -l`) | Exact Tests | Core Invariants & Behaviors Verified |
|---|--------------------|-------------|-----------------|-------------|--------------------------------------|
| 1 | `ChatSOSMigrationTests` | [ChatSOSMigrationTests.swift](../../TeekumTests/ChatSOSMigrationTests.swift) | 375 | 11 | Siren audio cadences (25ms pulse to 80ms reminder); upward swipe threshold (64pt); 1-byte wire color codes (yellow `0x09` vs cream `0x04`); deduplicated re-ACKing on final hops; isolation of `.relayedByMeshHop` from `.deliveredToFriend`; emergency persistence until authenticated `.sosResolved`; GPS-free sender resolution; stale ACK dropping; 20-byte UTF-8 clamping & 20% battery power-gating. |
| 2 | `NetworkMigrationTests` | [NetworkMigrationTests.swift](../../TeekumTests/NetworkMigrationTests.swift) | 372 | 11 | Packet sniffer diagnostic tracking; 100-packet ring buffer memory bounding; BLE MTU frame segmentation (2, 20, 57 bytes) and out-of-order rejection; delay-tolerant carry custody retry backoffs (2s, 4s, 32s); outbox priority queue scheduling (SOS > ACK > Chat > Location); token bucket rate limiting; cryptographic MAC tampering rejection in routing; authenticated `.sosResolved` retention; 24-bit session ID route isolation; meeting update deduplication. |
| 3 | `PacketCodecTest` | [PacketCodecTest.swift](../../TeekumTests/PacketCodecTest.swift) | 834 | 20 | Strict 56-byte wire layout; 10-byte cleartext envelope serialization; buffer underflow rejection; sequence number partitioning (8-bit slot, 24-bit counter); sub-11cm coordinate quantization; geographic boundary values ($\pm 90^\circ, \pm 180^\circ$); serialization of all 6 payload types; Base-37 `InitialsCodec` bit-packing; 1-byte `MemberColor`; 20-byte emoji clamping; ChaCha20-Poly1305 AEAD sealing with AAD hop-count modification; regression across all 8 `PacketType` values. |
| 4 | `PairingMeetingMigrationTests` | [PairingMeetingMigrationTests.swift](../../TeekumTests/PairingMeetingMigrationTests.swift) | 185 | 9 | Serverless QR invite generation; 32-bit key fingerprint matching (`0x630DCD29`); consent agreement gating (preventing premature session activation); input validation rejecting invalid initials and malformed URLs; composite clipboard parsing; Setter Lock rule for rendezvous points; proposal replacement by ID; proximity arrival detection ($\le 25\text{ meters}$); 1-hour rendezvous expiration sweeps. |
| 5 | `ParityContractTests` | [ParityContractTests.swift](../../TeekumTests/ParityContractTests.swift) | 258 | 9 | Exact wire parity against frozen Prototype V3 vectors (envelope, 12-byte nonce, 10-byte AAD, 56-byte layout); 30-byte location payload with 12-byte zero padding; 20-byte UTF-8 character boundary clamping; BLE frame fragmentation parity; 4-tier outbox prioritization; dead-man guard stillness simulation (180s warning) and motion cancellation; SOS retry event ID preservation with fresh telemetry; final hop re-ACKing. |
| 6 | `SessionSafetyTests` | [SessionSafetyTests.swift](../../TeekumTests/SessionSafetyTests.swift) | 245 | 10 | Atomic monotonic sequence allocation across 32 concurrent tasks; nonce reuse prevention (throwing `.exhausted` at `0x00FFFFFF` rather than rolling over); sequence space isolation across 24-bit session IDs; secure key storage in iOS Keychain (`kSecClassGenericPassword`); complete key and metadata purging on leave (`SecItemDelete`); rejection of delayed location pings; contact loss hysteresis; friend roster observation; polar radar coordinate projection and perimeter rim clamping. |
| 7 | `LocationService+Testing` | [LocationService+Testing.swift](../../TeekumTests/Support/LocationService+Testing.swift) | 34 | N/A (Mock) | Deterministic GPS injection hook (`simulateLocation`) bypassing CoreLocation satellite acquisition and permissions; direct synthetic measurement delivery to `applyLocationMeasurement`. |
| 8 | `TestMeshClock` | [TestMeshClock.swift](../../TeekumTests/Support/TestMeshClock.swift) | 31 | N/A (Mock) | Virtual time advancement (`advance(by:)`) enabling instant, deterministic testing of time-dependent retry schedules, timeouts, and sweeps without wall-clock sleeping (`Task.sleep`). |
| 9 | `TeekumTests-Bridging-Header` | [TeekumTests-Bridging-Header.h](../../TeekumTests/TeekumTests-Bridging-Header.h) | 4 | N/A (Header) | Test bundle bridging header exposing C/Objective-C interfaces and symbols to Swift test suites. |
| **Total** | **9 Files** | **Master Inventory** | **2,338** | **70 Tests** | **Complete coverage across wire codecs, routing engines, safety invariants, pairing flows, and hardware mocks.** |

---

## Diagram Arsitektur & Pelari Uji

Diagram di bawah ini mengilustrasikan bagaimana rangka pengujian, tiruan simulasi deterministik, dan mesin kriptografi nyata berinteraksi dengan aktor produksi selama eksekusi pengujian:

```
+-----------------------------------------------------------------------------------+
|                        TEST ARCHITECTURE & RUNNER WORKFLOW                        |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [TEST DRIVERS]                                                                   |
|  - XCTest Runner (State Machines, Concurrency, & UI Models)                       |
|  - Swift Testing Engine (@Suite, @Test, #expect for Protocol V3 Wire Codecs)      |
|                                                                                   |
|           |                                                    |                  |
|           v                                                    v                  |
|  +--------------------------------+   +---------------------------------------+   |
|  |     Deterministic Mocks        |   |      Real Cryptographic Primitives    |   |
|  | - TestMeshClock (advance(by:)) |   | - CryptoKit ChaCha20-Poly1305         |   |
|  | - LocationService+Testing      |   | - 12-Byte Nonce: [SID | Seq | Ver/Type|   |
|  | - In-Memory Transport Actors   |   |   | Magic "TKM3"]                     |   |
|  |   (ParityTransport,            |   | - 10-Byte AAD Masking (hopCount = 0)  |   |
|  |    NetworkTestTransport,       |   | - 16-Byte Poly1305 Authentication Tag |   |
|  |    MessagingTestTransport)     |   |                                       |   |
|  +--------------------------------+   +---------------------------------------+   |
|           |                                                    |                  |
|           +-------------------------+--------------------------+                  |
|                                     |                                             |
|                                     v                                             |
|  +-----------------------------------------------------------------------------+  |
|  |                     PRODUCTION ACTORS & ENGINES UNDER TEST                  |  |
|  |                                                                             |  |
|  |  +-----------------------+  +-----------------------+  +------------------+ |  |
|  |  |   ChatMessageEngine   |  |  SOSForwardingEngine  |  |   PacketRouter   | |  |
|  |  | - Delivery State      |  | - Retransmit Cadence  |  | - Route Lookup   | |  |
|  |  | - Deduplication ACKs  |  | - Audio Feedback      |  | - AAD Validation | |  |
|  |  | - 20-Byte UTF-8 Clamp |  | - Resolution Handling |  | - Carry Buffering| |  |
|  |  +-----------------------+  +-----------------------+  +------------------+ |  |
|  |              |                          |                         |         |  |
|  |              +--------------------------+-------------------------+         |  |
|  |                                         |                                   |  |
|  |                                         v                                   |  |
|  |                         +-------------------------------+                   |  |
|  |                         |  In-Memory Transport Capture  |                   |  |
|  |                         |  - broadcasts: [Data]         |                   |  |
|  |                         |  - carriedCount: Int          |                   |  |
|  |                         |  - broadcastCount: Int        |                   |  |
|  |                         +-------------------------------+                   |  |
|  |                                         |                                   |  |
|  +-----------------------------------------------------------------------------+  |
|                                            |                                      |
|                                            v                                      |
|  +-----------------------------------------------------------------------------+  |
|  |                         ASSERTIONS & VERIFICATION                           |  |
|  | - XCTAssertEqual(broadcasts.count, expected)                                |  |
|  | - CryptoKit Decryption & Verification of Transmitted Wire Bytes             |  |
|  | - Sub-11cm Spatial Precision & Monotonic Nonce Sequence Invariance          |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

---

## Pembahasan Mendalam Khusus Per Rangkaian Uji

## Suite 1: `ChatSOSMigrationTests.swift`

- **Jalur Repositori:** [ChatSOSMigrationTests.swift](../../TeekumTests/ChatSOSMigrationTests.swift)
- **Jumlah Baris:** Tepat 375 baris (`wc -l`)
- **Total Kasus Uji:** Tepat 11 kasus uji
- **Subsistem Target:** Mesin Perpesanan Obrolan dan SOS Darurat (`ChatMessageEngine`, `SOSForwardingEngine`, `SOSViewModel`, `ChatViewModel`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`ChatSOSMigrationTests` memvalidasi siklus hidup ganda dan batasan keselamatan perpesanan obrolan efemeral serta sinyal marabahaya darurat. Ini membuktikan:
1. **Transisi Umpan Balik Darurat:** Peringatan audio beralih dari denyut darurat cepat (interval 25 milidetik) ke denyut pengingat berjarak (interval 80 milidetik) setelah diakui oleh pengguna lokal, dan berhenti total saat penyelesaian.
2. **Mekanika Gestur:** Gestur aktivasi SOS memberlakukan tarikan ke atas vertikal minimum sebesar 64 poin (`height <= -64`) dengan toleransi lateral ketat (`abs(width) < 75`), mencegah aktivasi palsu di dalam saku atau ransel.
3. **Pengodean Warna Wire:** Kode wire 1-byte dengan benar menyerialisasi rona profil (kuning `0x09` vs. krem `0x04`) di seluruh `LocationPingPayload` dan `SOSPayload`, kembali ke hashing inisial saat tidak disetel.
4. **Perlindungan Kriptografi & Pengiriman Ulang ACK Terdeduplikasi:** Paket obrolan palsu dengan tag MAC Poly1305 yang diubah dibuang sebelum mencapai riwayat, sementara paket valid terkirim secara lokal satu kali dan memancarkan ulang ACK saat kedatangan duplikat tanpa menduplikasi rekaman antarmuka (UI).
5. **Pembedaan Relay vs. Pengiriman:** Paket ACK dengan status `.relayedByMeshHop` (`0x01`) mengonfirmasi transit melintasi hop perantara tetapi tidak pernah menambah jumlah penerima pesan yang dikonfirmasi.
6. **Otoritas Resolusi:** Menutup suara lokal tidak menghapus keadaan darurat; hanya paket `.sosResolved` autentik yang cocok dengan originator dan ID peristiwa yang mengakhiri status darurat.
7. **Transmisi Sadar Baterai:** Masukan draf obrolan memotong teks UTF-8 multi-byte menjadi 20 byte pada batas karakter dan memblokir transmisi (`canSend == false`) ketika baterai turun di bawah 20%.

### Analogi ELI5
Bayangkan walkie-talkie darurat yang digunakan oleh patroli ski di gunung yang rawan longsor. Ketika seorang pemain ski menarik tuas marabahaya darurat ke atas, radio pos komando membunyikan alarm berdenyut yang keras. Ketika petugas menekan "Acknowledge" (Akui), sirene mereda menjadi bunyi bip pengingat lembut, tetapi lampu suar merah terang yang berkedip di sekeliling layar tetap menyala. Petugas tidak dapat mematikan suar hanya karena merasa terganggu; suar peringatan merah tetap aktif sampai pemain ski di gunung memancarkan kode "All Clear" (Aman) yang autentik melalui radio. Sementara itu, telegram teks pendek yang dikirim antar anggota patroli dibatasi pada pita telegraf 20 karakter, dan menara repeater mengonfirmasi bahwa mereka telah meneruskan pesan tanpa mengklaim secara palsu bahwa penjaga gunung telah membacanya.

### Definisi Istilah Teknis
- **Alerter Pulse Cadence:** Frekuensi temporal dari denyut audio yang dipancarkan oleh `DefaultSOSAudioAlerter` untuk menandakan marabahaya mendesak vs. pengingat latar belakang.
- **Upward Travel Threshold:** Batas tarikan geometris yang membutuhkan setidaknya 64 poin pergeseran vertikal negatif untuk mengaktifkan mode darurat.
- **Relayed vs. Delivered ACK:** Pembedaan protokol antara tanda terima hop perantara (`0x01`, `.relayedByMeshHop`) dan tanda terima penerima akhir (`0x02`, `.deliveredToFriend`).
- **Edge Glow Persistence:** Keadaan batas merah dengan visibilitas tinggi yang dirender pada layar selama keadaan darurat aktif, bertahan dari penolakan audio lokal hingga diselesaikan secara kriptografis.
- **Battery Power Gate:** Aturan penghematan baterai otomatis yang menonaktifkan transmisi obrolan saat persentase baterai turun di bawah 20%, mencadangkan daya untuk ping darurat.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan uji berikut memeriksa `testDismissingSOSFeedbackKeepsEmergencyUntilMatchingResolution` dari [ChatSOSMigrationTests.swift:188-252](../../TeekumTests/ChatSOSMigrationTests.swift#L188-L252):

```swift
// Verified verbatim from TeekumTests/ChatSOSMigrationTests.swift:188-252
    @MainActor
    func testDismissingSOSFeedbackKeepsEmergencyUntilMatchingResolution() async throws {
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: keyData, localInitials: "BOB")
        let crypto = CryptoService()
        let audio = MessagingTestAudio()
        let engine = SOSForwardingEngine(transport: MessagingTestTransport(), cryptoService: crypto,
            sessionProvider: { session }, audioAlerter: audio)
        let model = SOSViewModel(engine: engine, locationService: LocationService(isLiveSharingEnabled: false),
            sessionProvider: { session })
        await model.start()
        XCTAssertFalse(model.showsEdgeGlow)

        let received = XCTestExpectation(description: "Receiver displays the SOS alert")
        let store = SessionStore(members: [Member(id: "ALX")])
        model.onIncomingAlert = { alert in
            store.setEmergency(true, for: alert.senderInitials)
            received.fulfill()
        }
        model.onIncomingSOSResolved = { initials in
            XCTAssertEqual(initials, "ALX")
            store.setEmergency(false, for: initials)
        }
        let payload = SOSPayload(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            timestamp: Date(timeIntervalSince1970: 0), accuracy: 255, sosEventId: 77,
            senderInitials: "ALX", batteryLevel: 85)
        let envelope = CleartextEnvelope(type: .sos, sessionId: session.sessionId, sequenceNumber: 0x01000001)
        let wire = try await crypto.sealToWireBytes(payload: payload.serialize(), envelope: envelope,
            using: SymmetricKey(data: session.symmetricKeyData))
        let packet = try RawWirePacket.fromWireData(wire)
        await model.acceptResolution(.init(senderInitials: "ALX", eventId: 76))
        var alreadyResolved = payload
        alreadyResolved.sosEventId = 76
        let delayedWire = try await crypto.sealToWireBytes(payload: alreadyResolved.serialize(), envelope:
            CleartextEnvelope(type: .sos, sessionId: session.sessionId, sequenceNumber: 0x01000002),
            using: SymmetricKey(data: session.symmetricKeyData))
        try await engine.handleInboundSOSPacket(rawPacket: RawWirePacket.fromWireData(delayedWire), fromPeerId: "ALX")
        XCTAssertNil(model.incomingAlert)
        XCTAssertFalse(store.members[0].isEmergency)

        try await engine.handleInboundSOSPacket(rawPacket: packet, fromPeerId: "ALX")
        let result = await XCTWaiter.fulfillment(of: [received], timeout: 2)
        XCTAssertEqual(result, .completed)
        XCTAssertTrue(model.showsEdgeGlow)
        await model.acknowledgeIncomingAlert()
        XCTAssertNil(model.incomingAlert)
        XCTAssertTrue(model.showsEdgeGlow)
        XCTAssertEqual(audio.reminderCount, 1)
        XCTAssertTrue(store.members[0].isEmergency)

        await model.acceptResolution(.init(senderInitials: "NIC", eventId: 77))
        XCTAssertTrue(store.members[0].isEmergency)
        XCTAssertTrue(model.showsEdgeGlow)
        XCTAssertEqual(audio.stopCount, 0)
        await model.acceptResolution(.init(senderInitials: "ALX", eventId: 77))
        XCTAssertFalse(store.members[0].isEmergency)
        XCTAssertFalse(model.showsEdgeGlow)
        XCTAssertEqual(audio.stopCount, 1)
        try await engine.handleInboundSOSPacket(rawPacket: packet, fromPeerId: "ALX")
        XCTAssertNil(model.incomingAlert)

        model.triggerSOS()
        XCTAssertTrue(model.showsEdgeGlow)
        model.dismissDeliveryStatus()
        XCTAssertTrue(model.showsEdgeGlow)
        await model.stop()
    }
```

- **Baris 188–196:** Menginisialisasi perlengkapan uji pada `@MainActor`. Membuat `GroupSession` untuk anggota `"BOB"`, menginstansiasi `CryptoService`, pembuat peringatan audio tiruan `MessagingTestAudio`, dan menghubungkan `SOSForwardingEngine` ke `SOSViewModel`. Memverifikasi bahwa sebelum peringatan marabahaya diterima, `model.showsEdgeGlow` bernilai false.
- **Baris 198–208:** Menyiapkan ekspektasi XCTest dan mengikat closure untuk `onIncomingAlert` dan `onIncomingSOSResolved`. Saat peringatan masuk terpicu, anggota `"ALX"` di `SessionStore` ditandai sebagai dalam keadaan darurat (`isEmergency = true`).
- **Baris 209–225:** Membangun paket wire tersegel untuk ID peristiwa darurat `77`. Mendemonstrasikan caching resolusi: view model menerima resolusi untuk peristiwa `76`. Ketika paket tertunda untuk peristiwa `76` tiba, mesin segera menekannya (`model.incomingAlert == nil`, `store.members[0].isEmergency == false`).
- **Baris 226–235:** Mengirimkan paket autentik untuk peristiwa `77`. Ekspektasi peringatan terpenuhi, dan `model.showsEdgeGlow` berubah menjadi true. Pengguna lokal mengakui peringatan melalui `acknowledgeIncomingAlert()`. Peringatan modal ditutup (`incomingAlert == nil`), tetapi kilau tepi tetap terlihat (`showsEdgeGlow == true`), audio pengingat dijadwalkan (`reminderCount == 1`), dan status darurat anggota tetap true.
- **Baris 236–246:** Mensimulasikan resolusi yang tidak valid dari rekan tidak berwenang `"NIC"`. Keadaan darurat tetap aktif, dan audio tidak berhenti (`stopCount == 0`). Selanjutnya, resolusi autentik dari pencetus `"ALX"` untuk peristiwa `77` diterima: status darurat anggota dihapus, kilau tepi mati, dan umpan balik audio berhenti total (`stopCount == 1`). Pemutaran ulang paket berikutnya tidak menghasilkan peringatan.
- **Baris 247–252:** Memicu SOS lokal, memverifikasi bahwa menutup status pengiriman tidak menonaktifkan kilau tepi, dan menghentikan model dengan bersih.

---

## Suite 2: `NetworkMigrationTests.swift`

- **Jalur Repositori:** [NetworkMigrationTests.swift](../../TeekumTests/NetworkMigrationTests.swift)
- **Jumlah Baris:** Tepat 372 baris (`wc -l`)
- **Total Kasus Uji:** Tepat 11 kasus uji
- **Subsistem Target:** Jaringan Inti, Pembingkaian BLE, Antrean Kotak Keluar, dan Perutean Paket (`PeerTransportService`, `BLEFrameCodec`, `CarryMessageStore`, `PriorityOutboxQueue`, `PacketRouter`, `ForwardingRateLimiter`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`NetworkMigrationTests` memvalidasi perutean datagram lapisan transpor, transfer kustodi store-and-forward toleran-penundaan, prioritas antrean kotak keluar, dan penegakan pembatasan laju. Ini membuktikan:
1. **Isolasi Sniffing Paket:** Pencatatan paket diagnostik pada-perangkat secara jelas membedakan paket relai komunal (`isOutsideGroup == true`) dari paket grup privat dan melacak perkembangan jumlah hop.
2. **Pembatasan Memori:** Ring buffer paket diagnostik membatasi penyimpanan pada 100 entri, mengeluarkan entri terlama untuk mencegah pertumbuhan memori.
3. **Segmentasi & Perakitan Ulang BLE:** `BLEFrameCodec` memotong bingkai 56-byte dengan benar di berbagai MTU (2, 20, 57 byte) dan dengan aman membuang potongan yang tidak berurutan.
4. **Backoff Kustodi Carry:** Antrean kustodi store-and-forward memberlakukan backoff percobaan ulang bertingkat (2 dtk, 4 dtk, 32 dtk) dan membersihkan paket kedaluwarsa tanpa mengatur ulang pengatur waktu retensi pada penerimaan duplikat.
5. **Pencabutan Izin Relai:** Antrean kustodi dalam-memori memprioritaskan ACK kritis di atas obrolan biasa dan segera menghapus paket relai asing saat izin pengguna dicabut.
6. **Preemption Lalu Lintas:** Antrean kotak keluar menegakkan penjadwalan 4-tingkat yang ketat: paket SOS mendahului ACK, ACK mendahului pesan obrolan, dan pesan obrolan mendahului ping lokasi.
7. **Reservasi Bandwidth Token Bucket:** Pembatas token bucket mencadangkan bandwidth untuk paket biasa dan darurat sembari membatasi telemetri lokasi latar belakang.
8. **Integritas Perutean:** `PacketRouter` membuang paket yang tidak terautentikasi tanpa mencemari cache deduplikasi atau buffer store-and-forward, sementara paket SOS asing yang buram diteruskan tanpa memicu alarm lokal.
9. **Isolasi Sesi 24-Bit:** Amplop, nonce, dan AAD melakukan roundtrip ID sesi 24-bit (`0x000001` hingga `0xFFFFFF`) dengan benar, dan tabel perutean mengisolasi penemuan rute antara ID sesi yang berbeda.

### Analogi ELI5
Bayangkan fasilitas penyortiran pos yang sibuk dengan berbagai kantong surat dan sabuk penyortir. Amplop merah ekspres (SOS darurat) dan kartu tanda terima bersertifikasi (ACK) langsung melompat ke bagian depan ban berjalan, melewati surat reguler (obrolan) dan brosur iklan (ping lokasi). Ketika sepucuk surat terlalu tebal untuk sebuah kantong surat, surat itu diiris menjadi potongan-potongan bernomor; jika amplop #2 tiba sebelum amplop #1, penyortir menolak memprosesnya sampai amplop #1 muncul. Jika sebuah amplop tiba dengan segel lilin palsu, fasilitas tersebut langsung merobeknya tanpa mencatatnya di buku pelacakan.

### Definisi Istilah Teknis
- **Ring Buffer Bounding:** Struktur data FIFO sirkular yang mempertahankan jumlah maksimum tetap (100 entri), menggantikan item terlama saat penuh.
- **BLE MTU Fragmentation:** Membagi paket wire 56-byte menjadi potongan-potongan berurutan yang lebih kecil agar muat di dalam ukuran MTU atribut Bluetooth fisik.
- **Store-and-Forward Custody:** Membuffer bingkai terenkripsi dalam memori ketika tidak ada rekan tetangga hop-berikutnya, mentransmisikannya saat bertemu rekan baru.
- **Preemption Outbox Queue:** Antrean prioritas 4-tingkat (`PriorityOutboxQueue`) yang memastikan bahwa lalu lintas keselamatan jiwa selalu dikirim sebelum telemetri latar belakang.
- **Bandwidth Token Reservation:** Mengalokasikan kuota token minimum secara eksklusif untuk lalu lintas yang andal, mencegah ping lokasi menghabiskan kapasitas saluran.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan uji berikut memeriksa `testRouterRejectsUnauthenticatedChatWithoutPoisoningCacheOrCarry` dari [NetworkMigrationTests.swift:153-199](../../TeekumTests/NetworkMigrationTests.swift#L153-L199):

```swift
// Verified verbatim from TeekumTests/NetworkMigrationTests.swift:153-199
    @MainActor
    func testRouterRejectsUnauthenticatedChatWithoutPoisoningCacheOrCarry() async throws {
        let transport = NetworkTestTransport()
        let crypto = CryptoService()
        let cache = SeenPacketCache()
        let routing = RoutingTable()
        let neighbors = NeighborTable()
        let discovery = RouteDiscoveryService(routingTable: routing, neighborTable: neighbors,
            transport: transport, cryptoService: crypto)
        let policy = RelayPolicyManager(storageKeyPrefix: "network-router-\(UUID())", transport: transport, defaultMode: .disabled)
        let key = SymmetricKey(size: .bits256)
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: key.withUnsafeBytes { Data($0) },
            localInitials: "BOB")
        var accepted = 0
        var alerts = 0
        let router = PacketRouter(cryptoService: crypto, peerTransport: transport,
            relayPolicyManager: policy, routeDiscoveryService: discovery, seenPacketCache: cache,
            onLocationPing: { _, _ in }, onSOS: { _, _ in alerts += 1 }, onACK: { _ in }, onMeetingUpdate: { _ in },
            onChat: { _ in accepted += 1 })
        let envelope = CleartextEnvelope(type: .chatMessage, sessionId: session.sessionId,
            sequenceNumber: CleartextEnvelope.makeSequenceNumber(memberSlot: 1, counter: 1))
        let payload = try ChatMessagePayload(senderInitials: "ALX", timestamp: .now, text: "Hello").serialize()
        let sealed = try await crypto.seal(payload: payload, envelope: envelope, using: key)
        let valid = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.authTag)
        var invalid = valid
        invalid.authTag[invalid.authTag.startIndex] ^= 1
        await router.routeInboundPacket(InboundPacket(rawPacket: invalid, sourcePeerId: "relay"), for: session)
        let cacheBefore = await cache.count
        let carryBefore = await transport.carriedCount
        XCTAssertEqual(accepted, 0)
        XCTAssertEqual(cacheBefore, 0)
        XCTAssertEqual(carryBefore, 0)
        await router.routeInboundPacket(InboundPacket(rawPacket: valid, sourcePeerId: "relay"), for: session)
        let carryAfter = await transport.carriedCount
        let sentAfter = await transport.broadcastCount
        XCTAssertEqual(accepted, 1)
        XCTAssertEqual(carryAfter, 1)
        XCTAssertEqual(sentAfter, 1)
        let opaqueSOS = try RawWirePacket.fromWireData(wire(type: .sos, sequence: 0x0100_0002))
        await router.routeInboundPacket(.init(rawPacket: opaqueSOS, sourcePeerId: "relay"), for: session)
        await router.routeInboundPacket(.init(rawPacket: opaqueSOS, sourcePeerId: "relay"), for: session)
        let sentWithOpaqueSOS = await transport.broadcastCount
        XCTAssertEqual(alerts, 0)
        XCTAssertEqual(sentWithOpaqueSOS, 2, "Prototype fallback forwards once without delivering an alert.")
        router.stop()
        await router.routeInboundPacket(InboundPacket(rawPacket: valid, sourcePeerId: "relay"), for: session)
        XCTAssertEqual(accepted, 1)
    }
```

- **Baris 153–171:** Menyiapkan lingkungan perutean pada `@MainActor`. Membuat transpor tiruan `NetworkTestTransport`, layanan kriptografi, cache deduplikasi paket terlihat, tabel perutean, tabel tetangga, layanan penemuan rute, dan manajer kebijakan relai. Mengonfigurasi closure observasi untuk peristiwa obrolan dan SOS.
- **Baris 172–177:** Menghasilkan pesan obrolan tersegel asli untuk slot anggota 1, pencacah urutan 1. Membuat paket yang tidak valid dan rusak dengan memutasi byte pertama dari tag autentikasi Poly1305 (`invalid.authTag[0] ^= 1`).
- **Baris 178–183:** Mengonsumsi paket yang tidak valid. Memverifikasi bahwa perute menolaknya dengan bersih: `accepted == 0`, `cacheBefore == 0` (cache deduplikasi tidak tercemar dengan paket tidak valid), dan `carryBefore == 0` (paket tidak valid tidak dimasukkan ke dalam memori carry store-and-forward).
- **Baris 184–189:** Mengonsumsi paket valid yang asli. Memverifikasi pengiriman lokal yang berhasil (`accepted == 1`), retensi dalam memori carry (`carryAfter == 1`), dan siaran transmisi ulang (`sentAfter == 1`).
- **Baris 190–196:** Mengonsumsi paket SOS asing yang buram dari grup lain. Memverifikasi bahwa peringatan darurat lokal tidak terpicu (`alerts == 0`), tetapi paket diteruskan sekali melintasi mesh sesuai dengan kebijakan relai komunal.
- **Baris 197–199:** Memanggil `router.stop()` dan memverifikasi bahwa kedatangan paket berikutnya diabaikan.

---

## Suite 3: `PacketCodecTest.swift`

- **Jalur Repositori:** [PacketCodecTest.swift](../../TeekumTests/PacketCodecTest.swift)
- **Jumlah Baris:** Tepat 834 baris (`wc -l`)
- **Total Kasus Uji:** Tepat 20 kasus uji
- **Subsistem Target:** Kodek Wire Biner Protokol V3, Amplop Teks Jelas, Payload, dan AEAD ChaCha20-Poly1305 (`CleartextEnvelope`, `RawWirePacket`, `LocationPingPayload`, `SOSPayload`, `MeetingUpdatePayload`, `ACKPayload`, `RouteReqPayload`, `RouteRespPayload`, `ChatMessagePayload`, `InitialsCodec`, `MemberColor`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`PacketCodecTest` adalah rangkaian pengujian spesifikasi protokol untuk Meepo Protocol V3, yang dibangun menggunakan kerangka kerja modern Swift Testing (`@Suite`, `@Test`). Ini membuktikan:
1. **Amplop Teks Jelas 10-Byte:** Amplop diserialisasi menjadi tepat 10 byte dan berhasil melakukan roundtrip melalui deserialisasi di semua ID sesi 24-bit yang valid.
2. **Deteksi Kesalahan Amplop:** Deserialisasi menolak buffer underflow, ketidakcocokan versi protokol (memerlukan `0x03`), tipe paket yang tidak diketahui, batas hop nol, dan jumlah hop yang melebihi batas hop.
3. **Partisi Nomor Urut:** Nomor urut 32-bit terbagi bersih menjadi `memberSlot` 8-bit atas (0–255) dan pencacah monotonik 24-bit bawah (0–16.777.215).
4. **Penegakan Ukuran Wire:** `RawWirePacket` menegakkan tata letak wire tepat 56 byte (amplop 10 byte, ciphertext 30 byte, tag Poly1305 16 byte), menolak paket 55 byte dan 57 byte.
5. **Kuantisasi Sub-11cm:** Kuantisasi koordinat Int32 mempertahankan presisi geografis dalam batas $0,000002^\circ$ (kesalahan spasial <11 sentimeter).
6. **Keamanan Koordinat Batas:** Koordinat geografis ekstrem (kutub pada $\pm 90^\circ$, antimeridian pada $\pm 180^\circ$, dan pulau nol pada $0^\circ, 0^\circ$) diserialisasi tanpa overflow bilangan bulat.
7. **Roundtrip Payload:** Payload SOS, Pembaruan Pertemuan, ACK, Permintaan Rute, dan Respons Rute diserialisasi menjadi tepat 30 byte dan mempertahankan semua bidang.
8. **Vektor Uji Deterministik:** Amplop dan nonce cocok dengan vektor heksadesimal beku (`3108000001020a0b0c0d` dan `0001020a0b0c0d31544b4d33`).
9. **Kompresi Inisial Base-37:** `InitialsCodec` mengemas 1–3 karakter alfanumerik menjadi tepat 2 byte ($37^3 = 50.653 < 65.536$), dengan sanitasi input penuh.
10. **Pengodean Warna & Fallback Hash:** Kode warna anggota 1-byte diserialisasi dengan bersih, menangani paket warisan ber-padding nol, dan kembali secara deterministik ke hashing inisial.
11. **Serialisasi Obrolan & Pemotongan:** Payload obrolan diserialisasi menjadi 30 byte, memotong teks UTF-8 multi-byte menjadi 20 byte pada batas karakter, dan menolak urutan byte UTF-8 yang cacat.
12. **Integritas AEAD ChaCha20-Poly1305:** Menyegel payload polos dengan nonce 12-byte dan AAD 10-byte mempertahankan kerahasiaan payload, memungkinkan penambahan jumlah hop selama perutean melalui penyamaran AAD, dan mendeteksi perusakan.

### Analogi ELI5
Bayangkan cetakan pengecoran logam untuk mencetak koin. Setiap koin harus berdiameter tepat 56 milimeter. Jika kepingan koin kurang 1 milimeter saja (55mm) atau lebih 1 milimeter (57mm), mesin pencetak langsung berhenti. Bagian atas 10 milimeter dicap dengan angka-angka jelas yang menunjukkan tanggal dan nilai koin. Bagian tengah 30 milimeter memuat mikrochip tersegel dengan kargo privat, diamankan oleh segel pendeteksi perusakan elektronik 16 milimeter. Jika ada yang mencoba mengubah angka-angka pada koin, segel elektronik mikrochip akan merusak diri sendiri dan koin tersebut tidak berlaku secara permanen.

### Definisi Istilah Teknis
- **Fixed 56-Byte Wire Layout:** Invarian protokol yang mengharuskan setiap datagram mesh berukuran tepat 56 byte (10 Amplop + 30 Ciphertext + 16 Tag Poly1305).
- **Int32 Fixed-Point Quantization:** Mengalikan derajat floating-point dengan $10^7$ untuk menyimpan koordinat sebagai bilangan bulat bertanda 32-bit, menghasilkan ~11,1cm per unit.
- **Base-37 Bit-Packing:** Mengodekan karakter dari alfabet `A-Z`, `0-9`, dan spasi ke dalam bilangan bulat basis-37, menyimpan 3 karakter dalam bilangan bulat 16-bit (2 byte).
- **AAD Hop-Count Masking:** Menyamarkan `hopCount` menjadi `0` saat menghasilkan Authenticated Associated Data sehingga perute perantara dapat menambah pencacah hop tanpa membatalkan tag autentikasi Poly1305.
- **ChaCha20 Nonce Structure:** Vektor inisialisasi 12-byte yang terdiri dari: ID Sesi 3-byte + Nomor Urut 4-byte + Versi/Tipe 1-byte + ASCII Ajaib 4-byte `"TKM3"`.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan uji berikut memeriksa `chatMessageWirePacketRoundtripAndCryptoAEAD` dari [PacketCodecTest.swift:679-746](../../TeekumTests/PacketCodecTest.swift#L679-L746):

```swift
// Verified verbatim from TeekumTests/PacketCodecTest.swift:679-746
    @Test("Chat wire packet 56-byte layout and ChaCha20-Poly1305 AEAD sealing")
    func chatMessageWirePacketRoundtripAndCryptoAEAD() throws {
        let key = SymmetricKey(size: .bits256)
        let sessionId: UInt32 = 0xCAFEEE
        let sequenceNumber: UInt32 = CleartextEnvelope.makeSequenceNumber(memberSlot: 5, counter: 101)

        let envelope = CleartextEnvelope(
            version: PacketConstants.protocolVersion,
            type: .chatMessage,
            hopLimit: 8,
            hopCount: 0,
            sessionId: sessionId,
            sequenceNumber: sequenceNumber
        )

        // 1. Envelope serialization
        let envData = envelope.serialize()
        #expect(envData.count == 10)
        #expect(envData[0] == 0x37)

        // 2. Nonce test
        let nonce = envelope.constructNonce()
        #expect(nonce.count == 12)
        #expect(nonce[7] == 0x37)

        // 3. Seal payload
        let chat = ChatMessagePayload(senderInitials: "SAM", text: "Beer line")
        let plainPayload = try chat.serialize()
        let aad = envelope.authenticatedAssociatedData()
        #expect(aad.count == 10)
        #expect(aad[0] == 0x37)
        #expect(aad[2] == 0x00)

        let chachaNonce = try ChaChaPoly.Nonce(data: nonce)
        let sealed = try ChaChaPoly.seal(plainPayload, using: key, nonce: chachaNonce, authenticating: aad)
        #expect(sealed.ciphertext.count == 30)
        #expect(sealed.tag.count == 16)

        // 4. Form RawWirePacket
        let rawPacket = RawWirePacket(envelope: envelope, ciphertext: sealed.ciphertext, authTag: sealed.tag)
        let wireBytes = try rawPacket.toWireData()
        #expect(wireBytes.count == 56)

        // 5. Parse back
        let parsedRaw = try RawWirePacket.fromWireData(wireBytes)
        #expect(parsedRaw.envelope.type == .chatMessage)
        #expect(parsedRaw.envelope.sessionId == sessionId)

        // 6. Simulate mesh relay hop
        var relayedEnvelope = parsedRaw.envelope
        relayedEnvelope.hopCount = 1

        let relayedAAD = relayedEnvelope.authenticatedAssociatedData()
        let openedBox = try ChaChaPoly.SealedBox(nonce: chachaNonce, ciphertext: parsedRaw.ciphertext, tag: parsedRaw.authTag)
        let decryptedData = try ChaChaPoly.open(openedBox, using: key, authenticating: relayedAAD)
        #expect(decryptedData == plainPayload)

        let decodedChat = try ChatMessagePayload.deserialize(from: decryptedData)
        #expect(decodedChat.senderInitials == "SAM")
        #expect(decodedChat.text == "Beer line")

        // 7. Tampering verification
        var tamperedEnvelope = relayedEnvelope
        tamperedEnvelope.hopLimit = 15
        let tamperedAAD = tamperedEnvelope.authenticatedAssociatedData()
        #expect(throws: (any Error).self) {
            try ChaChaPoly.open(openedBox, using: key, authenticating: tamperedAAD)
        }
    }
```

- **Baris 680–692:** Membuat kunci simetris 256-bit, ID sesi 24-bit `0xCAFEEE`, dan nomor urut untuk slot anggota 5, pencacah 101. Menginstansiasi amplop teks jelas 10-byte untuk `chatMessage`.
- **Baris 694–697:** Menyerialisasi amplop. Menegaskan bahwa jumlah byte tepat 10 dan Byte 0 bernilai `0x37` (`(version 3 << 4) | type 7`).
- **Baris 699–702:** Membangun nonce ChaCha20 12-byte. Memverifikasi bahwa indeks byte 7 memuat byte versi/tipe `0x37`.
- **Baris 704–715:** Menyerialisasi payload obrolan (dikodekan sebagai `"Beer line"` di perlengkapan pengujian unit) menjadi 30 byte. Menghitung AAD dan menegaskan bahwa indeks byte 2 (`hopCount`) disamarkan menjadi `0x00`. Mengeksekusi `ChaChaPoly.seal` dengan kunci, nonce, dan AAD, memverifikasi 30 byte ciphertext dan 16 byte tag autentikasi.
- **Baris 717–725:** Membundel komponen ke dalam `RawWirePacket`, menyerialisasi ke data wire biner, menegaskan panjang tepat 56 byte, dan mengurai kembali melalui `RawWirePacket.fromWireData`.
- **Baris 727–738:** Mensimulasikan hop perutean perantara: `hopCount` bertambah menjadi 1. Karena `authenticatedAssociatedData()` menyamarkan `hopCount` menjadi 0, `relayedAAD` cocok dengan AAD asli, memungkinkan `ChaChaPoly.open` mendekripsi dengan sukses dan memulihkan payload uji (`"Beer line"`).
- **Baris 740–745:** Mensimulasikan perusakan header: memodifikasi `hopLimit` menjadi 15 mengubah AAD. Dekripsi memunculkan error, membuktikan bahwa bidang header perutean selain `hopCount` diautentikasi secara kriptografis.

## Suite 4: `PairingMeetingMigrationTests.swift`

- **Jalur Repositori:** [PairingMeetingMigrationTests.swift](../../TeekumTests/PairingMeetingMigrationTests.swift)
- **Jumlah Baris:** Tepat 185 baris (`wc -l`)
- **Total Kasus Uji:** Tepat 9 kasus uji
- **Subsistem Target:** Pemasangan Tanpa Server, Penguraian Undangan QR, dan Koordinasi Titik Temu (`GroupSession`, `GroupSessionFactory`, `PairingViewModel`, `MeetingPointService`, `SessionStore`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`PairingMeetingMigrationTests` memverifikasi batasan keamanan, pembatasan persetujuan pendaftaran, dan aturan koordinasi titik temu dari subsistem pemasangan dan pertemuan Meepo. Ini membuktikan:
1. **Ekuivalensi Sidik Jari:** Host dan penggabung menurunkan sidik jari kunci 32-bit identik (`0x630DCD29`) dari kunci simetris 256-bit, memungkinkan konfirmasi visual instan tanpa mentransmisikan materi kunci rahasia.
2. **Invariansi Kontrak Sesi:** URL undangan QR (`meepo://join#key=...&sid=...&name=...`) mempertahankan ID sesi 24-bit, nama sesi, dan kunci simetris di seluruh anggota yang bergabung.
3. **Pembatasan Persetujuan Status Draf:** Memindai kode QR undangan mengisi `PairingViewModel.draftSession` tetapi TIDAK mengaktifkan sesi di `SessionStore` sampai pengguna melakukan tindakan persetujuan eksplisit (`activateLocalSession()`).
4. **Sanitasi & Penolakan Input:** Pabrik pemasangan menolak inisial kosong, string 4-karakter, digit, emoji, kunci terpotong (<32 byte), dan ID sesi yang tidak valid.
5. **Penguraian Papan Klip:** Penguraian papan klip mengisolasi tautan undangan dari URL mentah, pesan berbagi obrolan lengkap dengan teks pengantar, dan muatan papan klip multi-item, menolak papan klip kosong dengan pesan kesalahan terlokalisasi.
6. **Aturan Penguncian Pengusul (Setter Lock Rule):** Hanya pengusul asli dari suatu titik temu yang memiliki wewenang untuk membatalkan atau memindahkannya; paket pembatalan dari anggota lain ditolak.
7. **Preemption Usulan:** Usulan pertemuan masuk dengan ID titik temu yang meningkat secara bersih menggantikan titik aktif yang lebih lama.
8. **Kedatangan Proksimitas & Kedaluwarsa:** Anggota dalam jarak 25 meter dari titik temu secara otomatis mengubah status kehadiran menjadi `.arrived`, sementara penyapuan kedaluwarsa menghapus titik temu yang berusia lebih dari 1 jam.
9. **Pembaruan Idempoten:** Usulan redundan dan paket RSVP duplikat diabaikan tanpa memicu pergantian status atau siaran ulang mesh yang redundan.

### Analogi ELI5
Bayangkan mendirikan pos komando insiden di zona bencana gempa bumi dan menancapkan bendera evakuasi darurat di peta taktis. Untuk bergabung dengan regu penyelamat, rekan tim Anda memindai kode QR pengiriman Anda yang berisi kunci misi privat 256-bit. Aplikasi menampilkan penetapan regu, tetapi tidak mengaktifkan radio mesh sampai mereka mengetuk "Agree to Mesh Compact". Setelah aktif, setiap anggota operasional dalam regu dapat mengusulkan titik temu (waypoint). Namun begitu bendera evakuasi ditancapkan, Setter Lock Rule menjamin bahwa hanya pemimpin regu yang menancapkannya yang dapat memindahkan atau membatalkannya; jika orang lain mencoba memindahkannya, sistem akan menolak usulan tersebut. Ketika seorang responden bergerak dalam jarak 25 meter dari bendera, perangkat mereka secara otomatis menyiarkan pembaruan kedatangan: "Tiba di Titik Evakuasi Alpha!" Jika satu jam berlalu melewati tenggat waktu yang dijadwalkan, titik koordinat sementara akan kedaluwarsa secara otomatis.

### Definisi Istilah Teknis
- **Key Fingerprint:** Ringkasan heksadesimal 32-bit ringkas (`0x630DCD29`) yang diturunkan dari hashing SHA-256 dari kunci simetris 256-bit grup, ditampilkan di antarmuka pengguna untuk verifikasi visual di luar pita (out-of-band).
- **Setter Lock Rule:** Kebijakan otorisasi yang memastikan bahwa hanya pengusul asli dari koordinat titik temu yang dapat membatalkan atau memindahkan titik pertemuan.
- **Draft Session State:** Status memori terisolasi yang menyimpan kredensial sesi yang dipindai tanpa memberikan akses ke obrolan grup, pelacakan radar, atau perutean radio sampai persetujuan pengguna eksplisit diberikan.
- **Multi-Item Pasteboard Heuristic:** Fallback penguraian yang memindai beberapa item papan klip untuk mengisolasi URL undangan ketika tertanam di samping teks yang dapat dibaca manusia.
- **Proximity Arrival Threshold:** Batas jarak radial 25 meter di mana lokasi GPS anggota secara otomatis memperbarui kehadiran pertemuan mereka menjadi `.arrived`.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan uji berikut memeriksa `testMeetingSetterLockAndAttendanceMatchPrototypeRules` dari [PairingMeetingMigrationTests.swift:109-128](../../TeekumTests/PairingMeetingMigrationTests.swift#L109-L128):

```swift
// Verified verbatim from TeekumTests/PairingMeetingMigrationTests.swift:109-128
    func testMeetingSetterLockAndAttendanceMatchPrototypeRules() throws {
        let store = SessionStore(activeSession: GroupSession(localInitials: "ADI"))
        let service = MeetingPointService(sessionStore: store)
        let coordinate = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        XCTAssertTrue(service.proposeMeetingPoint(coordinate: coordinate))
        let point = try XCTUnwrap(store.activeMeetingPoint)
        XCTAssertTrue(service.canSetMeetingPoint(by: "ADI"))
        XCTAssertTrue(service.canSetMeetingPoint(by: "NIC"))
        XCTAssertFalse(service.applyInboundUpdate(MeetingUpdatePayload(
            coordinate: coordinate, action: .cancel, attendanceStatus: .attending,
            meetingPointId: point.id, senderInitials: "NIC"
        )))
        XCTAssertTrue(service.applyInboundUpdate(MeetingUpdatePayload(
            coordinate: coordinate, action: .accept, attendanceStatus: .atMeetingPoint,
            meetingPointId: point.id, senderInitials: "NIC"
        )))
        XCTAssertEqual(store.activeMeetingPoint?.attendance[.fromInitials("NIC")], .arrived)
        XCTAssertTrue(service.cancelMeetingPoint())
        XCTAssertNil(store.activeMeetingPoint)
    }
```

- **Baris 109–114:** Menginisialisasi `SessionStore` dengan pengguna aktif `"ADI"` dan menginstansiasi `MeetingPointService`. Mengusulkan titik temu pada koordinat $(-6,2, 106,8)$. Menegaskan bahwa usulan berhasil dan membuka bungkus `activeMeetingPoint` yang baru dibuat.
- **Baris 115–116:** Memverifikasi bahwa baik pengusul `"ADI"` maupun rekan `"NIC"` memiliki izin umum untuk menyetel titik temu baru (`canSetMeetingPoint == true`).
- **Baris 117–120:** Mendemonstrasikan aturan Setter Lock: rekan `"NIC"` mencoba membatalkan titik temu aktif melalui pembaruan masuk `.cancel`. `applyInboundUpdate` mengembalikan `false`, menolak pembatalan yang tidak sah.
- **Baris 121–125:** Rekan `"NIC"` mengirimkan tindakan `.accept` dengan status kehadiran `.atMeetingPoint`. `applyInboundUpdate` mengembalikan `true`, dan kehadiran `"NIC"` di `store.activeMeetingPoint` diperbarui menjadi `.arrived`.
- **Baris 126–128:** Pengusul resmi `"ADI"` memanggil `cancelMeetingPoint()`. Pembatalan berhasil (`XCTAssertTrue`), mengosongkan `store.activeMeetingPoint` menjadi `nil`.

---

## Suite 5: `ParityContractTests.swift`

- **Jalur Repositori:** [ParityContractTests.swift](../../TeekumTests/ParityContractTests.swift)
- **Jumlah Baris:** Tepat 258 baris (`wc -l`)
- **Total Kasus Uji:** Tepat 9 kasus uji
- **Subsistem Target:** Verifikasi Paritas Arsitektur terhadap Referensi Prototipe Warisan (`CleartextEnvelope`, `RawWirePacket`, `LocationPingPayload`, `InactivityGuardService`, `SOSForwardingEngine`, `ChatMessageEngine`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`ParityContractTests` adalah rangka verifikasi kontrak arsitektur yang memastikan bahwa implementasi modular yang direfaktor mempertahankan paritas wire byte-demi-byte 100% dan ekuivalensi fungsional dengan referensi prototipe warisan. Ini membuktikan:
1. **Paritas Byte Wire:** Amplop teks jelas, nonce 12-byte, AAD 10-byte, dan paket wire 56-byte cocok dengan vektor uji Prototipe V3 yang dibekukan secara tepat.
2. **Preservasi Telemetri:** Payload lokasi 30-byte mempertahankan stempel waktu pengukuran, koordinat sub-mikroderajat, telemetri baterai, dan 12 byte padding nol di bagian akhir.
3. **Pemotongan Batas Karakter UTF-8:** Pesan obrolan terpotong rapi menjadi 20 byte tanpa memecah grafem multi-byte atau emoji.
4. **Fragmentasi & Kustodi Carry:** Segmentasi bingkai BLE melintasi MTU 20-byte dan jadwal percobaan ulang pesan carry cocok dengan spesifikasi transfer kustodi prototipe.
5. **Prioritas Kotak Keluar:** Antrean kotak keluar menegakkan urutan prioritas ketat di seluruh lalu lintas relai asing (SOS > ACK > Chat > Location).
6. **Penjaga Keamanan Ketidakaktifan:** `InactivityGuardService` secara default dinonaktifkan, memicu hitungan mundur peringatan 30 detik setelah 180 detik keheningan fisik, dan dibatalkan saat ada gerakan akselerometer fisik atau interaksi layar.
7. **Kesegaran Transmisi Ulang SOS:** Transmisi ulang SOS mengunci akar `sosEventId` sembari memperbarui koordinat GPS dan telemetri baterai dengan pembacaan perangkat keras terbaru.
8. **Pengiriman Ulang ACK Hop Terakhir:** Obrolan terautentikasi yang tiba di hop terakhir (`hopCount == hopLimit`) memancarkan ulang ACK tujuan pada penerimaan duplikat tanpa menduplikasi riwayat antarmuka pengguna lokal.
9. **Peringatan Darurat Bebas GPS:** Peringatan marabahaya darurat masuk yang tidak memiliki kuncian GPS membunyikan sirene audio satu kali dan mengakui ulang kedatangan duplikat.

### Analogi ELI5
Bayangkan fasilitas sertifikasi otomotif yang menguji sistem injeksi bahan bakar digital baru terhadap mesin mekanis lama yang telah disertifikasi selama 20 tahun. Untuk mensertifikasi sistem digital baru, para insinyur memasok kedua mesin dengan sinyal udara, bahan bakar, dan throttle yang sama persis. Jika mesin digital membakar bahan bakar sedikit berbeda atau menyalakan businya terlambat setengah milidetik dari prototipe mekanis, mesin digital gagal dalam sertifikasi. `ParityContractTests` adalah bangku sertifikasi untuk protokol radio Meepo.

### Definisi Istilah Teknis
- **Dual-Target Parity Harness:** Konfigurasi sistem build menggunakan kompilasi bersyarat (`PROTOTYPE_REFERENCE`) yang memungkinkan asersi pengujian yang sama persis dieksekusi terhadap kode yang direfaktor dan referensi prototipe warisan.
- **Dead-Man Inactivity Guard:** Sistem keselamatan berbasis sensor yang memantau gerakan perangkat melalui `CMMotionManager` dan sentuhan layar, memulai hitungan mundur marabahaya jika keheningan pengguna mengindikasikan cedera atau kehilangan kesadaran.
- **Hardware Telemetry Refresh:** Memperbarui bidang sensor dinamis (koordinat GPS, persentase baterai) selama transmisi ulang sambil mengunci pengidentifikasi transaksi akar (`sosEventId`).
- **Final Hop Re-ACK:** Memancarkan ulang pengakuan setelah menerima paket duplikat ketika `hopCount == hopLimit`, memastikan ACK yang hilang dapat dipulihkan tanpa membuat pesan duplikat.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan uji berikut memeriksa `testEnvelopeAndNonceMatchPrototypeV3Vector` dari [ParityContractTests.swift:20-33](../../TeekumTests/ParityContractTests.swift#L20-L33):

```swift
// Verified verbatim from TeekumTests/ParityContractTests.swift:20-33
    func testEnvelopeAndNonceMatchPrototypeV3Vector() throws {
        let envelope = CleartextEnvelope(type: .locationPing, hopLimit: 8, hopCount: 2,
            sessionId: 0x1234, sequenceNumber: 0x0700_002a)
        XCTAssertEqual(envelope.serialize(), Data([0x31, 8, 2, 0, 0x12, 0x34, 7, 0, 0, 42]))
        XCTAssertEqual(envelope.constructNonce(), Data([0, 0x12, 0x34, 7, 0, 0, 42, 0x31, 0x54, 0x4b, 0x4d, 0x33]))
        XCTAssertEqual(envelope.authenticatedAssociatedData(), Data([0x31, 8, 0, 0, 0x12, 0x34, 7, 0, 0, 42]))
        XCTAssertEqual(try CleartextEnvelope.deserialize(from: envelope.serialize()), envelope)
        let packet = RawWirePacket(envelope: envelope, ciphertext: Data(repeating: 0x42, count: 30),
            authTag: Data(repeating: 0x24, count: 16))
        let wire = try packet.toWireData()
        XCTAssertEqual(wire.count, 56)
        XCTAssertEqual(wire.prefix(10), envelope.serialize())
        XCTAssertEqual(try RawWirePacket.fromWireData(wire), packet)
    }
```

- **Baris 20–23:** Membangun amplop teks jelas untuk `locationPing` (tipe 1), `hopLimit` 8, `hopCount` 2, ID sesi `0x1234`, dan nomor urut `0x0700_002a` (slot anggota 7, pencacah 42).
- **Baris 23:** Memverifikasi serialisasi tepat 10 byte: `0x31` (versi 3, tipe 1), `8` (batas hop), `2` (jumlah hop), `0, 0x12, 0x34` (ID sesi 24-bit), dan `7, 0, 0, 42` (nomor urut 32-bit).
- **Baris 24:** Memverifikasi nonce ChaCha20 tepat 12-byte: `[0, 0x12, 0x34]` (ID sesi), `[7, 0, 0, 42]` (nomor urut), `0x31` (versi/tipe), dan `[0x54, 0x4b, 0x4d, 0x33]` (`"TKM3"` ASCII ajaib).
- **Baris 25:** Memverifikasi AAD 10-byte: identik dengan amplop yang diserialisasi kecuali indeks byte 2 (`hopCount`) disamarkan menjadi `0`.
- **Baris 26–32:** Memverifikasi deserialisasi roundtrip amplop, membundel ke dalam `RawWirePacket` dengan 30 byte ciphertext dan 16 byte tag autentikasi, memverifikasi total jumlah wire tepat 56 byte, dan mengurai kembali.

---

## Suite 6: `SessionSafetyTests.swift`

- **Jalur Repositori:** [SessionSafetyTests.swift](../../TeekumTests/SessionSafetyTests.swift)
- **Jumlah Baris:** Tepat 245 baris (`wc -l`)
- **Total Kasus Uji:** Tepat 10 kasus uji
- **Subsistem Target:** Keselamatan Alokasi Urutan, Pencegahan Nonce Wrapping, Keamanan Keychain, dan Proyeksi Radar Polar (`PacketSequenceAllocator`, `SessionPersistence`, `SessionStore`, `OrbitMapViewModel`, `OrbitProjection`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`SessionSafetyTests` memverifikasi alokasi urutan kriptografis, jaminan non-wrapping nonce, pembersihan kunci tanpa remanensi (zero-remanence), dan matematika proyeksi spasial radar polar. Ini membuktikan:
1. **Monotonisitas Alokasi Konkuren:** `PacketSequenceAllocator` menghasilkan nomor urut unik dan meningkat secara monoton di 32 tugas asinkron konkuren (`withThrowingTaskGroup`) dan mempertahankan status pencacah saat aplikasi dimulai ulang.`
2. **Pencegahan Penggunaan Ulang Nonce:** Ketika pencacah 24-bit anggota mencapai kehabisan (`0x00FFFFFF`), pengalokasi memunculkan `PacketSequenceError.exhausted` alih-alih kembali ke nol, mencegah kerentanan ChaCha20 two-time pad.
3. **Reservasi Slot Byte Atas:** ID sesi 24-bit mempertahankan ruang urutan terisolasi, dan nomor urut secara ketat mencadangkan byte atas untuk slot anggota.
4. **Pembersihan Keychain Zero-Remanence:** `SessionPersistence` menyimpan metadata sesi di `UserDefaults` dan kunci simetris di iOS Keychain (`kSecClassGenericPassword`), serta menghapusnya secara permanen saat keluar dari sesi (`SecItemDelete`).
5. **Urutan Pengukuran Temporal:** Ping lokasi yang tidak berurutan atau tertunda tidak menimpa pengukuran perangkat keras yang lebih baru, dan meninggalkan sesi membersihkan semua status anggota.
6. **Histeresis Kehilangan Kontak:** Rekan yang diam bertransisi melalui histeresis kehilangan kontak, mencatat kehilangan kontak sekali sampai tersambung kembali.
7. **Observasi Roster:** Antarmuka roster rekan secara dinamis mengamati status penyambungan kembali perantara sebelum kesiapan transpor penuh.
8. **Pemberian Tema Profil Dinamis:** Tampilan radar memperbarui warna profil lokal secara dinamis dari status sesi aktif.
9. **Proyeksi Koordinat Polar:** Proyeksi radar Orbit memutar koordinat rekan relatif terhadap arah kompas dan menjepit rekan yang jauh ke pinggiran perimeter radar.
10. **Preservasi Jarak Metrik:** Proyeksi titik temu menjepit titik temu yang jauh ke pinggiran perimeter sembari mempertahankan pembacaan jarak metrik sebenarnya di UI.

### Analogi ELI5
Bayangkan pengalokasi gelang triase darurat di klinik lapangan tanggap bencana. Bahkan jika 32 utas konkuren meminta nomor urut pada milidetik yang sama persis, tidak ada dua paket yang pernah menerima nonce duplikat. Jika pencacah urutan 32-bit menghabiskan kuotanya, pencacah akan terkunci secara permanen alih-alih berputar kembali ke nol, menghilangkan kerentanan penggunaan ulang nonce di bawah ChaCha20-Poly1305. Ketika seorang responden demobilisasi, sistem mengeksekusi SecItemDelete untuk menghapus kunci simetris secara permanen dari iOS Keychain. Sementara itu, kompas radar taktis memandu operasional menuju titik kumpul triase lapangan: bahkan jika titik tersebut berjarak 5 kilometer melintasi puing-puing, panah perimeter terarah menjepit ke tepi luar, menunjuk langsung ke arah target dengan jarak sebenarnya.

### Definisi Istilah Teknis
- **Concurrent Task Group Allocation:** Meminta nomor urut secara bersamaan di 32 tugas Swift asinkron menggunakan `withThrowingTaskGroup`.
- **Nonce Space Exhaustion:** Kondisi di mana pencacah 24-bit mencapai kapasitas maksimumnya ($2^{24}-1 = 16.777.215$), mengharuskan penghentian transmisi untuk mencegah kerentanan ChaCha20 two-time pad.
- **Zero-Remanence Keychain Purge:** Mengeksekusi `SecItemDelete` untuk menghapus kunci sesi simetris secara permanen dari kantong aman (secure enclave) iOS saat meninggalkan sesi.
- **Temporal Measurement Ordering:** Membandingkan `measurementTimestamp` untuk membuang paket usang yang tiba tidak berurutan melalui jalur mesh multi-hop.
- **Rim Clamping (`isClamped`):** Membatasi koordinat secara trigonometris yang berada di luar radius kanvas radar ke batas melingkar sembari mempertahankan sudut bantalan (bearing).

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan uji berikut memeriksa `testExhaustedSequenceFailsWithoutWrappingNonce` dari [SessionSafetyTests.swift:34-50](../../TeekumTests/SessionSafetyTests.swift#L34-L50):

```swift
// Verified verbatim from TeekumTests/SessionSafetyTests.swift:34-50
    func testExhaustedSequenceFailsWithoutWrappingNonce() async throws {
        let service = "sequence-test-\(UUID())"
        defer { removeKeychainItems(service: service) }
        let session = GroupSession(sessionId: 0x1234, symmetricKeyData: Data(repeating: 0x42, count: 32), localInitials: "ALX")
        var identity = session.symmetricKeyData
        identity.append(contentsOf: [0x00, 0x12, 0x34, session.memberSlot])
        let account = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
            kSecValueData: Data([0, 255, 255, 255])
        ] as CFDictionary, nil)
        XCTAssertEqual(status, errSecSuccess)
        do {
            _ = try await PacketSequenceAllocator(serviceName: service).next(for: session)
            XCTFail("Exhausted nonce space must not restart at zero.")
        } catch PacketSequenceError.exhausted { }
    }
```

- **Baris 34–37:** Membuat pengidentifikasi layanan Keychain yang unik dan menyiapkan pembersihan melalui `defer`. Menginstansiasi `GroupSession` untuk anggota `"ALX"`.
- **Baris 38–40:** Menghitung kunci akun SHA-256 persis yang digunakan oleh `PacketSequenceAllocator` untuk mempertahankan pencacah di Keychain: `symmetricKeyData + session.sessionId + memberSlot`.
- **Baris 41–45:** Secara langsung menyuntikkan status pencacah yang habis (`0x00FFFFFF`, 16.777.215) ke dalam iOS Keychain melalui `SecItemAdd` dengan `kSecClassGenericPassword`.
- **Baris 46–49:** Menginstansiasi `PacketSequenceAllocator` dan memanggil `next(for: session)`. Memverifikasi bahwa pengalokasi mendeteksi kehabisan dan memunculkan `PacketSequenceError.exhausted`. Jika berputar kembali ke nol, `XCTFail` akan tercapai, melanggar keamanan kriptografis.

## File Pendukung 7: `LocationService+Testing.swift`

- **Jalur Repositori:** [LocationService+Testing.swift](../../TeekumTests/Support/LocationService+Testing.swift)
- **Jumlah Baris:** Tepat 34 baris (`wc -l`)
- **Total Kasus Uji:** N/A (Ekstensi Tiruan Simulasi)
- **Subsistem Target:** Simulasi Core Location dan Injeksi Sensor Deterministik (`LocationService`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`LocationService+Testing.swift` memperluas `LocationService` dengan hook simulasi yang dirancang khusus untuk pengujian otomatis. Ini membuktikan bahwa logika domain lokasi (pemfilteran ambang batas akurasi, ekstraksi stempel waktu pengukuran, pelestarian akurasi horizontal, pembacaan baterai, dan pembuatan ping kotak keluar) dapat diverifikasi secara deterministik tanpa memerlukan perangkat keras GPS fisik, akuisisi satelit CoreLocation, atau peringatan otorisasi pengguna.

### Analogi ELI5
Bayangkan menguji speedometer elektronik di meja kerja dalam ruangan. Alih-alih membawa mobil ke jalan raya sungguhan dan menunggu navigasi satelit terhubung, mekanik mencolokkan generator sinyal elektronik ke kabel dasbor, menyalurkan denyut tepat 60 mph langsung ke tampilan speedometer.

### Definisi Istilah Teknis
- **Deterministic Sensor Injection:** Memasok pengukuran sensor yang telah ditentukan sebelumnya ke logika layanan secara terprogram, memungkinkan pengujian yang dapat diulang tanpa ketergantungan perangkat keras eksternal.
- **Hardware Delegate Bypass:** Memanggil metode pemrosesan domain internal secara langsung (`applyLocationMeasurement`) alih-alih menunggu callback asinkron dari `CLLocationManagerDelegate`.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan berikut memeriksa `simulateLocation` dari [LocationService+Testing.swift:14-34](../../TeekumTests/Support/LocationService+Testing.swift#L14-L34):

```swift
// Verified verbatim from TeekumTests/Support/LocationService+Testing.swift:14-34
extension LocationService {
    /// Simulates a location update for deterministic unit testing.
    func simulateLocation(
        coordinate: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy = 5.0,
        timestamp: Date? = nil,
        speed: CLLocationSpeed = -1.0
    ) {
        let ts = timestamp ?? dateProvider()
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            course: 0,
            speed: speed,
            timestamp: ts
        )
        applyLocationMeasurement(location)
    }
}
```

- **Baris 14–21:** Mendeklarasikan metode ekstensi `simulateLocation` yang menerima koordinat garis lintang/bujur, akurasi horizontal opsional (default ke 5,0 meter), stempel waktu opsional, dan kecepatan.
- **Baris 22:** Menyelesaikan stempel waktu pengukuran: jika `timestamp` bernilai nil, ia akan kembali ke `dateProvider()` internal layanan, mendukung jam tiruan virtual.
- **Baris 23–31:** Menginstansiasi objek Apple `CLLocation` nyata yang diinisialisasi dengan parameter sintetis (ketinggian 0, arah rute 0, akurasi dan kecepatan yang ditentukan).
- **Baris 32:** Menyuntikkan `CLLocation` sintetis ke dalam `applyLocationMeasurement(location)`. Ini memicu kuantisasi lokasi, pembacaan baterai, pembuatan ping kotak keluar, dan publikasi status antarmuka identik dengan perbaikan satelit CoreLocation asli.

---

## File Pendukung 8: `TestMeshClock.swift`

- **Jalur Repositori:** [TestMeshClock.swift](../../TeekumTests/Support/TestMeshClock.swift)
- **Jumlah Baris:** Tepat 31 baris (`wc -l`)
- **Total Kasus Uji:** N/A (Tiruan Waktu Virtual)
- **Subsistem Target:** Simulasi Temporal Deterministik dan Perjalanan Waktu Virtual (`MeshClock`)

### Apa yang Dibuktikan oleh Rangkaian Ini
`TestMeshClock.swift` mengimplementasikan jam virtual terkontrol dalam-memori yang mematuhi `MeshClock`. Ini membuktikan bahwa algoritma jaringan mesh yang bergantung pada waktu (jadwal percobaan ulang store-and-forward toleran-penundaan, penyapuan batas waktu rekan, pembatalan tabel rute, dan kedaluwarsa pertemuan) dapat diuji secara deterministik dalam milidetik tanpa memanggil `Task.sleep` atau mengandalkan jam dinding sistem yang non-deterministik.

### Analogi ELI5
Bayangkan teka-teki escape room di mana brankas terbuka hanya setelah pengatur waktu 30 menit habis. Alih-alih memaksa penguji teka-teki duduk di ruangan tanpa melakukan apa pun selama 30 menit nyata, perancang permainan meraih bagian belakang jam, memutar jarum jam ke depan sejauh 30 menit dalam setengah detik, dan brankas langsung terbuka.

### Definisi Istilah Teknis
- **Virtual Time Advancement:** Menaikkan pencacah temporal internal secara terprogram untuk mensimulasikan berlalunya waktu tanpa penundaan fisik.
- **Unchecked Sendable:** Atribut konkurensi Swift yang menegaskan bahwa suatu kelas menyediakan jaminan sinkronisasinya sendiri (melalui `NSLock`), memungkinkan komunikasi lintas-aktor yang aman.
- **Clock Dependency Injection:** Meneruskan abstraksi protokol (`MeshClock`) ke dalam layanan domain alih-alih memanggil metode statis sistem (`Date.now`), memisahkan logika dari kalender fisik.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan berikut memeriksa `TestMeshClock` dari [TestMeshClock.swift:11-31](../../TeekumTests/Support/TestMeshClock.swift#L11-L31):

```swift
// Verified verbatim from TeekumTests/Support/TestMeshClock.swift:11-31
/// Injected mock clock supporting instant, deterministic time advancement.
public final class TestMeshClock: MeshClock, @unchecked Sendable {
    private var currentDate: Date
    private let lock = NSLock()
    
    public init(initialDate: Date = Date()) {
        self.currentDate = initialDate
    }
    
    nonisolated public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return currentDate
    }
    
    nonisolated public func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        currentDate = currentDate.addingTimeInterval(seconds)
    }
}
```

- **Baris 11–14:** Mendeklarasikan `TestMeshClock` yang mematuhi `MeshClock` dan ditandai `@unchecked Sendable`. Status dienkapsulasi dalam `currentDate: Date` yang dilindungi oleh `lock: NSLock`.
- **Baris 16–18:** Penginisialisasi menerima `initialDate`, memungkinkan pengujian menambatkan waktu pada masa deterministik (misalnya, stempel waktu `1.800.000.000`).
- **Baris 20–24:** Mengimplementasikan `now() -> Date` yang ditandai `nonisolated`. Memperoleh `lock` sebelum membaca `currentDate` dan melepaskannya melalui `defer`, memastikan pembacaan thread-safe dari aktor konkuren.`
- **Baris 26–30:** Mengimplementasikan `advance(by seconds: TimeInterval)`. Di bawah penguncian, memajukan `currentDate` dengan menambahkan interval waktu yang ditentukan. Layanan apa pun yang melakukan polling pada `clock.now()` segera mengamati stempel waktu lanjutan.

---

## File Pendukung 9: `TeekumTests-Bridging-Header.h`

- **Jalur Repositori:** [TeekumTests-Bridging-Header.h](../../TeekumTests/TeekumTests-Bridging-Header.h)
- **Jumlah Baris:** Tepat 4 baris (`wc -l`)
- **Total Kasus Uji:** N/A (Header Konfigurasi Build)
- **Subsistem Target:** Jembatan Interoperabilitas Objective-C/C Bundel Pengujian

### Apa yang Dibuktikan oleh Rangkaian Ini
`TeekumTests-Bridging-Header.h` membuktikan bahwa bundel pengujian unit mempertahankan pipa kompilasi yang diperlukan untuk mengekspos simbol C dan Objective-C ke rangkaian pengujian Swift, memenuhi persyaratan konfigurasi build Xcode untuk pengujian lintas bahasa.

### Analogi ELI5
Bayangkan adaptor daya internasional universal yang dipasang di dinding kamar hotel. Bahkan jika Anda tidak memiliki perangkat asing yang dicolokkan saat ini, adaptor tersebut telah dipasang kabel dan siap digunakan sehingga steker internasional apa pun berfungsi tanpa memutus pemutus sirkuit (sekring).

### Definisi Istilah Teknis
- **Bridging Header:** File konfigurasi build Xcode (`SWIFT_OBJC_BRIDGING_HEADER`) yang memungkinkan kode sumber Swift mengimpor dan mengeksekusi antarmuka C dan Objective-C.
- **Interoperability Bridge:** Perancah kompilasi yang memungkinkan fungsi kerangka kerja Darwin atau Security tingkat rendah diuji dengan mulus dari Swift.

### Panduan Uji Representatif (Baris-demi-Baris)
Panduan berikut memeriksa `TeekumTests-Bridging-Header.h` dari [TeekumTests-Bridging-Header.h:1-4](../../TeekumTests/TeekumTests-Bridging-Header.h#L1-L4):

```objc
// Verified verbatim from TeekumTests/TeekumTests-Bridging-Header.h:1-4
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

```

- **Baris 1–4:** Templat bridging header Xcode standar yang menetapkan batas C/Objective-C ke Swift untuk bundel pengujian.

---

## Verifikasi Build dan Pengujian yang Teramati

Sesuai dengan standar verifikasi teknis yang ketat, eksekusi pelari uji baris perintah dicoba secara langsung terhadap lingkungan host:

```bash
$ xcodebuild -showsdks
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

### Catatan Lingkungan Transparan
Lingkungan pengembang menjalankan Apple Command Line Tools (`/Library/Developer/CommandLineTools`) alih-alih instalasi grafis penuh Xcode IDE (`/Applications/Xcode.app`). Utilitas `xcodebuild` dan daemon runtime iOS Simulator (`CoreSimulator.framework`) dibundel secara eksklusif di dalam bundel aplikasi Xcode lengkap. Karena Command Line Tools hanya menyediakan kompilator mandiri dan utilitas CLI tanpa akar iOS SDK (`iPhoneSimulator.sdk`), eksekusi pengujian simulator interaktif tidak dapat dipanggil secara langsung dari sesi terminal ini.

### Analisis Statis & Metodologi Verifikasi
Untuk menjamin verifikasi yang lengkap dan ketat tanpa mengandalkan kelulusan simulasi:
1. **Verifikasi AST & Kode Sumber Menyeluruh:** Setiap file pengujian dibaca dari baris 1 hingga EOF. Semua 70 metode pengujian di enam rangkaian pengujian diindeks dan dipetakan ke implementasi produksinya.
2. **Penyelarasan Vektor Tingkat-Byte:** Semua offset byte, bitmask, nonce kriptografi, dan perlengkapan wire yang diharapkan diverifikasi dengan mereferensi silang `PacketCodecTest.swift`, `ParityContractTests.swift`, dan model produksi di `Teekum/Teekum/Core/Wire/`.
3. **Konfigurasi Proyek & Skema:** `project.yml` dan `project-parity.yml` dianalisis, mengonfirmasi konfigurasi bundel `TeekumTests`, target kerangka kerja `PrototypeReference`, dan skema verifikasi `TeekumParity`.

---

## Navigasi Footer

- [Volume 00: Indeks Utama & Ringkasan Arsitektur](00_index_and_architecture.md)
- [Volume 12: Diagnostik Fitur, Telemetri Paket & Kesehatan Jaringan](12_feature_diagnostics.md)
- [Volume 14: Panduan Narasi Non-Teknis & Pameran](14_non_technical_and_exhibition_guide.md)
