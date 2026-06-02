import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddStockScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AddStockScreen({super.key, this.docId, this.existingData});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final nameController = TextEditingController();
  final stockController = TextEditingController();
  final alertController = TextEditingController();

  File? image;

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        image = File(picked.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingData != null) {
      nameController.text = widget.existingData!['name'] ?? '';
      stockController.text = (widget.existingData!['stock'] ?? 0).toString();
      alertController.text =
          (widget.existingData!['lowStockThreshold'] ?? 0).toString();
    }
  }

  Future saveStock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? imageUrl = widget.existingData?['imageUrl'];

    /// Upload new image if selected
    if (image != null) {
      final ref = FirebaseStorage.instance.ref(
        'medicine_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await ref.putFile(image!);
      imageUrl = await ref.getDownloadURL();
    }

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule');

    /// 🔥 EDIT MODE
    if (widget.docId != null) {
      await collection.doc(widget.docId).update({
        "name": nameController.text,
        "stock": int.parse(stockController.text),
        "lowStockThreshold": int.parse(alertController.text),
        "imageUrl": imageUrl,
      });
    }

    /// ➕ ADD MODE
    else {
      await collection.add({
        "name": nameController.text,
        "stock": int.parse(stockController.text),
        "lowStockThreshold": int.parse(alertController.text),
        "imageUrl": imageUrl,
        "createdAt": Timestamp.now(),
      });
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Medicine Stock")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// IMAGE
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 120,
                color: Colors.grey[200],
                child: image == null
                    ? const Icon(Icons.camera_alt)
                    : Image.file(image!, fit: BoxFit.cover),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Medicine Name"),
            ),

            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Stock"),
            ),

            TextField(
              controller: alertController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Alert when stock reaches",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(onPressed: saveStock, child: const Text("Save")),
          ],
        ),
      ),
    );
  }
}
