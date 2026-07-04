import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FaultManagementScreen extends StatelessWidget {
  const FaultManagementScreen({super.key});

  // ── Resolve fault ────────────────────────────────────
  Future<void> _resolveFault(
    BuildContext context,
    String docId,
    String meterID,
  ) async {
    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Resolve Fault",
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 16,
          ),
        ),
        content: Text(
          "Mark fault for $meterID as resolved?\n\n"
          "Consumer will be notified automatically.",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "RESOLVE",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Firestore mein status update karo
      await FirebaseFirestore.instance
          .collection('Faults')
          .doc(docId)
          .update({
        'status':     'Resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': 'Admin',
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Fault for $meterID resolved successfully.",
          ),
          backgroundColor: Colors.greenAccent,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }


  Future<void> _archiveMeterGroup(
    BuildContext context,
    String meterID,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('meter_resolved_archive')
          .doc(meterID)
          .set({
        'archived':   true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ── Format timestamp ─────────────────────────────────
  String _formatTime(dynamic ts) {
    if (ts == null || ts is! Timestamp) return '—';
    final dt   = ts.toDate();
    final h    = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min  = dt.minute.toString().padLeft(2, '0');
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${dt.day} ${months[dt.month]}, $h:$min $ampm";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color(0xFF00E5FF),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Fault Reports",
            style: GoogleFonts.orbitron(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          // Tab bar — Pending | Resolved
          bottom: TabBar(
            indicatorColor: const Color(0xFF00E5FF),
            labelColor: const Color(0xFF00E5FF),
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: "PENDING"),
              Tab(text: "RESOLVED"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Tab 1: Pending faults (individual cards) ──
            _buildFaultList(
              context,
              statusFilter: 'Pending',
              emptyMessage: "No pending fault reports",
              showResolveButton: true,
            ),

            // ── Tab 2: Resolved faults (grouped by meter) ──
            _buildResolvedGroupedList(context),
          ],
        ),
      ),
    );
  }

  //   fault list builder 
  Widget _buildFaultList(
    BuildContext context, {
    required String statusFilter,
    required String emptyMessage,
    required bool showResolveButton,
  }) {
    return StreamBuilder<QuerySnapshot>(
     stream: FirebaseFirestore.instance
    .collection('Faults')
    .where('status', isEqualTo: statusFilter)
    .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00E5FF),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  statusFilter == 'Pending'
                      ? Icons.check_circle_outline
                      : Icons.history,
                  color: Colors.white.withOpacity(0.12),
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  emptyMessage,
                  style: GoogleFonts.orbitron(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc  = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final meterID     = data['meterID'] ?? '—';
            final description = data['description'] ?? '—';
            final type        = data['type'] ?? '—';
            final timestamp   = data['timestamp'];
            final resolvedAt  = data['resolvedAt'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: statusFilter == 'Pending'
                      ? Colors.orangeAccent.withOpacity(0.25)
                      : Colors.greenAccent.withOpacity(0.20),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    // ── Header row ─────────────────────
                    Row(
                      children: [
                        // Status icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusFilter == 'Pending'
                                ? Colors.orangeAccent
                                    .withOpacity(0.1)
                                : Colors.greenAccent
                                    .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Icon(
                            statusFilter == 'Pending'
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: statusFilter == 'Pending'
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Meter ID + type
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Meter: $meterID",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                type.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: statusFilter ==
                                          'Pending'
                                      ? Colors.orangeAccent
                                      : Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusFilter == 'Pending'
                                ? Colors.orangeAccent
                                    .withOpacity(0.15)
                                : Colors.greenAccent
                                    .withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusFilter,
                            style: TextStyle(
                              color: statusFilter == 'Pending'
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Divider(
                      color: Colors.white.withOpacity(0.06),
                    ),
                    const SizedBox(height: 8),

                    //  Description 
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),

                    //  Timestamps
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.white24,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Reported: ${_formatTime(timestamp)}",
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),

                    if (resolvedAt != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.greenAccent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Resolved: ${_formatTime(resolvedAt)}",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Resolve button 
                    if (showResolveButton) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.greenAccent
                                    .withOpacity(0.15),
                            foregroundColor:
                                Colors.greenAccent,
                            side: const BorderSide(
                              color: Colors.greenAccent,
                              width: 0.8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets
                                .symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            "MARK AS RESOLVED",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () => _resolveFault(
                            context,
                            doc.id,
                            meterID,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  //  fault list — grouped by meterID 

  Widget _buildResolvedGroupedList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Faults')
          .where('status', isEqualTo: 'Resolved')
          .snapshots(),
      builder: (context, faultSnap) {
        if (faultSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00E5FF),
            ),
          );
        }

        final allDocs = faultSnap.data?.docs ?? [];

        // Second stream — tracks which meter groups the admin
        // has chosen to hide from this screen.
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('meter_resolved_archive')
              .snapshots(),
          builder: (context, archiveSnap) {

            final archivedMeterIDs = <String>{};
            for (final doc in archiveSnap.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['archived'] == true) {
                archivedMeterIDs.add(doc.id);
              }
            }

            // Group resolved docs by meterID
            final Map<String, List<QueryDocumentSnapshot>> grouped = {};
            for (final doc in allDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final meterID = data['meterID'] ?? '—';
              grouped.putIfAbsent(meterID, () => []).add(doc);
            }

            // Hide groups the admin has archived from the screen
            final visibleEntries = grouped.entries
                .where((e) => !archivedMeterIDs.contains(e.key))
                .toList();

            if (visibleEntries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.white.withOpacity(0.12),
                      size: 48,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "No resolved faults yet",
                      style: GoogleFonts.orbitron(
                        color: Colors.white.withOpacity(0.22),
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Sort each meter's reports — most recent resolve first
            for (final entry in visibleEntries) {
              entry.value.sort((a, b) {
                final aTs = (a.data() as Map<String, dynamic>)['resolvedAt']
                    as Timestamp?;
                final bTs = (b.data() as Map<String, dynamic>)['resolvedAt']
                    as Timestamp?;
                if (aTs == null || bTs == null) return 0;
                return bTs.compareTo(aTs);
              });
            }

            // Sort the meter groups — meter with the most recent
            // resolved report appears at the top
            visibleEntries.sort((a, b) {
              final aTs = (a.value.first.data()
                  as Map<String, dynamic>)['resolvedAt'] as Timestamp?;
              final bTs = (b.value.first.data()
                  as Map<String, dynamic>)['resolvedAt'] as Timestamp?;
              if (aTs == null || bTs == null) return 0;
              return bTs.compareTo(aTs);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleEntries.length,
              itemBuilder: (context, index) {
                final meterID   = visibleEntries[index].key;
                final meterDocs = visibleEntries[index].value;
                final latestData =
                    meterDocs.first.data() as Map<String, dynamic>;
                final latestResolvedAt = latestData['resolvedAt'];
                final latestType = (latestData['type'] ?? '—')
                    .toString()
                    .replaceAll('_', ' ');

                return GestureDetector(
                  onTap: () => _showMeterHistoryDialog(
                      context, meterID, meterDocs),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.20),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.greenAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Meter: $meterID",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Last: $latestType",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.greenAccent,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Resolved: ${_formatTime(latestResolvedAt)}",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Report count chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${meterDocs.length} report"
                              "${meterDocs.length > 1 ? 's' : ''}",
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white24,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Full resolved-history popup for a single meter ────
  void _showMeterHistoryDialog(
    BuildContext context,
    String meterID,
    List<QueryDocumentSnapshot> docs,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Meter: $meterID",
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 15,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withOpacity(0.06)),
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final type = (data['type'] ?? '—')
                    .toString()
                    .replaceAll('_', ' ');
                final reportedAt = data['timestamp'];
                final resolvedAt = data['resolvedAt'];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.white24, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            "Reported: ${_formatTime(reportedAt)}",
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.greenAccent, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            "Resolved: ${_formatTime(resolvedAt)}",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              // Removes this meter's card from the Resolved
              // screen only — Firestore fault data stays as-is.
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _archiveMeterGroup(context, meterID);
                  },
                  child: const Text(
                    "DELETE",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Just closes the popup — card stays as it is.
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    "KEEP",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}