// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // ÖNEMLİ: Firebase Auth şu an KULLANILMIYOR. Bu geçici ve güvensiz bir yöntemdir.
import 'package:cloud_firestore/cloud_firestore.dart';

// AppUser modeli: Kullanıcı bilgilerini (isim, e-posta vb.) yapısal olarak tutar.
// Şifre bu modelde saklanmaz, çünkü bu durum güvenliği daha da azaltırdı.
class AppUser {
  final String uid; // Firestore'daki dokümanın ID'si. Geçici yöntemde basitçe oluşturulur.
  final String? email;
  final String? name;
  final Timestamp? createdAt; // Kullanıcının ne zaman oluşturulduğu bilgisi.

  AppUser({
    required this.uid,
    this.email,
    this.name,
    this.createdAt,
  });

  // Firestore'dan okunan veriyi AppUser nesnesine dönüştürür.
  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, [SnapshotOptions? options]) {
    final data = snapshot.data();
    return AppUser(
      uid: snapshot.id, // Doküman ID'sini alır.
      email: data?['email'] as String?,
      name: data?['name'] as String?,
      createdAt: data?['createdAt'] as Timestamp?,
    );
  }

  // AppUser nesnesini Firestore'a yazılacak formata dönüştürür.
  Map<String, dynamic> toFirestore() {
    return {
      if (email != null) "email": email,
      if (name != null) "name": name,
      if (createdAt != null) "createdAt": createdAt,
      // DİKKAT: Şifre bu metoda dahil edilmez. Şifre, register metodunda doğrudan Firestore'a (güvensiz bir şekilde) yazılır.
    };
  }
}

class AuthProvider with ChangeNotifier {
  // Firebase Auth KULLANILMIYOR. Yerine doğrudan Firestore kullanılıyor (geçici ve güvensiz).
  // final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore ile etkileşim için.

  AppUser? _currentUser; // Mevcut giriş yapmış kullanıcı bilgileri.
  bool _isAuthenticated = false; // Kullanıcının giriş yapıp yapmadığını belirtir.
  String? _authError; // Kayıt veya giriş sırasında oluşan hataları tutar.

  // Getter'lar: UI'ın bu değerlere erişmesini sağlar.
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _currentUser?.uid;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.name;
  String? get authError => _authError;

  // AuthProvider oluşturulduğunda çağrılır.
  AuthProvider() {
    // Uygulama ilk açıldığında, SharedPreferences'ten (yerel depolama) son oturum durumunu yükler.
    // Bu, uygulamanın hızlı başlamasına yardımcı olur, ancak asıl doğrulama Firestore'dan gelir.
    _loadFromPrefs();
  }

  // Mevcut kullanıcı bilgilerini ve oturum durumunu temizler.
  void _clearAuthData({bool notify = true}) {
    _currentUser = null;
    _isAuthenticated = false;
    if (notify) notifyListeners(); // Durum değişikliğini UI'a bildirir.
  }

