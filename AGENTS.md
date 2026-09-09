# AGENTS.md

## 1. ANA KURAL — MEVCUT ÇALIŞAN KODU KORU

Bu projede en önemli kural:

**Mevcut çalışan özellikleri bozma.**

Yeni bir özellik eklerken mevcut özellikleri, ekranları, kullanıcı akışlarını, Firebase yapısını veya UI tasarımını gereksiz yere değiştirme.

Yeni görev yalnızca belirtilen özelliğin uygulanmasıyla sınırlıdır.

Bir değişiklik mevcut çalışan bir özelliği etkileyebilecekse:
- Değişiklik yapmadan önce durumu açıkla.
- Neden gerekli olduğunu belirt.
- Mümkünse daha güvenli alternatif öner.
- Gerekli olmadıkça mevcut sistemi değiştirme.

---

# 2. DEĞİŞİKLİKLERİ MİNİMUM TUT

Her görevde:

- Yalnızca gerekli dosyaları değiştir.
- Yalnızca gerekli kodu değiştir.
- Gereksiz refactor yapma.
- Çalışan kodu yeniden yazma.
- Çalışan widget'ları sırf daha temiz göründüğü için değiştirme.
- Dosyaları gereksiz yere taşıma.
- Class veya method isimlerini gereksiz yere değiştirme.
- Mevcut mimariyi değiştirme.
- Büyük çaplı kod dönüşümleri yapma.

**"Daha temiz", "daha modern", "daha performanslı" veya "daha iyi" olduğunu düşündüğün için çalışan kodu yeniden düzenleme.**

---

# 3. GÖREVİ ANALİZ ETMEDEN KODA DOKUNMA

Her yeni görevde önce mevcut projeyi analiz et.

Özellikle:

- İlgili ekranları
- İlgili widget'ları
- İlgili model sınıflarını
- Provider / Riverpod / Bloc / GetX yapılarını
- Repository yapılarını
- Firebase servislerini
- Navigation sistemini
- Authentication sistemini
- Firestore yapısını
- Storage kullanımını
- Cloud Functions kullanımını
- Mevcut utility/helper sınıflarını

kontrol et.

Aynı işi yapan mevcut bir yapı varsa **yeni ve paralel bir yapı oluşturma.**

Önce mevcut sistemi kullan.

---

# 4. PLANLAMADAN BÜYÜK DEĞİŞİKLİK YAPMA

Görev birden fazla dosyayı etkiliyorsa önce:

1. Hangi dosyaların değişeceğini belirle.
2. Her dosyada ne değişeceğini belirle.
3. Mevcut sistemi neden değiştirmek gerektiğini kontrol et.
4. Gereksiz dosyaları değişiklik listesinden çıkar.

Büyük mimari değişiklik gerekiyorsa doğrudan uygulama.

Önce kullanıcıya bildir ve onay bekle.

---

# 5. UI / UX KURALLARI

Mevcut UI tasarımını koru.

Kullanıcı özellikle istemediği sürece:

- Renkleri değiştirme.
- Fontları değiştirme.
- Font boyutlarını değiştirme.
- Padding değiştirme.
- Margin değiştirme.
- Border radius değiştirme.
- Icon değiştirme.
- Button boyutlarını değiştirme.
- AppBar tasarımını değiştirme.
- Bottom navigation tasarımını değiştirme.
- Animasyonları değiştirme.
- Splash ekranını değiştirme.
- Sayfa geçişlerini değiştirme.
- Responsive davranışı bozma.

Yeni UI mevcut tasarım sistemine uyumlu olmalıdır.

Mevcut bir component varsa onu tekrar kullan.

---

# 6. NAVIGATION KURALLARI

Mevcut navigation sistemini değiştirme.

GoRouter, Navigator, named routes veya projede kullanılan mevcut navigation yapısı hangisiyse onu kullan.

Yeni bir navigation sistemi oluşturma.

Mevcut route isimlerini değiştirme.

Mevcut deep-link davranışını bozma.

---

# 7. FIREBASE KURALLARI

Firebase yapılandırmasına özellikle dikkat et.

