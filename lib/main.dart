import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(NewsApp());
}

class NewsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Российские Новости',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
        scaffoldBackgroundColor: Color(0xFF121212), // Темный фон
      ),
      home: NewsListScreen(),
    );
  }
}

class NewsListScreen extends StatefulWidget {
  @override
  _NewsListScreenState createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  List<dynamic> originalNewsList = [];
  List<dynamic> newsList = [];
  bool isLoading = true;
  bool isDescending = true;
  bool _isOfflineMode = false;
  String apiUrl =
      'http://api.mediastack.com/v1/news?countries=ru&languages=ru&access_key=05560bb1d8d68e7c58c76ad9a75a2750';

  TextEditingController dateFromController = TextEditingController();
  TextEditingController dateToController = TextEditingController();
  TextEditingController titleController = TextEditingController();
  TextEditingController sourceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> saveNews(List<dynamic> news) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('savedNews', jsonEncode(news));
  }

  Future<List<dynamic>> loadSavedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedNews = prefs.getString('savedNews');
    if (savedNews != null) {
      return jsonDecode(savedNews);
    }
    return [];
  }

  Future<void> fetchNews() async {
    if (_isOfflineMode) {
      List<dynamic> savedNews = await loadSavedNews();
      setState(() {
        originalNewsList = savedNews;
        newsList = List.from(originalNewsList);
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          originalNewsList = data['data'];
          newsList = List.from(originalNewsList);
          isLoading = false;
        });
        await saveNews(originalNewsList);
      } else {
        print('Ошибка загрузки новостей');
      }
    } catch (e) {
      print('Нет подключения к интернету: $e');
      List<dynamic> savedNews = await loadSavedNews();
      setState(() {
        originalNewsList = savedNews;
        newsList = List.from(originalNewsList);
        isLoading = false;
      });
    }
  }

  void sortByDate() {
    setState(() {
      isDescending = !isDescending;
      newsList.sort((a, b) => isDescending
          ? DateTime.parse(b['published_at']).compareTo(DateTime.parse(a['published_at']))
          : DateTime.parse(a['published_at']).compareTo(DateTime.parse(b['published_at'])));
    });
  }

  void filterByDateAndSource() {
    String dateFrom = dateFromController.text;
    String dateTo = dateToController.text;
    String sourceQuery = sourceController.text.toLowerCase();

    setState(() {
      newsList = originalNewsList.where((news) {
        bool matchesSource = true;
        bool matchesDate = true;

        if (sourceQuery.isNotEmpty) {
          matchesSource = news['source'].toLowerCase().contains(sourceQuery);
        }

        if (dateFrom.isNotEmpty) {
          DateTime fromDate = DateFormat('dd.MM.yyyy').parse(dateFrom);
          if (dateTo.isNotEmpty) {
            DateTime toDate = DateFormat('dd.MM.yyyy').parse(dateTo);
            DateTime newsDate = DateTime.parse(news['published_at']);
            matchesDate = (newsDate.isAfter(fromDate) || newsDate.isAtSameMomentAs(fromDate)) &&
                          (newsDate.isBefore(toDate) || newsDate.isAtSameMomentAs(toDate));
          } else {
            DateTime newsDate = DateTime.parse(news['published_at']);
            matchesDate = newsDate.isAfter(fromDate) || newsDate.isAtSameMomentAs(fromDate);
          }
        } else if (dateTo.isNotEmpty) {
          DateTime toDate = DateFormat('dd.MM.yyyy').parse(dateTo);
          DateTime newsDate = DateTime.parse(news['published_at']);
          matchesDate = newsDate.isBefore(toDate) || newsDate.isAtSameMomentAs(toDate);
        }

        return matchesSource && matchesDate;
      }).toList();
    });
  }

  void filterByTitle() {
    String titleQuery = titleController.text.toLowerCase();

    setState(() {
      newsList = originalNewsList.where((news) {
        return news['title'].toLowerCase().contains(titleQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Новости'),
        actions: [
          Row(
            children: [
              
              Switch(
                value: _isOfflineMode,
                onChanged: (value) {
                  setState(() {
                    _isOfflineMode = value;
                    fetchNews();
                  });
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchNews,
            tooltip: 'Обновить новости',
          ),
          IconButton(
            icon: Icon(Icons.sort, color: Colors.white),
            onPressed: sortByDate,
            tooltip: 'Сортировка по дате',
          ),
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => filterByDateAndSourceDialog(),
            tooltip: 'Фильтрация по дате и источнику',
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () => filterByTitleDialog(),
            tooltip: 'Фильтрация по названию',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: newsList.length,
              itemBuilder: (context, index) {
                final news = newsList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: const Color.fromARGB(255, 255, 123, 0),
                  child: ListTile(
                    title: Text(
                      news['title'] ?? 'Без заголовка',
                      style: TextStyle(fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 0, 0)),
                    ),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy').format(DateTime.parse(news['published_at'])) +
                      ' | Источник: ${news['source']}',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewsDetailScreen(news: news),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> filterByDateAndSourceDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Фильтрация по дате и источнику', style: TextStyle(color: Colors.orange)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: sourceController,
                  decoration: InputDecoration(labelText: 'Источник'),
                ),
                TextField(
                  controller: dateFromController,
                  decoration: InputDecoration(labelText: 'Дата от (дд.мм.гггг)'),
                  keyboardType: TextInputType.datetime,
                ),
                TextField(
                  controller: dateToController,
                  decoration: InputDecoration(labelText: 'Дата до (дд.мм.гггг)'),
                  keyboardType: TextInputType.datetime,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Фильтровать', style: TextStyle(color: Colors.orange)),
              onPressed: () {
                filterByDateAndSource();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> filterByTitleDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Фильтрация по названию', style: TextStyle(color: Colors.orange)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Название новости'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Фильтровать', style: TextStyle(color: Colors.orange)),
              onPressed: () {
                filterByTitle();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  final dynamic news;

  NewsDetailScreen({required this.news});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(news['title'] ?? 'Без заголовка'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(news['title'] ?? 'Без заголовка',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
            SizedBox(height: 10),
            Text(
              DateFormat('dd.MM.yyyy').format(DateTime.parse(news['published_at'])),
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 20),
            Text(news['description'] ?? 'Описание отсутствует', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
