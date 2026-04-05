// import 'package:flutter/material.dart';

// class AppointmentScreen extends StatelessWidget {
//   const AppointmentScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Text(
//           'My Appointments',
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';

/// ── Colour palette ────────────────────────────────────────────
const kPrimary  = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg       = Color(0xFFF4F6FB);
const kCardBg   = Colors.white;
const kTextDark = Color(0xFF1F2937);
const kTextMid  = Color(0xFF6B7280);
const kBorder   = Color(0xFFE5E7EB);
const kRed      = Color(0xFFEA4335);
const kGreen    = Color(0xFF34A853);

class AppointmentScreen extends StatefulWidget {
  @override
  State<AppointmentScreen> createState() =>
      _AppointmentScreenState();
}

class _AppointmentScreenState
    extends State<AppointmentScreen> {

  String searchQuery = "";
  String filterStatus = "all";

  List<Map<String, dynamic>> appointments = [
    {
      "name": "Dr. Sarah Johnson",
      "specialization": "Cardiologist",
      "clinic": "Heart Care Center",
      "date": "April 8, 2026",
      "time": "10:30 AM",
      "status": "upcoming",
      "location": "Downtown Medical Plaza",
      "image":
          "https://images.unsplash.com/photo-1706565029539-d09af5896340"
    },
    {
      "name": "Dr. Michael Chen",
      "specialization": "Dentist",
      "clinic": "Smile Dental Clinic",
      "date": "April 10, 2026",
      "time": "2:00 PM",
      "status": "upcoming",
      "location": "Central Square",
      "image":
          "https://images.unsplash.com/photo-1755189118414-14c8dacdb082"
    },
    {
      "name": "Dr. Emily Watson",
      "specialization": "General Physician",
      "clinic": "City Health Center",
      "date": "April 2, 2026",
      "time": "11:00 AM",
      "status": "completed",
      "location": "North Avenue",
      "image":
          "https://images.unsplash.com/photo-1606811801193-e318c9a87ad7"
    },
  ];

  Color getStatusColor(String status) {
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
    final filtered = appointments.where((a) {
      final matchSearch = a["name"]
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          a["specialization"]
              .toLowerCase()
              .contains(searchQuery.toLowerCase());

      final matchFilter =
          filterStatus == "all" || a["status"] == filterStatus;

      return matchSearch && matchFilter;
    }).toList();

    return Scaffold(
      backgroundColor: kBg,

      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary,
        onPressed: () {},
        child: Icon(Icons.add),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            /// 🔷 HEADER
          Container(
  padding: EdgeInsets.fromLTRB(16, 50, 16, 20),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [kGreen, Color(0xFFC8E6C9)],
    ),
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
  ),
  child: Column(
    children: [

      /// 🔍 SEARCH BAR (INSIDE HEADER)
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          onChanged: (val) => setState(() => searchQuery = val),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, color: kTextMid),
            hintText: "Search doctor or specialization",
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),

      SizedBox(height: 12),

      /// 🔘 FILTER TABS
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ["all", "upcoming", "completed", "cancelled"]
              .map((status) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          filterStatus = status;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: filterStatus == status
                              ? kGreen
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            if (filterStatus == status)
                              Icon(Icons.check,
                                  size: 14, color: Colors.white),
                            if (filterStatus == status)
                              SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: filterStatus == status
                                    ? Colors.white
                                    : kTextMid,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    ],
  ),
),
            /// 🔷 LIST
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: filtered.isEmpty
                    ? [
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Text("No appointments"),
                        )
                      ]
                    : filtered.map((a) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 14),
                          padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black12, blurRadius: 6)
                            ],
                          ),
                          child: Column(
                            children: [

                              /// Doctor Info
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage:
                                        NetworkImage(a["image"]),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(a["name"],
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: kTextDark)),
                                        Text(a["specialization"],
                                            style: TextStyle(
                                                color: kGreen)),
                                        Text(a["clinic"],
                                            style: TextStyle(
                                                color: kTextMid)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(a["status"])
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      a["status"],
                                      style: TextStyle(
                                          color: getStatusColor(
                                              a["status"]),
                                          fontSize: 12),
                                    ),
                                  )
                                ],
                              ),

                              SizedBox(height: 10),

                              /// Details
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 16, color: kTextMid),
                                  SizedBox(width: 6),
                                  Text(a["date"]),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 16, color: kTextMid),
                                  SizedBox(width: 6),
                                  Text(a["time"]),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16, color: kTextMid),
                                  SizedBox(width: 6),
                                  Text(a["location"]),
                                ],
                              ),

                              SizedBox(height: 10),

                              /// Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kGreen,
                                      ),
                                      onPressed: () {},
                                      child: Text("View Details"),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {},
                                    icon: Icon(Icons.call),
                                  )
                                ],
                              )
                            ],
                          ),
                        );
                      }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }
}