Kullanıcı açıkça istemediği sürece:

- Firebase projesini değiştirme.
- Firebase yapılandırmasını değiştirme.
- Firebase Authentication yapısını değiştirme.
- Firestore collection isimlerini değiştirme.
- Firestore document yapısını değiştirme.
- Firestore field isimlerini değiştirme.
- Storage path'lerini değiştirme.
- Cloud Functions mimarisini değiştirme.
- Firebase Security Rules'u değiştirme.
- Firebase indexes dosyasını gereksiz yere değiştirme.

Yeni özellik mevcut Firebase yapısına uyumlu şekilde eklenmelidir.

Database schema değişikliği gerekiyorsa önce bildir.

---

# 8. FIRESTORE VERİ GÜVENLİĞİ

Firestore işlemlerinde:

- Kullanıcı yetkilerini kontrol et.
- Client tarafından güvenilmeyen alanlara güvenme.
- Admin işlemlerini client tarafında güvenli kabul etme.
- Kullanıcı ID'sini doğrula.
- Mevcut Security Rules ile uyumlu kod yaz.
- Gereksiz database read/write oluşturma.
- Aynı veriyi tekrar tekrar okumaktan kaçın.

Security Rules değiştirmek gerekiyorsa kullanıcı onayı olmadan değiştirme.

---

# 9. FIREBASE AUTHENTICATION

Mevcut Authentication sistemini koru.

Login, logout, registration, password reset, email verification veya kullanıcı session davranışını yeni özellik nedeniyle bozma.

Yeni özellikte kullanıcı bilgisi gerekiyorsa mevcut authenticated user bilgisini kullan.

Yeni ve paralel authentication sistemi oluşturma.

---

# 10. FIREBASE STORAGE

Mevcut Storage yapısını koru.

Dosya yükleme sırasında:

- Dosya boyutunu kontrol et.
- Dosya tipini kontrol et.
- Mevcut path yapısını koru.
- Gereksiz duplicate upload yapma.
- Kullanıcı yetkilerini kontrol et.

Mevcut Storage path formatını değiştirme.

---

# 11. MODELLER

Mevcut model sınıflarını mümkün olduğunca koru.

Yeni field gerekiyorsa:

- Mevcut verileri bozmayacak şekilde ekle.
- Null safety kurallarına dikkat et.
- Eski Firestore belgelerinin yeni field olmadan da çalışmasını sağla.

Mevcut JSON / Firestore serialization davranışını bozma.

---

# 12. STATE MANAGEMENT

Projede kullanılan mevcut state management sistemini kullan.

Örneğin:

- Riverpod
- Provider
- Bloc/Cubit
- GetX
- ChangeNotifier

hangisi kullanılıyorsa onu koru.

Yeni bir state management sistemi ekleme.

Aynı state için birden fazla source of truth oluşturma.

---

# 13. ASYNC / FIREBASE İŞLEMLERİ

Async işlemlerde:

- Loading state yönet.
- Error state yönet.
- Empty state yönet.
- Widget dispose durumlarına dikkat et.
- Gereksiz duplicate request oluşturma.
- Aynı işlemi birden fazla kez tetikleme.
- Race condition oluşturma.
- Firebase çağrılarını UI thread davranışını bozmayacak şekilde yönet.

---

# 14. HATA YÖNETİMİ

Yeni özellikte hata durumlarını düzgün yönet.

Uygulamanın çökmesine neden olabilecek:

- null değerler
- Firebase hataları
- network hataları
- timeout
- boş veri
- beklenmeyen response
- kullanıcı tarafından girilen hatalı veri

durumlarını kontrol et.

Ancak mevcut error handling sistemini gereksiz yere değiştirme.

---

# 15. NULL SAFETY

Flutter null safety kurallarına uy.

Şunları gereksiz kullanma:

- !
- dynamic
- late

Null assertion operator (`!`) yalnızca değerin kesin olarak null olmayacağı kanıtlanabiliyorsa kullanılmalıdır.

---

# 16. PERFORMANS

Performans iyileştirmesi gerekiyorsa mevcut davranışı bozmadan yap.

Öncelik:

