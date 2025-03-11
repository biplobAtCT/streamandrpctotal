import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fddfiykqogpzpyxmgdrt.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkZGZpeWtxb2dwenB5eG1nZHJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc4Nzg3NDEsImV4cCI6MjA1MzQ1NDc0MX0.M-IP4t1R0FueKQsxbLmtqxKlKJrqrZbUEtcg_8jYs8Q',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SalesScreen(),
    );
  }
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final DateTime now = DateTime.now();
  late final DateTime startOfToday;
  late final DateTime startOfTomorrow;

  late final Stream<List<Map<String, dynamic>>> _stream;
  double totalSales = 0.0;


  @override
  void initState() {
    super.initState();
    startOfToday = DateTime(now.year, now.month, now.day);

    // full change listening alter table to full https://supabase.com/docs/guides/realtime/postgres-changes#receiving-old-records
    _stream = supabase
        .from('sell')
        .stream(primaryKey: ['id'])
        .gte('created_at', startOfToday.toIso8601String());

    _stream.listen((sales) {
      totalSales = sales.fold(0.0, (sum, sale) => sum + (sale['total'] ?? 0.0));
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Sales')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Total Sales: \$${totalSales.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  print("data: ${snapshot.data}");

                  final sales = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return ListTile(
                        title: Text('ID: ${sale['id']} - Total: \$${sale['total']}'),
                        subtitle: Text('Created At: ${sale['created_at']}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}