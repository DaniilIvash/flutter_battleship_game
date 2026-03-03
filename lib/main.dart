// main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

// Модель данных для статистики
class GameStats {
  final String date;
  final String winner;
  final int moves;

  GameStats({
    required this.date,
    required this.winner,
    required this.moves,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'winner': winner,
    'moves': moves,
  };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
    date: json['date'],
    winner: json['winner'],
    moves: json['moves'],
  );
}

// Сервис для работы с файлом статистики
class GameStatsService {
  Future<File> _getStatsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final statsDir = Directory('${directory.path}/game_stats');
    if (!await statsDir.exists()) {
      await statsDir.create(recursive: true);
    }
    return File('${statsDir.path}/game_stats.json');
  }

  Future<List<GameStats>> readStats() async {
    try {
      final file = await _getStatsFile();
      if (await file.exists()) {
        final jsonData = await file.readAsString();
        final List<dynamic> statsList = jsonDecode(jsonData)['games'];
        return statsList.map((stat) => GameStats.fromJson(stat)).toList();
      }
    } catch (e) {
      print('Ошибка чтения статистики: $e');
    }
    return [];
  }

  Future<void> saveStats(List<GameStats> stats) async {
    final file = await _getStatsFile();
    final jsonData = jsonEncode({'games': stats.map((stat) => stat.toJson()).toList()});
    await file.writeAsString(jsonData);
  }
}

// Логика игры
class GameLogic {
  final GameStatsService statsService = GameStatsService();
  final StreamController<List<GameStats>> _statsController = StreamController<List<GameStats>>.broadcast();

  Stream<List<GameStats>> get statsStream => _statsController.stream;

  Future<void> saveGameResult(String winner, int moves) async {
    final newStat = GameStats(
      date: DateTime.now().toString(),
      winner: winner,
      moves: moves,
    );
    final currentStats = await statsService.readStats();
    currentStats.add(newStat);
    await statsService.saveStats(currentStats);
    _statsController.add(currentStats);
  }

  void dispose() {
    _statsController.close();
  }
}

// Виджет пиксельного игрового поля
class PixelBattleshipField extends StatefulWidget {
  final bool isPlayerField;
  final bool isPlacingShips;
  final List<List<String>> field;
  final Function(int, int)? onTap;

  const PixelBattleshipField({
    Key? key,
    required this.isPlayerField,
    required this.isPlacingShips,
    required this.field,
    this.onTap,
  }) : super(key: key);

  @override
  _PixelBattleshipFieldState createState() => _PixelBattleshipFieldState();
}

