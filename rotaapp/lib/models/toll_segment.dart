// lib/models/toll_segment.dart

import './route_step.dart'; // RouteStep modelini import edin
// debugPrint için
import 'dart:developer'; // log fonksiyonu için
import 'dart:collection'; // LinkedHashSet için
import 'package:flutter/foundation.dart'; // debugPrint için
import 'package:collection/collection.dart'; // DeepCollectionEquality için

class TollSegment {
  // Segmentin iki ucunu temsil eden anahtar kelimeler.
  final String keyword1;
  final String keyword2;

  // Bu segmenti kullanan araç sınıfı (1'den 6'ya kadar)
  final int vehicleClass;

  // Bu segmenti geçmenin ücreti
  final double cost;
  
  // Debug modunu kontrol eden değişken
  static bool debugMode = false;

  TollSegment({
    required this.keyword1,
    required this.keyword2,
    required this.vehicleClass, // Yeni eklenen özellik
    required this.cost,
  });

  // Debug mesajlarını yazdıran yardımcı metod
  void _debug(String message) {
    if (debugMode) {
      debugPrint('🔍 TollSegment: $message');
      log('TollSegment: $message');
    }
  }

  // Türkçe karakterleri İngilizce karşılıklarına çeviren yardımcı fonksiyon
  String _translateTurkishChars(String text) {
    return text
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ı', 'i') // Küçük noktasız ı -> i
        .replaceAll('İ', 'I') // Büyük noktalı İ -> I (Küçük harfe çevrilecek)
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C');
  }

  // Bir adım metninin (isim + talimat) belirli bir anahtar kelimeyi içerip içermediğini kontrol eder (karakter çevirisi sonrası küçük harf).
  bool _stepTextContainsKeyword(String stepText, String keyword) {
    _debug('Checking if "$stepText" contains "$keyword"');
    
    if (stepText.isEmpty || keyword.isEmpty) {
      _debug('Result: false (empty text or keyword)');
      return false;
    }

    // Karakterleri çevir ve küçük harfe çevir
    final translatedStepText = _translateTurkishChars(stepText).toLowerCase();
    final translatedKeyword = _translateTurkishChars(keyword)
        .toLowerCase(); // Anahtar kelimeyi de çevir ve küçük harf yap

    _debug('Comparing translated lower: "$translatedStepText" vs "$translatedKeyword"');
    final result = translatedStepText.contains(translatedKeyword);
    _debug('Result: $result');
    
    return result;
  }

  // Rota adımları listesi içinde bu gişe segmentinin geçip geçmediğini kontrol eder.
  bool matchesRouteSteps(List<RouteStep> allSteps) {
    _debug('=== Segment Eşleşme Kontrolü Başladı: $segmentDescription (Sınıf: $vehicleClass, Anahtar Kelimeler: "${keyword1.toLowerCase()}", "${keyword2.toLowerCase()}") ===');

    if (allSteps.isEmpty) {
      _debug('=== Kontrol Bitti: Adım listesi boş. Eşleşmedi. ===');
      return false;
    }

    int keyword1FirstIndex = -1;
    int keyword2FirstIndex = -1;

    // Tüm adımları gezerek anahtar kelimelerin geçtiği ilk indeksleri bul
    for (int i = 0; i < allSteps.length; i++) {
      final stepText =
          '${allSteps[i].name} ${allSteps[i].instruction ?? ''}'.trim();

      _debug('Adım $i kontrol ediliyor: "$stepText"');

      // keyword1 kontrolü
      if (_stepTextContainsKeyword(stepText, keyword1)) {
        if (keyword1FirstIndex == -1) {
          keyword1FirstIndex = i;
          _debug('-> "${keyword1.toLowerCase()}" ilk defa adım $i\'de bulundu (Çeviri Sonrası Kontrol).');
        }
      }
      // keyword2 kontrolü
      if (_stepTextContainsKeyword(stepText, keyword2)) {
        if (keyword2FirstIndex == -1) {
          keyword2FirstIndex = i;
          _debug('-> "${keyword2.toLowerCase()}" ilk defa adım $i\'de bulundu (Çeviri Sonrası Kontrol).');
        }
      }
    }

    _debug('=== Kontrol Sonrası İndeksler: "${keyword1.toLowerCase()}" Index: $keyword1FirstIndex, "${keyword2.toLowerCase()}" Index: $keyword2FirstIndex ===');

    final bool foundBothKeywords =
        keyword1FirstIndex != -1 && keyword2FirstIndex != -1;

    // Sadece farklı adımlarda bulundularsa sıra kontrolü yap
    final bool differentSteps =
        foundBothKeywords && (keyword1FirstIndex != keyword2FirstIndex);

    // Sıra kontrolü: keyword1, keyword2'den önce mi geliyor?
    final bool order1to2 =
        differentSteps && (keyword1FirstIndex < keyword2FirstIndex);
    // Sıra kontrolü: keyword2, keyword1'den önce mi geliyor?
    final bool order2to1 =
        differentSteps && (keyword2FirstIndex < keyword1FirstIndex);

    final bool matched = foundBothKeywords &&
        differentSteps &&
        (order1to2 ||
            order2to1);

    _debug('=== Kontrol Sonuçları: foundBothKeywords: $foundBothKeywords, differentSteps: $differentSteps, order1to2: $order1to2, order2to1: $order2to1, Genel Eşleşme: $matched ===');
    _debug('=== Segment Eşleşme Kontrolü Bitti: $segmentDescription (Sınıf: $vehicleClass). Sonuç: $matched ===');

    return matched;
  }

  // Segmentin tanımını döndürür (örneğin "Yeniçağa - İzmit Doğu")
  String get segmentDescription => '$keyword1 - $keyword2';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TollSegment &&
          runtimeType == other.runtimeType &&
          vehicleClass == other.vehicleClass &&
          cost == other.cost &&
          const DeepCollectionEquality().equals(
            LinkedHashSet.from([
              _translateTurkishChars(keyword1).toLowerCase(),
              _translateTurkishChars(keyword2).toLowerCase(),
            ]),
            LinkedHashSet.from([
              _translateTurkishChars(other.keyword1).toLowerCase(),
              _translateTurkishChars(other.keyword2).toLowerCase(),
            ]),
          );

  @override
  int get hashCode =>
      Object.hashAll([
        const DeepCollectionEquality().hash(
          LinkedHashSet.from([
            _translateTurkishChars(keyword1).toLowerCase(),
            _translateTurkishChars(keyword2).toLowerCase(),
          ]),
        ),
        vehicleClass,
        cost,
      ]);

  @override
  String toString() {
    return 'TollSegment{keyword1: "$keyword1", keyword2: "$keyword2", vehicleClass: $vehicleClass, cost: $cost}';
  }
}
