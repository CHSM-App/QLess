import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';


/// ── Colour palette ────────────────────────────────────────────
const kPrimary = Color(0xFF1A73E8);
const kBg = Color(0xFFF4F6FB);
const kCardBg = Colors.white;
const kTextDark = Color(0xFF1F2937);
const kTextMid = Color(0xFF6B7280);
const kRed = Color(0xFFEA4335);
const kGreen = Color(0xFF34A853);

class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({super.key});

  @override
  ConsumerState<AppointmentScreen> createState() =>
      _AppointmentScreenState();
}

class _AppointmentScreenState
    extends ConsumerState<AppointmentScreen> {
  String searchQuery = "";
  String filterStatus = "all";

  @override
  void initState() {
    super.initState();

    /// ✅ API CALL
    Future.microtask(() {
      ref
          .read(appointmentViewModelProvider.notifier)
          .getPatientAppointments(ref.read(patientLoginViewModelProvider).patientId ?? 0); // 👉 dynamic patientId
    });
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case "upcoming":
        return kPrimary;
      case "completed":
        return kGreen;
      case "cancelled":
        return kRed;
      default:
        return kTextMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointmentState =
        ref.watch(appointmentViewModelProvider).patientAppointmentsList;

    return Scaffold(
      backgroundColor: kBg,

      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        onPressed: () {},
        child: const Icon(Icons.add),
      ),

      body: appointmentState!.when(
        /// 🔄 LOADING
        loading: () =>
            const Center(child: CircularProgressIndicator()),

        /// ❌ ERROR
        error: (err, stack) =>
            Center(child: Text("Error: $err")),

        /// ✅ DATA
        data: (appointments) {
          final filtered = appointments.where((a) {
            final matchSearch =
                (a.name ?? "")
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase());

            final matchFilter =
                filterStatus == "all" ||
                    (a.status ?? "").toLowerCase() == filterStatus;

            return matchSearch && matchFilter;
          }).toList();

          return SingleChildScrollView(
            child: Column(
              children: [
                /// 🔷 HEADER
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(16, 50, 16, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [kGreen, Color(0xFFC8E6C9)]),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(40)),
                  ),
                  child: Column(
                    children: [
                      /// 🔍 SEARCH
                      TextField(
                        onChanged: (val) =>
                            setState(() => searchQuery = val),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon:
                              const Icon(Icons.search),
                          hintText: "Search patient name",
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// 🔘 FILTER
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            "all",
                            "upcoming",
                            "completed",
                            "cancelled"
                          ].map((status) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  filterStatus = status;
                                });
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.only(
                                        right: 8),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8),
                                decoration: BoxDecoration(
                                  color: filterStatus ==
                                          status
                                      ? kGreen
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                          10),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: filterStatus ==
                                            status
                                        ? Colors.white
                                        : kTextMid,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                /// 🔷 LIST
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                          horizontal: 16),
                  child: Column(
                    children: filtered.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child:
                                  Text("No appointments"),
                            )
                          ]
                        : filtered.map((a) {
                            return Container(
                              margin:
                                  const EdgeInsets.only(
                                      bottom: 14),
                              padding:
                                  const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius:
                                    BorderRadius.circular(
                                        16),
                                boxShadow: const [
                                  BoxShadow(
                                      color:
                                          Colors.black12,
                                      blurRadius: 6),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  /// Name + Status
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 24,
                                        child: Icon(
                                            Icons.person),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          a.name ?? "N/A",
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            color: kTextDark,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                    horizontal:
                                                        10,
                                                    vertical:
                                                        4),
                                        decoration:
                                            BoxDecoration(
                                          color: getStatusColor(
                                                  a.status)
                                              .withOpacity(
                                                  0.1),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      20),
                                        ),
                                        child: Text(
                                          a.status ?? "",
                                          style:
                                              TextStyle(
                                            color:
                                                getStatusColor(
                                                    a.status),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  /// Date
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons
                                              .calendar_today,
                                          size: 16,
                                          color:
                                              kTextMid),
                                      const SizedBox(
                                          width: 6),
                                      Text(
                                          a.appointmentDate ??
                                              "N/A"),
                                    ],
                                  ),

                                  /// Queue Number
                                  Row(
                                    children: [
                                      const Icon(
                                          Icons
                                              .format_list_numbered,
                                          size: 16,
                                          color:
                                              kTextMid),
                                      const SizedBox(
                                          width: 6),
                                      Text(
                                          "Queue: ${a.queueNumber ?? '-'}"),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  /// Button
                                  ElevatedButton(
                                    style:
                                        ElevatedButton
                                            .styleFrom(
                                      backgroundColor:
                                          kGreen,
                                    ),
                                    onPressed: () {},
                                    child: const Text(
                                        "View Details"),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}