class _PixelBattleshipFieldState extends State<PixelBattleshipField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
        ),
        itemCount: 100,
        itemBuilder: (context, index) {
          final row = index ~/ 10;
          final col = index % 10;
          final cell = widget.field[row][col];
          Color cellColor;
          if (cell == 'ship' && widget.isPlayerField) {
            cellColor = Colors.blue;
          } else if (cell == 'hit') {
            cellColor = Colors.red;
          } else if (cell == 'miss') {
            cellColor = Colors.grey;
          } else {
            cellColor = Colors.white;
          }
          return GestureDetector(
            onTap: () => widget.onTap?.call(row, col),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: cellColor,
                border: Border.all(color: Colors.black, width: 0.5),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Основной экран
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GameLogic gameLogic = GameLogic();
  bool isPlayerVsPlayer = false;
  bool isPlacingShips = true;
  int shipsToPlace = 10;
  int currentPlayer = 1;
  int moves = 0;
  String gameStatus = 'Выберите режим игры';
  bool isThinking = false;

  List<List<String>> player1Field = List.generate(10, (_) => List.generate(10, (_) => 'empty'));
  List<List<String>> player2Field = List.generate(10, (_) => List.generate(10, (_) => 'empty'));

  // Список кораблей: 1x4, 2x3, 3x2, 4x1
  final List<int> shipSizes = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
  int currentShipIndex = 0;
  bool isHorizontal = true;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    player1Field = List.generate(10, (_) => List.generate(10, (_) => 'empty'));
    player2Field = List.generate(10, (_) => List.generate(10, (_) => 'empty'));
  }

  void _placeShip(int row, int col) {
    if (!isPlacingShips || shipsToPlace <= 0) return;

    int shipSize = shipSizes[currentShipIndex];
    bool canPlaceShip = true;

    if (isHorizontal) {
      if (col + shipSize > 10) {
        canPlaceShip = false;
      } else {
        for (int i = 0; i < shipSize; i++) {
          if (player1Field[row][col + i] != 'empty') {
            canPlaceShip = false;
            break;
          }
        }
      }
    } else {
      if (row + shipSize > 10) {
        canPlaceShip = false;
      } else {
        for (int i = 0; i < shipSize; i++) {
          if (player1Field[row + i][col] != 'empty') {
            canPlaceShip = false;
            break;
          }
        }
      }
    }

    if (canPlaceShip) {
      setState(() {
        if (isHorizontal) {
          for (int i = 0; i < shipSize; i++) {
            player1Field[row][col + i] = 'ship';
          }
        } else {
          for (int i = 0; i < shipSize; i++) {
            player1Field[row + i][col] = 'ship';
          }
        }
        currentShipIndex++;
        shipsToPlace--;
        if (shipsToPlace == 0) {
          isPlacingShips = false;
          gameStatus = isPlayerVsPlayer ? 'Игрок 2, разместите корабли' : 'Начните стрельбу!';
          if (!isPlayerVsPlayer) {
            _placeComputerShips();
          }
        }
      });
    }
  }

  void _placeComputerShips() {
    final Random random = Random();
    for (int size in shipSizes) {
      bool placed = false;
      while (!placed) {
        bool horizontal = random.nextBool();
        int row = random.nextInt(10);
        int col = random.nextInt(10);

        if (horizontal) {
          if (col + size <= 10) {
            bool canPlace = true;
            for (int i = 0; i < size; i++) {
              if (player2Field[row][col + i] != 'empty') {
                canPlace = false;
                break;
              }
            }
            if (canPlace) {
              for (int i = 0; i < size; i++) {
                player2Field[row][col + i] = 'ship';
              }
              placed = true;
            }
          }
        } else {
          if (row + size <= 10) {
            bool canPlace = true;
            for (int i = 0; i < size; i++) {
              if (player2Field[row + i][col] != 'empty') {
                canPlace = false;
                break;
              }
            }
            if (canPlace) {
              for (int i = 0; i < size; i++) {
                player2Field[row + i][col] = 'ship';
              }
              placed = true;
            }
          }
        }
      }
    }
  }

  void _shoot(int row, int col) {
    if (isPlacingShips || isThinking) return;

    setState(() {
      moves++;
      if (currentPlayer == 1) {
        if (player2Field[row][col] == 'ship') {
          player2Field[row][col] = 'hit';
          gameStatus = 'Игрок 1: Попадание!';
          if (!_checkWin(player2Field)) {
            // Продолжаем ход игрока 1
          } else {
            gameStatus = 'Игрок 1 победил!';
          }
        } else {
          player2Field[row][col] = 'miss';
          gameStatus = 'Игрок 1: Мимо!';
          currentPlayer = 2;
          if (!isPlayerVsPlayer) {
            _computerMoveWithDelay();
          }
        }
      } else {
        if (player1Field[row][col] == 'ship') {
          player1Field[row][col] = 'hit';
          gameStatus = 'Игрок 2: Попадание!';
          if (!_checkWin(player1Field)) {
            // Продолжаем ход игрока 2
          } else {
            gameStatus = 'Игрок 2 победил!';
          }
        } else {
          player1Field[row][col] = 'miss';
          gameStatus = 'Игрок 2: Мимо!';
          currentPlayer = 1;
        }
      }
    });
  }

  void _computerMoveWithDelay() {
    setState(() {
      isThinking = true;
      gameStatus = 'Компьютер думает...';
    });

    Future.delayed(const Duration(seconds: 2), () {
      _computerMove();
      setState(() {
        isThinking = false;
      });
    });
  }

  void _computerMove() {
    final Random random = Random();
    int row, col;
    do {
      row = random.nextInt(10);
      col = random.nextInt(10);
    } while (player1Field[row][col] == 'hit' || player1Field[row][col] == 'miss');

    setState(() {
      moves++;
      if (player1Field[row][col] == 'ship') {
        player1Field[row][col] = 'hit';
        gameStatus = 'Компьютер: Попадание!';
        if (!_checkWin(player1Field)) {
          _computerMoveWithDelay();
        } else {
          gameStatus = 'Компьютер победил!';
        }
      } else {
        player1Field[row][col] = 'miss';
        gameStatus = 'Компьютер: Мимо!';
        currentPlayer = 1;
      }
    });
  }

  bool _checkWin(List<List<String>> field) {
    for (int i = 0; i < 10; i++) {
      for (int j = 0; j < 10; j++) {
        if (field[i][j] == 'ship') {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Морской бой')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(gameStatus, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              if (isPlacingShips && shipsToPlace > 0)
                Column(
                  children: [
                    Text('Разместите корабль размером ${shipSizes[currentShipIndex]}', style: const TextStyle(fontSize: 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Ориентация: '),
                        Switch(
                          value: isHorizontal,
                          onChanged: (value) {
                            setState(() {
                              isHorizontal = value;
                            });
                          },
                        ),
                        Text(isHorizontal ? 'Горизонтальная' : 'Вертикальная'),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Text('Ходы: $moves', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              if (isThinking)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 10),
              if (!isPlayerVsPlayer || currentPlayer == 1 || isPlacingShips)
                Column(
                  children: [
                    const Text('Ваше поле:', style: TextStyle(fontSize: 16)),
                    SizedBox(
                      height: 180,
                      child: PixelBattleshipField(
                        isPlayerField: true,
                        isPlacingShips: isPlacingShips,
                        field: player1Field,
                        onTap: isPlacingShips ? _placeShip : null,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              const Text('Поле противника:', style: TextStyle(fontSize: 16)),
              SizedBox(
                height: 180,
                child: PixelBattleshipField(
                  isPlayerField: false,
                  isPlacingShips: false,
                  field: player2Field,
                  onTap: !isPlacingShips && currentPlayer == 1 ? _shoot : null,
                ),
              ),
              const SizedBox(height: 10),
              if (isPlacingShips && shipsToPlace == 0)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (isPlayerVsPlayer) {
                        isPlacingShips = true;
                        shipsToPlace = 10;
                        currentShipIndex = 0;
                        gameStatus = 'Игрок 2, разместите корабли';
                      } else {
                        isPlacingShips = false;
                        gameStatus = 'Начните стрельбу!';
                      }
                    });
                  },
                  child: const Text('Готово'),
                ),
              if (!isPlacingShips)
                ElevatedButton(
                  onPressed: () async {
                    await gameLogic.saveGameResult(
                      gameStatus.contains('победил') ? gameStatus.split(' ')[0] : 'Ничья',
                      moves,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Результат сохранён!')),
                    );
                  },
                  child: const Text('Сохранить результат'),
                ),
              if (gameStatus == 'Выберите режим игры')
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isPlayerVsPlayer = false;
                          isPlacingShips = true;
                          gameStatus = 'Разместите корабли';
                        });
                      },
                      child: const Text('Игрок vs Компьютер'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isPlayerVsPlayer = true;
                          isPlacingShips = true;
                          gameStatus = 'Игрок 1, разместите корабли';
                        });
                      },
                      child: const Text('Игрок vs Игрок'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Корневой виджет приложения
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Морской бой',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}
