class StatsScreen extends StatelessWidget {
  final int total;
  final int done;
  final int skipped;

  const StatsScreen({
    super.key,
    required this.total,
    required this.done,
    required this.skipped,
  });

  @override
  Widget build(BuildContext context) {
    final pending = total - done - skipped;
    final percent = total == 0 ? 0 : (done / total * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Stats')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Productivity: $percent%',
                style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 20),

            Text('Total: $total'),
            Text('Done: $done'),
            Text('Skipped: $skipped'),
            Text('Pending: $pending'),
          ],
        ),
      ),
    );
  }
}
