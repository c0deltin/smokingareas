import 'package:latlong2/latlong.dart';

import '../models/city.dart';

/// All major cities in Japan covered by the app: Tokyo (23 wards + Tama
/// core), all 20 designated cities (政令指定都市) and the remaining
/// prefectural capitals / large tourist cities.
///
/// The radius describes the area downloaded from the data sources. It is
/// chosen to cover the urban core where public smoking areas actually exist,
/// while keeping Overpass queries reasonably small.
const List<City> kCities = [
  // --- Kantō -------------------------------------------------------------
  City(id: 'tokyo', name: 'Tokyo (23 Bezirke)', nameJa: '東京23区', prefecture: 'Tokyo', center: LatLng(35.6812, 139.7671), radiusKm: 16, zoom: 12),
  City(id: 'tokyo_tama', name: 'Tokyo Tama (Hachiōji/Tachikawa)', nameJa: '多摩', prefecture: 'Tokyo', center: LatLng(35.6800, 139.3900), radiusKm: 14, zoom: 12),
  City(id: 'yokohama', name: 'Yokohama', nameJa: '横浜市', prefecture: 'Kanagawa', center: LatLng(35.4660, 139.6220), radiusKm: 13),
  City(id: 'kawasaki', name: 'Kawasaki', nameJa: '川崎市', prefecture: 'Kanagawa', center: LatLng(35.5600, 139.6300), radiusKm: 10),
  City(id: 'sagamihara', name: 'Sagamihara', nameJa: '相模原市', prefecture: 'Kanagawa', center: LatLng(35.5710, 139.3730), radiusKm: 8),
  City(id: 'saitama', name: 'Saitama', nameJa: 'さいたま市', prefecture: 'Saitama', center: LatLng(35.8617, 139.6455), radiusKm: 10),
  City(id: 'chiba', name: 'Chiba', nameJa: '千葉市', prefecture: 'Chiba', center: LatLng(35.6074, 140.1065), radiusKm: 10),
  City(id: 'utsunomiya', name: 'Utsunomiya', nameJa: '宇都宮市', prefecture: 'Tochigi', center: LatLng(36.5551, 139.8828), radiusKm: 7),
  City(id: 'maebashi', name: 'Maebashi / Takasaki', nameJa: '前橋市・高崎市', prefecture: 'Gunma', center: LatLng(36.3600, 139.0300), radiusKm: 10),
  City(id: 'mito', name: 'Mito', nameJa: '水戸市', prefecture: 'Ibaraki', center: LatLng(36.3707, 140.4760), radiusKm: 6),

  // --- Hokkaidō / Tōhoku -------------------------------------------------
  City(id: 'sapporo', name: 'Sapporo', nameJa: '札幌市', prefecture: 'Hokkaido', center: LatLng(43.0618, 141.3545), radiusKm: 12),
  City(id: 'sendai', name: 'Sendai', nameJa: '仙台市', prefecture: 'Miyagi', center: LatLng(38.2601, 140.8822), radiusKm: 9),
  City(id: 'aomori', name: 'Aomori', nameJa: '青森市', prefecture: 'Aomori', center: LatLng(40.8246, 140.7406), radiusKm: 6),
  City(id: 'morioka', name: 'Morioka', nameJa: '盛岡市', prefecture: 'Iwate', center: LatLng(39.7036, 141.1527), radiusKm: 6),
  City(id: 'akita', name: 'Akita', nameJa: '秋田市', prefecture: 'Akita', center: LatLng(39.7186, 140.1024), radiusKm: 6),
  City(id: 'yamagata', name: 'Yamagata', nameJa: '山形市', prefecture: 'Yamagata', center: LatLng(38.2554, 140.3396), radiusKm: 6),
  City(id: 'fukushima', name: 'Fukushima / Kōriyama', nameJa: '福島市・郡山市', prefecture: 'Fukushima', center: LatLng(37.5000, 140.4300), radiusKm: 18, zoom: 11),

  // --- Chūbu ------------------------------------------------------------
  City(id: 'nagoya', name: 'Nagoya', nameJa: '名古屋市', prefecture: 'Aichi', center: LatLng(35.1709, 136.8815), radiusKm: 12),
  City(id: 'niigata', name: 'Niigata', nameJa: '新潟市', prefecture: 'Niigata', center: LatLng(37.9122, 139.0614), radiusKm: 8),
  City(id: 'shizuoka', name: 'Shizuoka', nameJa: '静岡市', prefecture: 'Shizuoka', center: LatLng(34.9756, 138.3828), radiusKm: 8),
  City(id: 'hamamatsu', name: 'Hamamatsu', nameJa: '浜松市', prefecture: 'Shizuoka', center: LatLng(34.7038, 137.7349), radiusKm: 8),
  City(id: 'kanazawa', name: 'Kanazawa', nameJa: '金沢市', prefecture: 'Ishikawa', center: LatLng(36.5780, 136.6480), radiusKm: 7),
  City(id: 'toyama', name: 'Toyama', nameJa: '富山市', prefecture: 'Toyama', center: LatLng(36.7013, 137.2133), radiusKm: 6),
  City(id: 'fukui', name: 'Fukui', nameJa: '福井市', prefecture: 'Fukui', center: LatLng(36.0620, 136.2230), radiusKm: 6),
  City(id: 'kofu', name: 'Kōfu', nameJa: '甲府市', prefecture: 'Yamanashi', center: LatLng(35.6664, 138.5686), radiusKm: 6),
  City(id: 'nagano', name: 'Nagano / Matsumoto', nameJa: '長野市・松本市', prefecture: 'Nagano', center: LatLng(36.4500, 138.0700), radiusKm: 22, zoom: 11),
  City(id: 'gifu', name: 'Gifu', nameJa: '岐阜市', prefecture: 'Gifu', center: LatLng(35.4093, 136.7568), radiusKm: 6),

  // --- Kansai -------------------------------------------------------------
  City(id: 'osaka', name: 'Osaka', nameJa: '大阪市', prefecture: 'Osaka', center: LatLng(34.6937, 135.5023), radiusKm: 11),
  City(id: 'sakai', name: 'Sakai', nameJa: '堺市', prefecture: 'Osaka', center: LatLng(34.5733, 135.4830), radiusKm: 7),
  City(id: 'kyoto', name: 'Kyoto', nameJa: '京都市', prefecture: 'Kyoto', center: LatLng(35.0050, 135.7600), radiusKm: 9),
  City(id: 'kobe', name: 'Kobe', nameJa: '神戸市', prefecture: 'Hyogo', center: LatLng(34.6901, 135.1955), radiusKm: 10),
  City(id: 'himeji', name: 'Himeji', nameJa: '姫路市', prefecture: 'Hyogo', center: LatLng(34.8268, 134.6907), radiusKm: 6),
  City(id: 'nara', name: 'Nara', nameJa: '奈良市', prefecture: 'Nara', center: LatLng(34.6851, 135.8048), radiusKm: 6),
  City(id: 'otsu', name: 'Ōtsu', nameJa: '大津市', prefecture: 'Shiga', center: LatLng(35.0045, 135.8686), radiusKm: 6),
  City(id: 'wakayama', name: 'Wakayama', nameJa: '和歌山市', prefecture: 'Wakayama', center: LatLng(34.2260, 135.1675), radiusKm: 6),
  City(id: 'tsu', name: 'Tsu / Yokkaichi', nameJa: '津市・四日市市', prefecture: 'Mie', center: LatLng(34.8500, 136.5500), radiusKm: 14, zoom: 11),

  // --- Chūgoku / Shikoku -------------------------------------------------
  City(id: 'hiroshima', name: 'Hiroshima', nameJa: '広島市', prefecture: 'Hiroshima', center: LatLng(34.3853, 132.4553), radiusKm: 9),
  City(id: 'okayama', name: 'Okayama', nameJa: '岡山市', prefecture: 'Okayama', center: LatLng(34.6618, 133.9350), radiusKm: 8),
  City(id: 'matsue', name: 'Matsue', nameJa: '松江市', prefecture: 'Shimane', center: LatLng(35.4723, 133.0505), radiusKm: 6),
  City(id: 'tottori', name: 'Tottori', nameJa: '鳥取市', prefecture: 'Tottori', center: LatLng(35.5011, 134.2351), radiusKm: 6),
  City(id: 'yamaguchi', name: 'Yamaguchi / Shimonoseki', nameJa: '山口市・下関市', prefecture: 'Yamaguchi', center: LatLng(34.0500, 131.1500), radiusKm: 30, zoom: 10),
  City(id: 'takamatsu', name: 'Takamatsu', nameJa: '高松市', prefecture: 'Kagawa', center: LatLng(34.3428, 134.0466), radiusKm: 6),
  City(id: 'matsuyama', name: 'Matsuyama', nameJa: '松山市', prefecture: 'Ehime', center: LatLng(33.8392, 132.7657), radiusKm: 7),
  City(id: 'tokushima', name: 'Tokushima', nameJa: '徳島市', prefecture: 'Tokushima', center: LatLng(34.0703, 134.5548), radiusKm: 6),
  City(id: 'kochi', name: 'Kōchi', nameJa: '高知市', prefecture: 'Kochi', center: LatLng(33.5597, 133.5311), radiusKm: 6),

  // --- Kyūshū / Okinawa --------------------------------------------------
  City(id: 'fukuoka', name: 'Fukuoka', nameJa: '福岡市', prefecture: 'Fukuoka', center: LatLng(33.5902, 130.4017), radiusKm: 10),
  City(id: 'kitakyushu', name: 'Kitakyūshū', nameJa: '北九州市', prefecture: 'Fukuoka', center: LatLng(33.8835, 130.8752), radiusKm: 10),
  City(id: 'kumamoto', name: 'Kumamoto', nameJa: '熊本市', prefecture: 'Kumamoto', center: LatLng(32.8031, 130.7079), radiusKm: 8),
  City(id: 'kagoshima', name: 'Kagoshima', nameJa: '鹿児島市', prefecture: 'Kagoshima', center: LatLng(31.5966, 130.5571), radiusKm: 7),
  City(id: 'nagasaki', name: 'Nagasaki', nameJa: '長崎市', prefecture: 'Nagasaki', center: LatLng(32.7503, 129.8777), radiusKm: 6),
  City(id: 'oita', name: 'Ōita / Beppu', nameJa: '大分市・別府市', prefecture: 'Oita', center: LatLng(33.2700, 131.5600), radiusKm: 10),
  City(id: 'miyazaki', name: 'Miyazaki', nameJa: '宮崎市', prefecture: 'Miyazaki', center: LatLng(31.9077, 131.4202), radiusKm: 6),
  City(id: 'saga', name: 'Saga', nameJa: '佐賀市', prefecture: 'Saga', center: LatLng(33.2635, 130.3009), radiusKm: 6),
  City(id: 'naha', name: 'Naha', nameJa: '那覇市', prefecture: 'Okinawa', center: LatLng(26.2124, 127.6809), radiusKm: 8),
];

City? cityById(String id) {
  for (final c in kCities) {
    if (c.id == id) return c;
  }
  return null;
}

/// The city whose download area contains [p], preferring the closest centre
/// when areas overlap (e.g. Tokyo / Kawasaki / Yokohama).
City? cityForPosition(LatLng p) {
  const distance = Distance();
  City? best;
  double bestDist = double.infinity;
  for (final c in kCities) {
    if (!c.contains(p)) continue;
    final d = distance(p, c.center);
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }
  return best;
}

/// All cities whose download area contains [p].
List<City> citiesContaining(LatLng p) =>
    kCities.where((c) => c.contains(p)).toList();