1. Gereksiz rebuild azaltma.
2. Gereksiz Firebase read/write azaltma.
3. Gereksiz network request azaltma.
4. Büyük listelerde lazy loading kullanma.
5. Görselleri uygun şekilde cache etme.
6. Ağır işlemleri UI akışından ayırma.

Sırf performans için çalışan mimariyi tamamen değiştirme.

---

# 17. DEPENDENCY KURALI

Yeni package/dependency eklemeden önce mevcut package'larla aynı işin yapılıp yapılamayacağını kontrol et.

Gereksiz dependency ekleme.

pubspec.yaml dosyasını gereksiz değiştirme.

Yeni dependency eklemek gerekiyorsa:
- Neden gerektiğini belirt.
- Mevcut Flutter/Dart sürümüyle uyumluluğunu kontrol et.
- Mevcut dependency'lerle çakışma oluşturmadığından emin ol.

---

# 18. DOSYA SİLME KURALI

Kullanıcı açıkça istemediği sürece:

**Dosya silme.**

Aynı şekilde:

- Class silme.
- Method silme.
- Widget silme.
- Firebase function silme.
- Route silme.
- Model silme.

Yalnızca gerçekten kullanılmadığı kesin olarak tespit edilen ve kaldırılması görev kapsamında olan kodları değiştir.

---

# 19. IMPORT KURALI

Import temizliği yaparken çalışan kodu bozma.

Kullanılmadığını düşündüğün importları otomatik olarak topluca silme.

Değişiklik sonrası Dart analyzer sonucuna göre hareket et.

---

# 20. TEST VE DOĞRULAMA

Her önemli değişiklikten sonra mümkünse:

```bash
flutter analyze
```

çalıştır.

Uygun testler varsa:

```bash
flutter test
```

çalıştır.

Build ile ilgili değişikliklerde mümkünse:

```bash
flutter build apk
```

veya proje ihtiyacına göre:

```bash
flutter build appbundle
```

ile doğrula.

Hata oluşursa yalnızca yaptığın değişiklikten kaynaklanan hataları düzelt.

Başka alanlara gereksiz müdahale etme.

---

# 21. GIT KURALI

Git repository kullanılıyorsa mevcut değişiklikleri koru.

Kullanıcının mevcut değişikliklerini:

- Silme.
- Üzerine yazma.
- Resetleme.
- Revert etme.

Kullanıcı açıkça istemediği sürece:

```bash
git reset --hard
git clean -fd
git checkout .
```

gibi yıkıcı komutları çalıştırma.

---

# 22. MEVCUT DEĞİŞİKLİKLERİ KORU

Göreve başlamadan önce çalışma alanında kullanıcı tarafından yapılmış değişiklikler varsa bunları koru.

Kullanıcının mevcut değişikliklerinin sana ait olduğunu varsayma.

Bir dosyada hem mevcut kullanıcı değişiklikleri hem de yeni görev için gereken kod varsa mevcut kodu mümkün olduğunca koruyarak minimum değişiklik yap.

---

# 23. GERİYE DÖNÜK UYUMLULUK

Yeni özellik eski kullanıcı verilerini bozmayacak şekilde tasarlanmalıdır.

Özellikle:

- Firestore belgeleri
- Local storage
- SharedPreferences
- Cached data
- User profiles
- Existing listings
- Existing messages
- Existing orders

gibi mevcut veriler yeni kod ile çalışmaya devam etmelidir.

---

# 24. GEREKSİZ REFACTOR YASAK

Kullanıcı yalnızca:

"X özelliğini ekle"

dediyse:

- Mimariyi yeniden tasarlama.
- Kodun tamamını refactor etme.
- Dosya yapısını değiştirme.
- Naming convention değiştirme.
- UI'ı yeniden tasarlama.
- State management değiştirme.
- Firebase mimarisini değiştirme.

**Görev neyse sadece onu yap.**

---

# 25. KOD STİLİ

Mevcut projedeki kod stilini takip et.

Yeni kod:

- Mevcut indentation
- Naming convention
- Class yapısı
- Widget yapısı
- Service yapısı
- Repository yapısı
- Error handling
- Comment formatı

