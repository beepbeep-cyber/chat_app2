import 'package:my_porject/configs/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/file_sharing_service.dart';

class FileMessageWidget extends StatelessWidget {
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String fileExtension;
  final bool isMe;

  const FileMessageWidget({
    Key? key,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.fileExtension,
    required this.isMe,
  }) : super(key: key);

  Future<void> _openFile() async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Không thể mở file';
      }
    } catch (e) {
      debugPrint('❌ FileMessageWidget: Error opening file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileIcon = FileSharingService.getFileIcon(fileExtension);
    final fileSizeFormatted = FileSharingService.formatFileSize(fileSize);
    
    return GestureDetector(
      onTap: _openFile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.gray800 : AppTheme.primaryDark,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isMe ? AppTheme.gray700 : AppTheme.gray800,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  fileIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // File info
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // File name
                  Text(
                    fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // File size and extension
                  Row(
                    children: [
                      Text(
                        fileSizeFormatted,
                        style: TextStyle(
                          color: AppTheme.gray400,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isMe 
                              ? AppTheme.gray700?.withValues(alpha: 0.5)
                              : AppTheme.gray800?.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '.${fileExtension.toUpperCase()}',
                          style: TextStyle(
                            color: AppTheme.gray300,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            
            // Download icon
            Icon(
              Icons.download_rounded,
              color: AppTheme.gray400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget để hiển thị progress khi đang upload file
class FileUploadProgressWidget extends StatelessWidget {
  final String fileName;
  final double progress; // 0.0 - 1.0
  final VoidCallback? onCancel;

  const FileUploadProgressWidget({
    Key? key,
    required this.fileName,
    required this.progress,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.gray800,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress indicator
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  backgroundColor: AppTheme.gray700,
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // File info
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Đang tải lên...',
                  style: TextStyle(
                    color: AppTheme.gray400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Cancel button
          if (onCancel != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              color: AppTheme.gray400,
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
