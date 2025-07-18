import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserModel {
  final String userID;
  final String email;
  final String username;
  final Uint8List? profileImage;
  final String bio;

  UserModel({
    required this.userID,
    required this.email,
    required this.username,
    this.profileImage,
    required this.bio,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userID: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      profileImage: json['profileImage'] != null
          ? base64Decode(json['profileImage'])
          : null,
      bio: json['bio'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userID,
      'email': email,
      'username': username,
      'profileImage': profileImage != null
          ? base64Encode(profileImage!)
          : null,
      'bio': bio,
    };
  }


  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userID: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      profileImage: data['profileImage'] != null
          ? base64Decode(data['profileImage'])
          : null,
      bio: data['bio'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'profileImage': profileImage != null
          ? base64Encode(profileImage!)
          : null,
      'bio': bio,
    };
  }

  ImageProvider? get imageProvider {
    if (profileImage != null) {
      return MemoryImage(profileImage!);
    }
    return null;
  }
}