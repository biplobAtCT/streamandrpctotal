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

  num totalSales = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchTotalSales(); // Initial fetch of total sales
    _listenToSalesChanges(); // Set up real-time listener
  }

  Future<void> _fetchTotalSales() async {
    // If you want to receive the "previous" data for updates and deletes, you will need to set REPLICA IDENTITY to FULL, like this: ALTER TABLE your_table REPLICA IDENTITY FULL
    //
    // create or replace function get_total_sales_for_date (sales_date DATE) RETURNS table (total_sales NUMERIC) as $$
    // BEGIN
    //     RETURN QUERY
    //     SELECT SUM(total) FROM sell WHERE sales_date <= created_at::date;
    // END;
    // $$ LANGUAGE plpgsql;

    final response = await supabase.rpc('get_total_sales_for_date', params: {
      "sales_date": DateTime.now().toIso8601String()
    }).single();
    final num? total = response['total_sales'];
    if (total != null) {
      totalSales = total;
      setState(() {});
    } else {
      print('Error fetching total sales:');
    }
  }

  void _listenToSalesChanges() {
    supabase
        .channel('public:sell')
        .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sell',
        callback: (payload) {
          print("Payload $payload");
          _fetchTotalSales();
        })
        .subscribe();
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() async {
    await supabase.removeAllChannels();
    super.dispose();
  }
}
