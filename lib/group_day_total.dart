

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesDataScreen extends StatefulWidget {
  @override
  _SalesDataScreenState createState() => _SalesDataScreenState();
}

class _SalesDataScreenState extends State<SalesDataScreen> {
  List<Map<String, dynamic>> salesData = [];
  int currentPage = 1;
  final int pageSize = 2;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchSalesData(currentPage);
  }

  Future<void> fetchSalesData(int page) async {
    setState(() {
      isLoading = true;
    });

    try {
// create or replace function get_sales_data(page integer, page_size integer)
// returns json as $$
// declare
//   result json;
// begin
//   select json_agg(row_to_json(sales_data))
//   into result
//   from (
//     select
//       date_trunc('day', created_at) as date,
//       sum(total) as total_sales,
//       jsonb_agg(jsonb_build_object('id', id, 'total', total, 'created_at', created_at)) as records
//     from sell
//     group by date
//     order by date desc
//     offset (page - 1) * page_size
//     limit page_size
//   ) sales_data;
//
//   return coalesce(result, '[]'::json);
// end;
// $$ language plpgsql;

      // Call the RPC function to get the sales data
      final response = await Supabase.instance.client
          .rpc('get_sales_data', params: {'page': page, 'page_size': pageSize});

      print("data: $response");

      if (response == null) {
        throw Exception('Error fetching sales data: ${response.error!.message}');
      }

      final List<dynamic> groupedSales = response;

      // Prepare the final result
      List<Map<String, dynamic>> result = [];
      for (var item in groupedSales) {
        String date = item['date'].toString().substring(0, 10); // Format date
        num totalSales = item['total_sales'] ?? 0;

        result.add({
          'date': date,
          'total_sales': totalSales,
          'list': item['records'] ?? [],
        });
      }

      setState(() {
        salesData = result;
      });
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Group data: $salesData");
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales Data'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: salesData.length,
        itemBuilder: (context, index) {
          final sale = salesData[index];
          return Card(
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${sale['date']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Total Sales: \$${sale['total_sales']}', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Sales Records:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ...List.generate(sale['list'].length, (recordIndex) {
                    final record = sale['list'][recordIndex];
                    return ListTile(
                      title: Text('ID: ${record['id']} - Total: \$${record['total']}'),
                      subtitle: Text('Created At: ${record['created_at']}'),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            currentPage++;
            fetchSalesData(currentPage);
          });
        },
        child: Icon(Icons.arrow_forward),
      ),
    );
  }
}