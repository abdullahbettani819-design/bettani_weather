import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const BettaniWeatherApp());
}

class BettaniWeatherApp extends StatelessWidget {
  const BettaniWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bettani Weather',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF090D16),
      ),
      home: const WeatherHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherHomeScreen extends StatefulWidget {
  const WeatherHomeScreen({super.key});

  @override
  State<WeatherHomeScreen> createState() => _WeatherHomeScreenState();
}

class _WeatherHomeScreenState extends State<WeatherHomeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  bool isCelsius = true;

  String cityName = 'Jandola, Waziristan';
  double currentLat = 32.3056;
  double currentLon = 69.8736;
  double tempC = 0.0;
  double feelsLikeC = 0.0;
  String condition = '';
  String iconCode = '01d';
  double windSpeed = 0.0;
  int humidity = 0;
  int pressure = 0;
  double visibility = 0.0;
  String aqiStatus = 'Good (1)';
  String uvIndex = 'Moderate (4.5)';
  String clothingAdvice = 'Comfortable clothing recommended.';

  List<dynamic> hourlyList = [];
  List<dynamic> dailyList = [];

  List<String> favorites = [];
  List<String> searchHistory = [];
  bool showHistoryDropdown = false;

  final Map<String, Map<String, dynamic>> localDatabase = {
    "jandola": {"lat": 32.3056, "lon": 69.8736, "name": "Jandola, Waziristan"},
    "waziristan": {"lat": 32.5000, "lon": 69.7000, "name": "Waziristan"},
    "south waziristan": {"lat": 32.2500, "lon": 69.6000, "name": "South Waziristan"},
    "north waziristan": {"lat": 32.9500, "lon": 69.9000, "name": "North Waziristan"},
    "tank": {"lat": 32.2171, "lon": 70.3831, "name": "Tank"},
    "dera ismail khan": {"lat": 31.8313, "lon": 70.9016, "name": "Dera Ismail Khan"},
    "dik": {"lat": 31.8313, "lon": 70.9016, "name": "Dera Ismail Khan"},
  };

  final String apiKey = "84cb6e28261af3054b59f8fad3c6c93c";
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    fetchWeather("Jandola");
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favorites = prefs.getStringList('bettani_favs') ?? [];
      searchHistory = prefs.getStringList('bettani_hist') ?? [];
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bettani_favs', favorites);
    await prefs.setStringList('bettani_hist', searchHistory);
  }

  void addToHistory(String query) {
    if (!searchHistory.contains(query)) {
      searchHistory.insert(0, query);
      if (searchHistory.length > 5) searchHistory.removeLast();
      _savePreferences();
    }
  }

  void toggleFavorite() {
    setState(() {
      if (favorites.contains(cityName)) {
        favorites.remove(cityName);
      } else {
        favorites.add(cityName);
      }
      _savePreferences();
    });
  }

  String formatTemp(double celsius) {
    if (isCelsius) {
      return '${celsius.round()}°C';
    } else {
      return '${((celsius * 9/5) + 32).round()}°F';
    }
  }

  String getClothingAdvice(double temp, String cond) {
    if (temp < 10) return 'Heavy winter jacket and warm layers needed.';
    if (temp > 32) return 'Very hot! Wear light cotton clothes and stay hydrated.';
    if (cond.contains('rain') || cond.contains('shower')) return 'Carry an umbrella or raincoat!';
    return 'Pleasant weather. Light jacket or casual shirt is fine.';
  }

  Future<void> fetchWeather(String query) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      showHistoryDropdown = false;
    });

    try {
      String key = query.toLowerCase().trim();
      double lat, lon;

      if (localDatabase.containsKey(key)) {
        lat = localDatabase[key]!['lat'];
        lon = localDatabase[key]!['lon'];
        cityName = localDatabase[key]!['name'];
      } else {
        var geoUrl = Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$query&units=metric&appid=$apiKey');
        var geoRes = await http.get(geoUrl);
        if (geoRes.statusCode == 200) {
          var data = jsonDecode(geoRes.body);
          lat = data['coord']['lat'];
          lon = data['coord']['lon'];
          cityName = data['name'];
        } else {
          setState(() {
            errorMessage = 'Location unreachable. Verify spelling.';
            isLoading = false;
          });
          return;
        }
      }

      await fetchWeatherByCoords(lat, lon, customName: cityName);
    } catch (e) {
      setState(() {
        errorMessage = 'Network synchronization exception.';
        isLoading = false;
      });
    }
  }

  Future<void> fetchWeatherByCoords(double lat, double lon, {String? customName}) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      var weatherUrl = Uri.parse('https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey');
      var aqiUrl = Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey');
      var forecastUrl = Uri.parse('https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&units=metric&appid=$apiKey');

      var responses = await Future.wait([
        http.get(weatherUrl),
        http.get(aqiUrl),
        http.get(forecastUrl),
      ]);

      if (responses[0].statusCode == 200 && responses[2].statusCode == 200) {
        var data = jsonDecode(responses[0].body);
        var forecastData = jsonDecode(responses[2].body);

        if (customName != null) {
          cityName = customName;
        } else {
          cityName = data['name'] ?? 'Custom Coordinate Point';
        }
        
        String calculatedAqi = "Good (1)";
        if (responses[1].statusCode == 200) {
          var aqiJson = jsonDecode(responses[1].body);
          int aqiVal = aqiJson['list'][0]['main']['aqi'] ?? 1;
          List<String> aqiMap = ["", "Good (1)", "Fair (2)", "Moderate (3)", "Poor (4)", "Hazardous (5)"];
          calculatedAqi = aqiMap[aqiVal];
        }

        Map<String, dynamic> uniqueDays = {};
        for (var item in forecastData['list']) {
          String dateKey = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000).toIso8601String().substring(0, 10);
          if (!uniqueDays.containsKey(dateKey)) {
            uniqueDays[dateKey] = item;
          }
        }

        setState(() {
          currentLat = lat;
          currentLon = lon;
          tempC = data['main']['temp'].toDouble();
          feelsLikeC = data['main']['feels_like'].toDouble();
          condition = data['weather'][0]['description'];
          iconCode = data['weather'][0]['icon'];
          windSpeed = data['wind']['speed'].toDouble();
          humidity = data['main']['humidity'];
          pressure = data['main']['pressure'];
          visibility = (data['visibility'] / 1000).toDouble();
          aqiStatus = calculatedAqi;
          clothingAdvice = getClothingAdvice(tempC, condition);

          hourlyList = forecastData['list'].sublist(0, 10);
          dailyList = uniqueDays.values.toList();
          isLoading = false;
        });

        try {
          _mapController.move(LatLng(currentLat, currentLon), 11.0);
        } catch (_) {}

        addToHistory(cityName);
      } else {
        setState(() {
          errorMessage = 'Failed to load coordinate weather stream.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch coordinate weather data.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFav = favorites.contains(cityName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bettani Weather', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Text(isCelsius ? '°F' : '°C', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
            onPressed: () => setState(() => isCelsius = !isCelsius),
            tooltip: 'Toggle Unit',
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onTap: () => setState(() => showHistoryDropdown = searchHistory.isNotEmpty),
                          onChanged: (val) => setState(() => showHistoryDropdown = val.isNotEmpty && searchHistory.isNotEmpty),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search city or village (e.g. Jandola)...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: () {
                          if (_controller.text.isNotEmpty) {
                            fetchWeather(_controller.text);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF43F5E),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Search', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: toggleFavorite,
                        tooltip: 'Favorite City',
                      ),
                    ],
                  ),

                  if (favorites.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          String fav = favorites[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(fav, style: const TextStyle(fontSize: 10)),
                              backgroundColor: Colors.white.withOpacity(0.06),
                              onPressed: () => fetchWeather(fav),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(50.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
                    )
                  else if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(errorMessage, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.035),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            cityName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Image.network(
                            'https://openweathermap.org/img/wn/$iconCode@4x.png',
                            width: 70,
                            height: 70,
                            errorBuilder: (c, e, s) => const Icon(Icons.wb_sunny, size: 50, color: Colors.amber),
                          ),
                          Text(
                            formatTemp(tempC),
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300),
                          ),
                          Text(
                            condition.toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Feels like: ${formatTemp(feelsLikeC)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.checkroom, color: Color(0xFF38BDF8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              clothingAdvice,
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Advanced Interactive GIS Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        Text('Tap anywhere to query', style: TextStyle(fontSize: 9, color: Colors.pinkAccent.shade200)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(currentLat, currentLon),
                            initialZoom: 10.0,
                            onTap: (tapPosition, latLng) {
                              fetchWeatherByCoords(latLng.latitude, latLng.longitude, customName: 'Lat: ${latLng.latitude.toStringAsFixed(2)}, Lon: ${latLng.longitude.toStringAsFixed(2)}');
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.bettani.weather',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(currentLat, currentLon),
                                  width: 80,
                                  height: 80,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Color(0xFFF43F5E),
                                    size: 45,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 1.3,
                      children: [
                        metricBox('AQI Status', aqiStatus),
                        metricBox('UV Index', uvIndex),
                        metricBox('Humidity', '$humidity%'),
                        metricBox('Wind Speed', '$windSpeed km/h'),
                        metricBox('Pressure', '$pressure hPa'),
                        metricBox('Visibility', '$visibility km'),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text('Hourly Atmospheric Progression', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),

                    SizedBox(
                      height: 95,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: hourlyList.length,
                        itemBuilder: (context, index) {
                          var item = hourlyList[index];
                          String timeStr = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000)
                              .toLocal()
                              .toString()
                              .substring(11, 16);
                          String hIcon = item['weather'][0]['icon'];
                          double hTemp = item['main']['temp'].toDouble();

                          return Container(
                            width: 65,
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(timeStr, style: const TextStyle(fontSize: 9, color: Color(0xFF38BDF8))),
                                Image.network('https://openweathermap.org/img/wn/$hIcon.png', width: 28, height: 28),
                                Text(formatTemp(hTemp), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Extended Outlook Matrix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dailyList.length,
                      itemBuilder: (context, index) {
                        var item = dailyList[index];
                        String dayStr = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000)
                            .toLocal()
                            .toString()
                            .substring(0, 10);
                        String dDesc = item['weather'][0]['description'];
                        double dTemp = item['main']['temp'].toDouble();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white.withOpacity(0.03)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dayStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                              Text(dDesc, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                              Text(formatTemp(dTemp), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (showHistoryDropdown)
            Positioned(
              top: 55,
              left: 14,
              right: 75,
              child: Material(
                color: const Color(0xFF0F172A),
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: searchHistory.length,
                  itemBuilder: (context, index) {
                    String hist = searchHistory[index];
                    return ListTile(
                      dense: true,
                      title: Text(hist, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      onTap: () {
                        _controller.text = hist;
                        fetchWeather(hist);
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget metricBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