ile uyumlu olmalıdır.

Kendi kişisel kod stilini mevcut projeye zorla uygulama.

---

# 26. KODU YENİDEN YAZMADAN ÖNCE KONTROL

Bir dosyada küçük bir değişiklik gerekiyorsa dosyanın tamamını yeniden oluşturma.

Örneğin yalnızca bir buton eklenmesi gerekiyorsa:

Yanlış:

"Dosyanın tamamını yeniden yaz."

Doğru:

"Mevcut yapıyı koru ve gerekli noktaya yalnızca yeni butonu ekle."

---

# 27. BÜYÜK GÖREVLERİ PARÇALA

Görev büyükse aşamalara böl.

Örneğin:

1. Model
2. Service
3. Repository
4. State management
5. UI
6. Navigation
7. Firebase
8. Test

Her aşamada mevcut sistemin bozulmadığını kontrol et.

Tek seferde onlarca dosyayı değiştirmekten kaçın.

---

# 28. BİLMEDİĞİN ŞEYİ UYDURMA

Mevcut projede olmayan:

- Firebase collection
- API endpoint
- package
- class
- route
- database field
- environment variable
- configuration

uydurma.

Kod içinde mevcut yapıyı bulamıyorsan bunu belirt.

---

# 29. KULLANICI İSTEĞİ İLE PROJE KURALLARI ÇATIŞIRSA

Kullanıcı açıkça bir değişiklik istiyorsa onu uygula.

Ancak değişiklik mevcut özellikleri bozacaksa:

1. Etkilenecek alanı belirt.
2. Daha güvenli alternatif öner.
3. Kullanıcı onaylamadan gereksiz yıkıcı değişiklik yapma.

---

# 30. TASK SCOPE

Her görev için kendine şu soruyu sor:

> "Bu değişiklik kullanıcının istediği özelliğin çalışması için gerçekten gerekli mi?"

Cevap hayır ise değişikliği yapma.

---

# 31. SON KONTROL

Her görev tamamlandıktan sonra kontrol et:

- [ ] Mevcut özellikler korunuyor mu?
- [ ] Mevcut UI değişmedi mi?
- [ ] Gereksiz dosya değişti mi?
- [ ] Gereksiz refactor yapıldı mı?
- [ ] Firebase yapısı korundu mu?
- [ ] Authentication bozulmadı mı?
- [ ] Firestore yapısı korundu mu?
- [ ] Navigation bozulmadı mı?
- [ ] State management korundu mu?
- [ ] Null safety doğru mu?
- [ ] Error handling var mı?
- [ ] `flutter analyze` sonucu temiz mi?
- [ ] Mevcut testler çalışıyor mu?
- [ ] Kullanıcının mevcut değişiklikleri korundu mu?

---

# 32. COPILOT'A UYGULANACAK ÇALIŞMA PRENSİBİ

Her görevde şu sırayı takip et:

### AŞAMA 1 — ANALİZ

Önce mevcut kodu ve ilgili dosyaları analiz et.

### AŞAMA 2 — PLAN

Değiştirilecek dosyaları ve yapılacak minimum değişiklikleri belirle.

### AŞAMA 3 — UYGULAMA

Sadece gerekli değişiklikleri uygula.

### AŞAMA 4 — DOĞRULAMA

`flutter analyze` ve uygun testleri çalıştır.

### AŞAMA 5 — RAPOR

Sonuç olarak şunları bildir:

- Hangi dosyalar değiştirildi?
- Ne değiştirildi?
- Neden değiştirildi?
- Test/analyze sonucu nedir?
- Mevcut özelliklerde değişiklik oldu mu?

---

# 33. MUTLAK KURAL

**ÇALIŞAN KODU SIRF DAHA İYİ GÖRÜNDÜĞÜNÜ DÜŞÜNDÜĞÜN İÇİN DEĞİŞTİRME.**

**YENİ ÖZELLİK EKLE, ESKİ ÖZELLİKLERİ KORU.**

**MİNİMUM DEĞİŞİKLİK + MAKSİMUM GERİYE DÖNÜK UYUMLULUK.**