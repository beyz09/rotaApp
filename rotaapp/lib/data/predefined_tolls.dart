// data/predefined_tolls.dart

import 'package:latlong2/latlong.dart';
import 'dart:math';

// TollSegment importu burada gereksiz, kaldırılabilir eğer bu dosyada kullanılmıyorsa.
// import 'package:rotaapp/models/toll_segment.dart'; 

// Tek bir gişenin bilgisi
class TollGate {
  final String name;
  final LatLng coordinates;
  const TollGate(this.name, this.coordinates);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TollGate &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

// Tüm bilinen otoyol ve köprü gişelerinin listesi
const List<TollGate> allTollGates = [
  // ... (allTollGates listeniz olduğu gibi kalacak, önceki mesajlardaki gibi) ...
  // O-4 Ankara-İstanbul Otoyolu Gişeleri (Önemli giriş/çıkışlar)
  TollGate('ABANT Gişeleri', LatLng(40.7188074, 31.4716456)),
  TollGate('ADANA BATI ALIN Gişeleri', LatLng(37.0466566, 35.1547182)),
  TollGate('ADANA DOĞU ALIN Gişeleri', LatLng(37.0088966, 35.2673286)),
  TollGate('ADAPAZARI Gişeleri', LatLng(40.7132999, 30.3846092)),
  TollGate('AKINCI Gişeleri', LatLng(40.1162325, 32.6025533)),
  TollGate('AKYAZI Gişeleri', LatLng(40.7217809, 30.5650263)),
  TollGate('ALAÇATI Gişeleri', LatLng(38.2805252, 26.3797933)),
  TollGate('ANADOLU (ÇAMLICA) Gişeleri', LatLng(40.974114,29.175916)),
  TollGate('AVCILAR Gişeleri', LatLng(41.0499074, 28.6871674)),
  TollGate('AYDIN BATI Gişeleri', LatLng(37.8568785,27.7822933)),
  TollGate('BABAESKİ Gişeleri', LatLng(41.5011028, 27.1171478)),
  TollGate('BAHÇE Gişeleri', LatLng(37.1823438, 36.5106635)),
  TollGate('BATI HEREKE Gişeleri', LatLng(40.7778248, 29.595926)),
  TollGate('BATI İZMİT Gişeleri', LatLng(40.7636761, 29.8767629)),
  TollGate('BEKİRPAŞA Gişeleri',LatLng(40.7222453, 30.4519938)),
  TollGate('BELEVİ Gişeleri', LatLng(38.0283587, 27.4468498)),
  TollGate('BİRECİK Gişeleri', LatLng(37.0695617, 38.0143676)),
  TollGate('BOLU BATI Gişeleri', LatLng(40.7384057, 31.565295)),
  TollGate('CEYHAN Gişeleri', LatLng(36.9871973, 35.8303282)),
  TollGate('ÇAMALAN Gişeleri', LatLng(37.200268, 34.8160865)),
  TollGate('ÇAMTEPE Gişeleri', LatLng(37.0012084,34.9426603)),
  TollGate('ÇATALCA Gişeleri', LatLng(41.1639993, 28.4704829)),
  TollGate('ÇAYDURT Gişeleri', LatLng(40.757529,31.7613371)),
  TollGate('ÇELTİKÇİ (KIZILCAHAMAM) Gişeleri', LatLng(40.3322079, 32.494837)),
  TollGate('ÇERKEZKÖY Gişeleri', LatLng(41.1984039, 28.0837189)),
  TollGate('ÇEŞME Gişeleri', LatLng(38.2956677, 26.3103099)),
  TollGate('ÇORLU Gişeleri', LatLng(41.2256682, 27.8735947)),
  TollGate('DİL İSKELESİ Gişeleri', LatLng(40.7808655, 29.5267547)),
  TollGate('DOĞU HEREKE Gişeleri', LatLng(40.7863801, 29.6214398)),
  TollGate('DOĞU İZMİT Gişeleri', LatLng(40.7490547, 30.0368359)), // Bu gişe önemli
  TollGate('DÖRTYOL Gişeleri', LatLng(36.8550212, 36.225774)),
  TollGate('DÖRTDİVAN Gişeleri', LatLng(40.7422213, 32.1167535)),
  TollGate('DÜZCE (GÖLYAKA) Gişeleri', LatLng(40.8353105, 31.0409508)),
  TollGate('EDİRNE Gişeleri', LatLng(41.6607832, 26.6302495)),
  TollGate('EMİNLİK ALIN Gişeleri', LatLng(37.6476325,34.653156)),
  TollGate('ERZİN Gişeleri', LatLng(36.9615243, 36.1372199)),
  TollGate('ESENYURT Gişeleri', LatLng(41.0533631, 28.6746225)),
  TollGate('GAZİANTEP BATI ALIN Gişeleri', LatLng(37.2029512, 37.2635023)),
  TollGate('GAZİANTEP DOĞU Gişeleri', LatLng(37.0873962, 37.4570539)),
  TollGate('GEBZE Gişeleri', LatLng(40.8043038, 29.4741517)),
  TollGate('GEBZE ORG. SAN. BÖLGELERİ Gişeleri', LatLng(40.8542352, 29.3896354)),
  TollGate('GEREDE Gişeleri', LatLng(40.7492939, 32.1987083)),
  TollGate('GERMENCİK Gişeleri', LatLng(37.8780952,27.5755199)),
  TollGate('GÖLCÜK ALIN Gişeleri', LatLng(39.4456452, 30.9297168)),
  TollGate('HADIMKÖY Gişeleri', LatLng(41.0856742, 28.6318167)),
  TollGate('HAVSA Gişeleri', LatLng(41.6144094, 26.8460393)),
  TollGate('HENDEK Gişeleri', LatLng(40.7588415, 30.7179825)),
  TollGate('ISPARTAKULE Gişeleri', LatLng(41.0586331, 28.7095465)),
  TollGate('IŞIKKENT Gişeleri', LatLng(38.314216, 27.1839061)),
  TollGate('İSKENDERUN Gişeleri', LatLng(36.6348903, 36.2276552)),
  TollGate('K.BURGAZ Gişeleri', LatLng(41.2107721,28.8292368)),
  TollGate('KANDIRA Gişeleri', LatLng(40.77822, 29.9733602)),
  TollGate('KARABURUN Gişeleri', LatLng(38.3030722,26.6835171)),
  TollGate('KARTEPE Gişeleri', LatLng(40.7490768,30.0342459)),
  TollGate('KAYNAŞLI Gişeleri', LatLng(40.7839659, 31.2777247)),
  TollGate('KEMERHİSAR Gişeleri', LatLng(37.7794972, 34.6052794)),
  TollGate('KINALI Gişeleri', LatLng(41.1270832, 28.210508)),
  TollGate('KÖMÜRLER (NURDAĞI) Gişeleri', LatLng(37.1948174,36.7560674)),
  TollGate('KÖRFEZ Gişeleri', LatLng(40.7704471,29.7665331)),
  TollGate('KURTKÖY Gişeleri', LatLng(40.9324629, 29.3298804)),
  TollGate('KÜÇÜKKILIÇLI Gişeleri', LatLng(41.1262645,28.2022694)),
  TollGate('LİMAN Gişeleri', LatLng(38.9733135, 27.0535164)),
  TollGate('LÜLEBURGAZ Gişeleri', LatLng(41.4450011, 27.3885212)),
  TollGate('MAHMUTBEY Gişeleri', LatLng(41.0626882,28.7978771)),
  TollGate('MECİDİYE Gişeleri', LatLng(40.9540133, 29.3155172)),
  TollGate('MERSİN ALIN Gişeleri', LatLng(36.9162468,34.4030443)),
  TollGate('MUALLİMKÖY Gişeleri', LatLng(40.801117,29.4720454)),
  TollGate('NARLI Gişeleri', LatLng(37.2899819,37.1246214)),
  TollGate('NİĞDE GÜNEY Gişeleri', LatLng(37.9673224, 34.7107934)),
  TollGate('NİĞDE KUZEY Gişeleri', LatLng(38.0376378, 34.7449585)),
  TollGate('NİZİP Gişeleri', LatLng(37.0222683,37.8166941)),
  TollGate('ORHANLI Gişeleri', LatLng(40.9267278, 29.3439559)),
  TollGate('OSMANİYE Gişeleri', LatLng(37.1024632,36.2439675)),
  TollGate('PAYAS Gişeleri', LatLng(36.7426493,36.219296)),
  TollGate('PELİTÇİK (ÇAMLIDERE) Gişeleri', LatLng(40.4405421,32.4075771)),
  TollGate('POZANTI (GÜNEY) Gişeleri', LatLng(37.4119364, 34.8794912)),
  TollGate('POZANTI (KUZEY) Gişeleri', LatLng(37.4486948, 34.8783725)),
  TollGate('SAKIZGEDİĞİ Gişeleri', LatLng(37.1386376,36.1895598)),
  TollGate('SAMANDIRA Gişeleri', LatLng(40.974118,29.2114499)),
  TollGate('SAPANCA Gişeleri', LatLng(40.6865571, 30.2401813)),
  TollGate('SARAY Gişeleri', LatLng(41.3287352, 27.6845056)),
  TollGate('SEFERİHİSAR (GÜZELBAHÇE) Gişeleri', LatLng(38.3653432,26.8687301)),
  TollGate('SELİMPAŞA Gişeleri', LatLng(41.0614877, 28.3763058)),
  TollGate('SİLİVRİ Gişeleri', LatLng(41.1347119, 28.2901621)),
  TollGate('SULTANBEYLİ Gişeleri', LatLng(40.9703901, 29.2538485)),
  TollGate('SURUÇ Gişeleri',LatLng(37.1166438,38.4584796)),
  TollGate('Ş.PINAR Gişeleri',LatLng(40.867327,29.387068)),
  TollGate('ŞANLIURFA Gişeleri',LatLng(37.1525386,38.4648828)),
  TollGate('TAHTALIÇAY (HAVALİMANI) Gişeleri',LatLng(38.2726552,27.2145321)),
  TollGate('TARSUS Gişeleri', LatLng(36.9389183,34.8536392)),
  TollGate('TARSUS OSB Gişeleri', LatLng(36.9389183,34.8536392)),
  TollGate('TEKİR Gişeleri', LatLng(37.3272825, 34.7926289)),
  TollGate('TOPAĞAÇ Gişeleri',LatLng(40.7390117,30.6210753)),
  TollGate('TOPRAKKALE Gişeleri', LatLng(37.0783822,36.115757)),
  TollGate('TORBALI Gişeleri', LatLng(38.1942969,27.3354456)),
  TollGate('URLA Gişeleri', LatLng(38.3227772,26.7794131)),
  TollGate('YENİCE Gişeleri', LatLng(36.9788793,34.9714301)),
  TollGate('YENİÇAĞA Gişeleri', LatLng(40.7683402, 32.0086695)), // Bu gişe önemli
  TollGate('YUMURTALIK SERBEST BÖLGE Gişeleri', LatLng(36.9512608,35.9859806)),
  TollGate('ZEYTİNLER Gişeleri', LatLng(38.2850392,26.561545)),

  TollGate('Fatih Sultan Mehmet Köprüsü', LatLng(41.0857, 29.0966)),
  TollGate('15 Temmuz Şehitler Köprüsü', LatLng(41.0422, 29.0354)),
  TollGate('Yavuz Sultan Selim Köprüsü', LatLng(41.2000, 29.2700)),
  TollGate('Osmangazi Köprüsü', LatLng(40.7646, 29.5116)),
];

final Random _random = Random();

// Belirtilen aralıkta rastgele bir double değer üretir
// double _generateRandomCost(double min, double max) {
//   return min + (_random.nextDouble() * (max - min));
// }

// Hangi giriş gişesinden hangi çıkış gişesine ücretleri
Map<String, Map<String, double>> tollCostsMatrix = {
  // İstanbul - Ankara / Ankara - İstanbul Otoyolu (O-4) için bazı örnekler
  'ANADOLU (ÇAMLICA) Gişeleri': {
    'GEBZE Gişeleri': 20.0, // Rastgeleliği kaldırdım, test için sabit değerler daha iyi.
    'DOĞU İZMİT Gişeleri': 40.0,
    'ADAPAZARI Gişeleri': 50.0,
    'SAPANCA Gişeleri': 45.0,
    'AKYAZI Gişeleri': 55.0,
    'HENDEK Gişeleri': 60.0,
    'KAYNAŞLI Gişeleri': 80.0,
    'DÜZCE (GÖLYAKA) Gişeleri': 90.0,
    'BOLU BATI Gişeleri': 100.0,
    'ABANT Gişeleri': 105.0,
    'YENİÇAĞA Gişeleri': 110.0,
    'GEREDE Gişeleri': 120.0,
    'AKINCI Gişeleri': 150.0,
  },
  'AKINCI Gişeleri': {
    'GEREDE Gişeleri': 40.0,
    'BOLU BATI Gişeleri': 50.0,
    'DÜZCE (GÖLYAKA) Gişeleri': 60.0,
    'KAYNAŞLI Gişeleri': 70.0,
    'SAPANCA Gişeleri': 90.0,
    'ADAPAZARI Gişeleri': 95.0,
    'AKYAZI Gişeleri': 98.0,
    'HENDEK Gişeleri': 105.0,
    'DOĞU İZMİT Gişeleri': 110.0, // Burası YENİÇAĞA -> DOĞU İZMİT için değil, AKINCI -> DOĞU İZMİT
    'GEBZE Gişeleri': 120.0,
    'ANADOLU (ÇAMLICA) Gişeleri': 155.0,
    'Fatih Sultan Mehmet Köprüsü': 170.0,
    '15 Temmuz Şehitler Köprüsü': 175.0,
    'Yavuz Sultan Selim Köprüsü': 200.0,
  },

  // ***** YENİ EKLENEN GİRİŞ *****
  'YENİÇAĞA Gişeleri': {
    'DOĞU İZMİT Gişeleri': 65.0, 
    'ABANT Gişeleri': 10.0,
    'BOLU BATI Gişeleri': 20.0,
    'DÜZCE (GÖLYAKA) Gişeleri': 40.0,
    'KAYNAŞLI Gişeleri': 50.0,
    'HENDEK Gişeleri': 55.0,
    'AKYAZI Gişeleri': 60.0,
    'SAPANCA Gişeleri': 62.0,
    'ADAPAZARI Gişeleri': 63.0,
    'KANDIRA Gişeleri': 70.0,
    // ... ve İstanbul yönündeki diğer gişeler
  },
  // Ters yön için de ekleyelim
  'DOĞU İZMİT Gişeleri': {
    'YENİÇAĞA Gişeleri': 65.0, // Aynı maliyet veya farklı olabilir.
    // DOĞU İZMİT'ten diğer olası çıkışlar buraya eklenebilir...
    'GEBZE Gişeleri': 15.0,
    'ANADOLU (ÇAMLICA) Gişeleri': 40.0,
    // ... ve Ankara yönündeki diğer gişeler
    'ADAPAZARI Gişeleri': 10.0,
    'SAPANCA Gişeleri': 12.0,
    'AKYAZI Gişeleri': 20.0,
    'HENDEK Gişeleri': 25.0,
  },
  // ***** BİTTİ YENİ EKLENEN GİRİŞ *****

  'Osmangazi Köprüsü': {
     'ORHANGAZİ Gişeleri': 25.0,
     'BURSA KUZEY Gişeleri': 40.0,
  },
   'GEBZE Gişeleri': {
       'Osmangazi Köprüsü': 110.0,
       'DOĞU İZMİT Gişeleri': 15.0, // GEBZE -> DOĞU İZMİT eklendi
   },
   'EDİRNE Gişeleri': {
       'LÜLEBURGAZ Gişeleri': 30.0,
       'ÇORLU Gişeleri': 50.0,
       'MAHMUTBEY Gişeleri': 95.0,
   },
   // Diğer mevcut girişleriniz...
};

// const List<TollSegment> predefinedTollSegmentsOld = []; // Artık kullanılmıyor