  // Yeni kullanıcı kaydı yapar (GEÇİCİ VE GÜVENSİZ YÖNTEM).
  Future<void> register(String name, String email, String password) async {
    _authError = null; // Önceki hata mesajını temizler.
    notifyListeners(); // UI'da yükleme göstergesi varsa aktifleşir.

    try {
      // 1. Firestore'da bu e-postanın zaten kayıtlı olup olmadığını kontrol eder.
      // 'users_unsafe_auth' koleksiyonu bu geçici yöntem için kullanılır.
      final querySnapshot = await _firestore
          .collection('users_unsafe_auth')
          .where('email', isEqualTo: email) // E-posta ile filtreler.
          .limit(1) // Sadece bir sonuç yeterli.
          .get();

      // Eğer e-posta zaten varsa, hata fırlatır.
      if (querySnapshot.docs.isNotEmpty) {
        _authError = 'Bu e-posta adresi zaten kayıtlı.';
        notifyListeners();
        throw Exception(_authError);
      }

      // 2. Yeni kullanıcı için basit bir ID oluşturur ve AppUser nesnesini hazırlar.
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}_${email.hashCode}';
      _currentUser = AppUser(
        uid: userId,
        email: email,
        name: name,
        createdAt: Timestamp.now(), // Kayıt zamanını Firestore Timestamp olarak ayarlar.
      );

      await _firestore.collection('users_unsafe_auth').doc(userId).set({
        'email': email,
        'name': name,
        'createdAt': Timestamp.now(),
        'password_plaintext': password,
      });

      _isAuthenticated = true; // Kullanıcıyı doğrulanmış olarak işaretler.
      await _saveToPrefs(); // Oturum bilgilerini yerel depolamaya (SharedPreferences) kaydeder.
      debugPrint("Geçici Kayıt başarılı ve Firestore'a yazıldı (GÜVENSİZ): $userId");
      notifyListeners(); // UI'ı günceller.

    } catch (e) {
      debugPrint("Geçici Kayıt Hatası: $e");
      _authError = _authError ?? 'Kayıt sırasında bir hata oluştu.';
      _clearAuthData(notify: false); // Hata durumunda oturum bilgilerini temizler.
      notifyListeners(); // Hata mesajını UI'a bildirir.
      throw Exception(_authError); // Hatanın yukarıya (UI'a) iletilmesini sağlar.
    }
  }

  Future<void> signIn(String email, String password) async {
    _authError = null;
    notifyListeners();

    try {
      // 1. Firestore'da verilen e-posta ile eşleşen kullanıcıyı arar.
      final querySnapshot = await _firestore
          .collection('users_unsafe_auth')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      // Kullanıcı bulunamazsa hata fırlatır.
      if (querySnapshot.docs.isEmpty) {
        _authError = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
        notifyListeners();
        throw Exception(_authError);
      }

      // Kullanıcı bulunduysa, dokümanı ve verilerini alır.
      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final storedPassword = userData['password_plaintext'] as String?;

      // Saklanan şifre ile girilen şifreyi karşılaştırır.
      if (storedPassword == null || storedPassword != password) {
        _authError = 'E-posta veya şifre hatalı.';
        notifyListeners();
        throw Exception(_authError);
      }

      // Şifreler eşleşirse, giriş başarılıdır.
      _currentUser = AppUser( // AppUser nesnesini Firestore'dan gelen bilgilerle doldurur.
        uid: userDoc.id,
        email: userData['email'] as String?,
        name: userData['name'] as String?,
        createdAt: userData['createdAt'] as Timestamp?,
      );
      _isAuthenticated = true;
      await _saveToPrefs(); // Oturum bilgilerini yerel depolamaya kaydeder.
      debugPrint("Geçici Giriş başarılı (GÜVENSİZ): ${userDoc.id}");
      notifyListeners();

    } catch (e) {
      debugPrint("Geçici Giriş Hatası: $e");
      _authError = _authError ?? 'Giriş sırasında bir hata oluştu.';
      _clearAuthData(notify: false);
      notifyListeners();
      throw Exception(_authError);
    }
  }

  // Kullanıcı oturumunu kapatır.
  Future<void> signOut() async {
    _authError = null;
    _clearAuthData(); // Kullanıcı bilgilerini ve oturum durumunu sıfırlar.
    await _clearPrefs(); // Yerel depolamadaki oturum bilgilerini siler.
    debugPrint("Geçici Çıkış yapıldı.");
    notifyListeners();
  }

  // Oturum bilgilerini SharedPreferences'e (yerel depolama) kaydeder.
  // Bu, uygulama kapatılıp açıldığında kullanıcının tekrar giriş yapmasını engeller (geçici olarak).
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated_unsafe', _isAuthenticated);
    if (_currentUser != null) {
      await prefs.setString('userId_unsafe', _currentUser!.uid);
      await prefs.setString('userEmail_unsafe', _currentUser!.email ?? '');
      await prefs.setString('userName_unsafe', _currentUser!.name ?? '');
    }
  }

  // Uygulama başladığında SharedPreferences'ten oturum bilgilerini yükler.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated_unsafe') ?? false;
    if (_isAuthenticated) {
      final uid = prefs.getString('userId_unsafe');
      final email = prefs.getString('userEmail_unsafe');
      final name = prefs.getString('userName_unsafe');
      if (uid != null) {
        // DİKKAT: Bu geçici yöntemde, uygulama açıldığında Firestore'dan güncel veri çekilmiyor.
        // Sadece SharedPreferences'teki bilgiler kullanılıyor. Bu, verilerin güncel olmaması riskini taşır.
        // Gerçek bir uygulamada, Firebase Auth state listener veya başlangıçta Firestore'dan veri çekme kullanılır.
        _currentUser = AppUser(uid: uid, email: email, name: name);
      } else {
        // SharedPreferences'te UID yoksa, tutarsız bir durum oluşmuş demektir. Oturumu temizle.
        _isAuthenticated = false;
        await _clearPrefs();
      }
    }
    notifyListeners(); // Yüklenen durumu UI'a bildirir.
  }

  // SharedPreferences'teki oturum bilgilerini temizler.
  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated_unsafe');
    await prefs.remove('userId_unsafe');
    await prefs.remove('userEmail_unsafe');
    await prefs.remove('userName_unsafe');
  }

  // Splash Screen'de çağrılarak mevcut oturum durumunu kontrol eder (bu geçici yöntemde SharedPreferences'i okur).
  Future<void> checkAuthStatus() async {
    await _loadFromPrefs();
  }

  // Provider dispose edildiğinde çağrılır (genellikle widget ağacından kaldırıldığında).
  @override
  void dispose() {
    super.dispose();
  }
}