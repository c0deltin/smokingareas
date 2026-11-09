import 'package:latlong2/latlong.dart';

/// Popular districts (Viertel) shown as quick jump targets in the city
/// picker. Selecting one loads the parent city and zooms in on the district.
class District {
  const District({
    required this.cityId,
    required this.name,
    required this.nameJa,
    required this.center,
    this.ward,
    this.zoom = 16,
  });

  final String cityId;
  final String name;
  final String nameJa;

  /// Tokyo special ward / city ward the district belongs to.
  final String? ward;
  final LatLng center;
  final double zoom;
}

const List<District> kDistricts = [
  // Tokyo
  District(cityId: 'tokyo', name: 'Shinjuku', nameJa: '新宿', ward: 'Shinjuku', center: LatLng(35.6909, 139.7003)),
  District(cityId: 'tokyo', name: 'Shibuya', nameJa: '渋谷', ward: 'Shibuya', center: LatLng(35.6580, 139.7016)),
  District(cityId: 'tokyo', name: 'Ikebukuro', nameJa: '池袋', ward: 'Toshima', center: LatLng(35.7295, 139.7109)),
  District(cityId: 'tokyo', name: 'Akihabara', nameJa: '秋葉原', ward: 'Chiyoda', center: LatLng(35.6984, 139.7731)),
  District(cityId: 'tokyo', name: 'Kanda', nameJa: '神田', ward: 'Chiyoda', center: LatLng(35.6918, 139.7709)),
  District(cityId: 'tokyo', name: 'Jimbōchō / Kudanshita', nameJa: '神保町・九段下', ward: 'Chiyoda', center: LatLng(35.6959, 139.7545)),
  District(cityId: 'tokyo', name: 'Tokyo Station / Marunouchi', nameJa: '東京駅・丸の内', ward: 'Chiyoda', center: LatLng(35.6812, 139.7671)),
  District(cityId: 'tokyo', name: 'Ueno', nameJa: '上野', ward: 'Taitō', center: LatLng(35.7138, 139.7773)),
  District(cityId: 'tokyo', name: 'Asakusa', nameJa: '浅草', ward: 'Taitō', center: LatLng(35.7118, 139.7966)),
  District(cityId: 'tokyo', name: 'Ginza', nameJa: '銀座', ward: 'Chūō', center: LatLng(35.6717, 139.7650)),
  District(cityId: 'tokyo', name: 'Shimbashi', nameJa: '新橋', ward: 'Minato', center: LatLng(35.6663, 139.7583)),
  District(cityId: 'tokyo', name: 'Roppongi', nameJa: '六本木', ward: 'Minato', center: LatLng(35.6628, 139.7314)),
  District(cityId: 'tokyo', name: 'Harajuku / Omotesandō', nameJa: '原宿・表参道', ward: 'Shibuya', center: LatLng(35.6690, 139.7055)),
  District(cityId: 'tokyo', name: 'Ebisu', nameJa: '恵比寿', ward: 'Shibuya', center: LatLng(35.6467, 139.7101)),
  District(cityId: 'tokyo', name: 'Takadanobaba', nameJa: '高田馬場', ward: 'Shinjuku', center: LatLng(35.7126, 139.7038)),
  District(cityId: 'tokyo', name: 'Shinagawa', nameJa: '品川', ward: 'Minato', center: LatLng(35.6285, 139.7387)),
  District(cityId: 'tokyo', name: 'Kameido / Tōyōchō', nameJa: '亀戸・東陽町', ward: 'Kōtō', center: LatLng(35.6850, 139.8180), zoom: 14),
  // Osaka
  District(cityId: 'osaka', name: 'Umeda / Osaka Station', nameJa: '梅田・大阪駅', center: LatLng(34.7025, 135.4959)),
  District(cityId: 'osaka', name: 'Namba / Dōtonbori', nameJa: '難波・道頓堀', center: LatLng(34.6670, 135.5010)),
  District(cityId: 'osaka', name: 'Shinsaibashi', nameJa: '心斎橋', center: LatLng(34.6745, 135.5007)),
  District(cityId: 'osaka', name: 'Tennōji', nameJa: '天王寺', center: LatLng(34.6466, 135.5135)),
  District(cityId: 'osaka', name: 'Shin-Ōsaka', nameJa: '新大阪', center: LatLng(34.7334, 135.5001)),
  // Kyoto
  District(cityId: 'kyoto', name: 'Kyoto Station', nameJa: '京都駅', center: LatLng(34.9858, 135.7588)),
  District(cityId: 'kyoto', name: 'Kawaramachi / Gion', nameJa: '河原町・祇園', center: LatLng(35.0037, 135.7710)),
  District(cityId: 'kyoto', name: 'Kiyomizu-dera', nameJa: '清水寺', center: LatLng(34.9960, 135.7810)),
  // Okayama
  District(cityId: 'okayama', name: 'Okayama Station', nameJa: '岡山駅', center: LatLng(34.6664, 133.9180)),
  District(cityId: 'okayama', name: 'Omotechō', nameJa: '表町', center: LatLng(34.6627, 133.9300)),
];
