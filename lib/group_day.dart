import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesData {
  final DateTime date;
  final double totalSales;
  final List<SalesRecord> list;

  SalesData({
    required this.date,
    required this.totalSales,
    required this.list,
  });

  factory SalesData.fromJson(Map<String, dynamic> json) {
    final List<SalesRecord> list = [];

    for (var m in json['records']) {
      list.add(SalesRecord.fromJson(m));
    }

    return SalesData(
      date: DateTime.parse(json['date']),
      totalSales: json['total_sales'].toDouble(),
      list: list,
    );
  }
}

class SalesRecord {
  final int id;
  final double total;
  final DateTime createdAt;

  SalesRecord({
    required this.id,
    required this.total,
    required this.createdAt,
  });

  factory SalesRecord.fromJson(Map<String, dynamic> json) {
    return SalesRecord(
      id: json['id'],
      total: json['total'].toDouble(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  _SalesPageState createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _supabase = Supabase.instance.client;
  List<SalesData> _salesData = [];
  bool _isLoading = false;
  int _currentPage = 1;
  final int _pageSize = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  bool _initialLoadComplete = false;

  // Track if we need more content based on screen height
  bool _needsMoreContent = false;

  @override
  void initState() {
    super.initState();
    _loadSalesData();

    // Add scroll listener to detect when user scrolls
    _scrollController.addListener(_scrollListener);

    // Add post-frame callback to check if we need more content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfMoreContentNeeded();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Check if we need more content based on screen height
  void _checkIfMoreContentNeeded() {
    if (!_initialLoadComplete) return;

    // If we have a scroll controller attached to a scrollable widget
    if (_scrollController.hasClients) {
      // Check if the current content doesn't fill the screen
      if (_scrollController.position.maxScrollExtent < 50 && _hasMoreData && !_isLoading) {
        setState(() {
          _needsMoreContent = true;
        });
        _loadSalesData();
      } else {
        setState(() {
          _needsMoreContent = false;
        });
      }
    }
  }

  // Scroll listener that only checks if we need more content when scrolling stops
  void _scrollListener() {
    // Load more when user reaches near the bottom
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreData) {
      _loadSalesData();
    }
  }

  Future<void> _loadSalesData({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _salesData = [];
        _hasMoreData = true;
        _initialLoadComplete = false;
      }
    });

    try {
// create or replace function get_sales_data_1(page integer, page_size integer)
// returns json as $$
// declare
//   dates date[];
//   result json;
// begin
//   -- First, get the distinct dates with pagination
//   select array_agg(date_group)
//   into dates
//   from (
//     select distinct date_trunc('day', created_at)::date as date_group
//     from sell
//     order by date_group desc
//     offset (page - 1) * page_size
//     limit page_size
//   ) subq;
//
//   -- Then build the complete result
//   select json_build_object(
//     'data', coalesce(
//       (select json_agg(
//         json_build_object(
//           'date', date_val,
//           'total_sales', (
//             select sum(total)
//             from sell
//             where date_trunc('day', created_at)::date = date_val
//           ),
//           'records', (
//             select jsonb_agg(
//               jsonb_build_object(
//                 'id', id,
//                 'total', total,
//                 'created_at', created_at
//               )
//             )
//             from sell
//             where date_trunc('day', created_at)::date = date_val
//           )
//         )
//       )
//       from unnest(dates) as date_val),
//       '[]'::json
//     )
//   ) into result;
//
//   return result;
// end;
// $$ language plpgsql;

      final response = await _supabase.rpc('get_sales_data_1', params: {
        'page': _currentPage,
        'page_size': _pageSize,
      });

      final data = response['data'] as List;

      if (data.isEmpty) {
        setState(() {
          _hasMoreData = false;
        });
      } else {
        setState(() {
          _salesData.addAll(
            data.map((item) => SalesData.fromJson(item)).toList(),
          );
          _currentPage++;
        });
      }

      // Mark initial load as complete
      if (!_initialLoadComplete) {
        setState(() {
          _initialLoadComplete = true;
        });

        // Check if we need to load more data after rendering
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkIfMoreContentNeeded();
        });
      }
    } catch (e, s) {
      print(e.toString());
      print(s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sales data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Sales Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSalesData(refresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSalesData(refresh: true),
        child: _salesData.isEmpty && !_isLoading
            ? const Center(child: Text('No sales data available'))
            : ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          itemCount: _salesData.length + (_hasMoreData ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _salesData.length) {
              return _isLoading || _needsMoreContent
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator()),
              )
                  : const SizedBox.shrink();
            }

            final salesData = _salesData[index];
            return SalesDataCard(salesData: salesData);
          },
        ),
      ),
    );
  }
}

class SalesDataCard extends StatelessWidget {
  final SalesData salesData;

  const SalesDataCard({super.key, required this.salesData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  salesData.date.toLocal().toString().split(' ')[0],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${salesData.totalSales.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                )
              ],
            ),
          ),
          const SizedBox(height: 5),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: salesData.list.length,
            itemBuilder: (context, index) {
              final record = salesData.list[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${record.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total : ${record.total}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    children: [
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Amount: \$${record.total.toStringAsFixed(2)}'),
                              Text('Time: ${record.createdAt.toLocal().toString().split('.')[0]}'),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Amount: \$${record.total.toStringAsFixed(2)}'),
                              Text('Time: ${record.createdAt.toLocal().toString().split('.')[0]}'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text("Info added by Person")
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}