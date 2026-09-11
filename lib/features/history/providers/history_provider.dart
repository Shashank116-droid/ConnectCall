import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/call_model.dart';

class HistoryProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<CallModel> _history = [];
  bool _isLoading = true;

  List<CallModel> get history => _history;
  bool get isLoading => _isLoading;

  void fetchHistory(String userId) {
    _firestore
        .collection('calls')
        .where('callerId', isEqualTo: userId)
        .snapshots()
        .listen((callerSnapshot) {
          _firestore
            .collection('calls')
            .where('calleeIds', arrayContains: userId)
            .snapshots()
            .listen((calleeSnapshot) {
               final allDocs = [...callerSnapshot.docs, ...calleeSnapshot.docs];
               final uniqueDocs = {for (var doc in allDocs) doc.id: doc}.values.toList();
               
               _history = uniqueDocs
                   .map((doc) => CallModel.fromJson(doc.data()))
                   .where((call) => call.status == 'ended' || call.status == 'rejected' || call.status == 'missed' || call.status == 'failed' || call.status == 'busy')
                   .toList();
               
               // Sort by timestamp descending
               _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
               
               _isLoading = false;
               notifyListeners();
            });
        });
  }
}
