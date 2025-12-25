import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FileSharingService {
  // Giới hạn dung lượng file (Firebase Free tier: 5GB total storage, 1GB download/day)
  // Để an toàn, giới hạn mỗi file: 25MB
  static const int maxFileSizeBytes = 25 * 1024 * 1024; // 25MB
  static const int maxFileSizeMB = 25;

  // Các loại file được phép
  static const List<String> allowedExtensions = [
    // Documents
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt',
    // Archives
    'zip', 'rar', '7z',
    // Images (nếu muốn gửi qua file picker thay vì image picker)
    'jpg', 'jpeg', 'png', 'gif', 'webp',
    // Audio
    'mp3', 'wav', 'aac', 'm4a',
    // Video (nhỏ hơn 25MB)
    'mp4', 'mov', 'avi',
    // Other
    'apk',
  ];

  /// Chọn file từ thiết bị
  static Future<PlatformFile?> pickFile() async {
    try {
      debugPrint('📁 FileSharingService: Opening file picker...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false, // Chỉ cho phép chọn 1 file 1 lúc
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;
        
        debugPrint('📁 FileSharingService: File selected:');
        debugPrint('   - Name: ${file.name}');
        debugPrint('   - Size: ${file.size} bytes (${(file.size / 1024 / 1024).toStringAsFixed(2)} MB)');
        debugPrint('   - Extension: ${file.extension}');

        // Kiểm tra dung lượng file
        if (file.size > maxFileSizeBytes) {
          debugPrint('❌ FileSharingService: File too large! Max: ${maxFileSizeMB}MB');
          throw FileException(
            'File quá lớn! Dung lượng tối đa: ${maxFileSizeMB}MB\n'
            'File của bạn: ${(file.size / 1024 / 1024).toStringAsFixed(2)}MB'
          );
        }

        // Kiểm tra extension
        if (file.extension != null && 
            !allowedExtensions.contains(file.extension!.toLowerCase())) {
          debugPrint('❌ FileSharingService: File type not allowed: ${file.extension}');
          throw FileException(
            'Loại file không được hỗ trợ: .${file.extension}\n'
            'Các loại file được phép: ${allowedExtensions.join(", ")}'
          );
        }

        debugPrint('✅ FileSharingService: File validation passed');
        return file;
      } else {
        debugPrint('📁 FileSharingService: No file selected');
        return null;
      }
    } catch (e) {
      debugPrint('❌ FileSharingService: Error picking file: $e');
      rethrow;
    }
  }

  /// Upload file lên Firebase Storage
  static Future<FileUploadResult> uploadFile({
    required PlatformFile file,
    required String chatRoomId,
    required Function(double) onProgress,
  }) async {
    try {
      debugPrint('☁️ FileSharingService: Starting file upload...');
      debugPrint('   - Chat Room ID: $chatRoomId');
      debugPrint('   - File name: ${file.name}');

      // Tạo unique filename với timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.extension ?? 'bin';
      final fileName = 'file_${timestamp}_${file.name}';
      
      // Path trong Firebase Storage
      final path = 'chats/$chatRoomId/files/$fileName';
      debugPrint('   - Storage path: $path');

      // Reference đến Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(path);

      // Metadata cho file
      final metadata = SettableMetadata(
        contentType: _getMimeType(extension),
        customMetadata: {
          'originalName': file.name,
          'extension': extension,
          'size': file.size.toString(),
          'uploadedAt': timestamp.toString(),
        },
      );

      // Upload file
      UploadTask uploadTask;
      if (file.path != null) {
        // Upload từ file path (mobile)
        uploadTask = storageRef.putFile(File(file.path!), metadata);
      } else if (file.bytes != null) {
        // Upload từ bytes (web)
        uploadTask = storageRef.putData(file.bytes!, metadata);
      } else {
        throw FileException('Không thể đọc file');
      }

      // Theo dõi tiến trình upload
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('☁️ FileSharingService: Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress(progress);
      });

      // Đợi upload hoàn thành
      final snapshot = await uploadTask;
      debugPrint('✅ FileSharingService: Upload completed!');

      // Lấy download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ FileSharingService: Download URL: $downloadUrl');

      return FileUploadResult(
        downloadUrl: downloadUrl,
        fileName: file.name,
        fileSize: file.size,
        fileExtension: extension,
        storagePath: path,
      );
    } catch (e) {
      debugPrint('❌ FileSharingService: Upload failed: $e');
      throw FileException('Upload thất bại: $e');
    }
  }

  /// Xóa file từ Firebase Storage
  static Future<void> deleteFile(String storagePath) async {
    try {
      debugPrint('🗑️ FileSharingService: Deleting file: $storagePath');
      await FirebaseStorage.instance.ref(storagePath).delete();
      debugPrint('✅ FileSharingService: File deleted successfully');
    } catch (e) {
      debugPrint('❌ FileSharingService: Delete failed: $e');
      throw FileException('Xóa file thất bại: $e');
    }
  }

  /// Lấy MIME type từ extension
  static String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      
      // Archives
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      
      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      
      // Video
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      
      // APK
      case 'apk':
        return 'application/vnd.android.package-archive';
      
      default:
        return 'application/octet-stream';
    }
  }

  /// Lấy icon cho file dựa trên extension
  static String getFileIcon(String extension) {
    final ext = extension.toLowerCase();
    
    // Documents
    if (['pdf'].contains(ext)) return '📄';
    if (['doc', 'docx'].contains(ext)) return '📝';
    if (['xls', 'xlsx'].contains(ext)) return '📊';
    if (['ppt', 'pptx'].contains(ext)) return '📽️';
    if (['txt'].contains(ext)) return '📃';
    
    // Archives
    if (['zip', 'rar', '7z'].contains(ext)) return '🗜️';
    
    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return '🖼️';
    
    // Audio
    if (['mp3', 'wav', 'aac', 'm4a'].contains(ext)) return '🎵';
    
    // Video
    if (['mp4', 'mov', 'avi'].contains(ext)) return '🎥';
    
    // APK
    if (['apk'].contains(ext)) return '📦';
    
    return '📁'; // Default file icon
  }

  /// Format file size thành chuỗi dễ đọc
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
    }
  }
}

/// Kết quả upload file
class FileUploadResult {
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final String fileExtension;
  final String storagePath;

  FileUploadResult({
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.fileExtension,
    required this.storagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileExtension': fileExtension,
      'storagePath': storagePath,
    };
  }
}

/// Custom exception cho file operations
class FileException implements Exception {
  final String message;
  FileException(this.message);

  @override
  String toString() => message;
}
