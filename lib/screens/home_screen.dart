import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'record_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Map<String, String>> recentRecordings = [
    {"date": "Jun 12", "title": "Reading A", "duration": "00:25"},
    {"date": "Jun 11", "title": "Intro Poem", "duration": "00:18"},
    {"date": "Jun 10", "title": "Custom Text", "duration": "00:30"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: PopupMenuButton<String>(
                  icon: const CircleAvatar(
                    radius: 23,
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  onSelected: (value) async {
                    if (value == 'signout') {
                      await FirebaseAuth.instance.signOut();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'signout',
                      child: Text('Sign out'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Welcome, USER',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RecordScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.mic, size: 48),
                      SizedBox(height: 10),
                      Text(
                        "New Recording",
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Recordings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full history
                    },
                    child: Text('View all'),
                  )
                ],
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: recentRecordings.length,
                  itemBuilder: (context, index) {
                    final rec = recentRecordings[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(rec['date']!),
                            Text(
                              rec['title']!,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(rec['duration']!),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
