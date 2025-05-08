import 'package:flutter/material.dart';
import '../data/placemarks/firestore_placemarks.dart';
import '../data/placemarks/placemark_model.dart';

class SportObjectsScreen extends StatefulWidget {
  const SportObjectsScreen({Key? key}) : super(key: key);

  @override
  State<SportObjectsScreen> createState() => _SportObjectsScreenState();
}

class _SportObjectsScreenState extends State<SportObjectsScreen> {
  final FirestorePlacemarks _firestorePlacemarks = FirestorePlacemarks();
  bool _isLoading = true;
  List<PlacemarkData> _sportObjects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSportObjects();
  }

  Future<void> _loadSportObjects() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final sportObjects = await _firestorePlacemarks.getSportObjects();

      setState(() {
        _sportObjects = sportObjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки данных: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Спортивные объекты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSportObjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSportObjects,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _sportObjects.isEmpty
                  ? const Center(
                      child: Text('Нет доступных спортивных объектов'))
                  : ListView.builder(
                      itemCount: _sportObjects.length,
                      itemBuilder: (context, index) {
                        final sportObject = _sportObjects[index];
                        return ListTile(
                          title: Text(sportObject.name),
                          subtitle: Text(sportObject.description),
                          trailing: Text(
                            '${sportObject.location.latitude.toStringAsFixed(4)}, '
                            '${sportObject.location.longitude.toStringAsFixed(4)}',
                          ),
                          onTap: () {
                            // Можно добавить переход на детальный экран
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Выбран объект: ${sportObject.name}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}
