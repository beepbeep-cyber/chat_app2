import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Trợ giúp & Hỗ trợ'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 24),

          // 1. Hướng dẫn sử dụng
          _buildSection(
            icon: Icons.book_outlined,
            title: 'Hướng dẫn sử dụng',
            color: Colors.blue,
            items: [
              _HelpItem('Cách gửi tin nhắn', 'Gửi text, voice, ảnh, file'),
              _HelpItem('Cách tạo nhóm chat', 'Tạo và quản lý nhóm'),
              _HelpItem('Cách gọi video call', 'Thực hiện cuộc gọi video'),
              _HelpItem('Mã hóa end-to-end', 'Bảo mật tin nhắn của bạn'),
              _HelpItem('Chat riêng tư', 'Thiết lập chat với mật khẩu'),
              _HelpItem('Tự động xóa tin nhắn', 'Cài đặt thời gian xóa'),
            ],
            onTap: (item) => _showGuideDetail(item),
          ),

          const SizedBox(height: 16),

          // 2. Câu hỏi thường gặp
          _buildSection(
            icon: Icons.help_outline,
            title: 'Câu hỏi thường gặp',
            color: Colors.orange,
            items: [
              _HelpItem('Làm sao để thêm bạn bè?', 'Tìm kiếm và kết nối'),
              _HelpItem('Làm sao để xóa tin nhắn?', 'Xóa tin nhắn đã gửi'),
              _HelpItem('Làm sao để thay đổi avatar?', 'Cập nhật ảnh đại diện'),
              _HelpItem('Làm sao để bật/tắt thông báo?', 'Quản lý thông báo'),
              _HelpItem('Tại sao tin nhắn không gửi được?', 'Xử lý lỗi gửi tin nhắn'),
            ],
            onTap: (item) => _showFaqDetail(item),
          ),

          const SizedBox(height: 16),

          // 3. Bảo mật & Quyền riêng tư
          _buildSection(
            icon: Icons.security_outlined,
            title: 'Bảo mật & Quyền riêng tư',
            color: Colors.green,
            items: [
              _HelpItem('Chính sách bảo mật', 'Cách chúng tôi bảo vệ dữ liệu'),
              _HelpItem('Quyền truy cập', 'Camera, micro, storage'),
              _HelpItem('Mã hóa end-to-end', 'Công nghệ bảo mật'),
              _HelpItem('Báo cáo vi phạm', 'Báo cáo người dùng xấu'),
            ],
            onTap: (item) => _showSecurityDetail(item),
          ),

          const SizedBox(height: 16),

          // 4. Liên hệ hỗ trợ
          _buildContactSection(),

          const SizedBox(height: 16),

          // 5. Thông tin ứng dụng
          _buildAppInfoSection(),

          const SizedBox(height: 16),

          // 6. Báo cáo lỗi
          _buildReportBugCard(),

          const SizedBox(height: 16),

          // 7. Đánh giá ứng dụng
          _buildRateUsCard(),

          const SizedBox(height: 24),

          // Footer
          Center(
            child: Text(
              'Chat App v$_appVersion',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.support_agent,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Chúng tôi có thể giúp gì cho bạn?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tìm hướng dẫn, câu trả lời hoặc liên hệ hỗ trợ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<_HelpItem> items,
    required Function(_HelpItem) onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return InkWell(
              onTap: () => onTap(item),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Liên hệ hỗ trợ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContactItem(
            icon: Icons.email_outlined,
            title: 'Email',
            value: 'support@chatapp.com',
            onTap: () => _launchUrl('mailto:support@chatapp.com'),
          ),
          const Divider(height: 24),
          _buildContactItem(
            icon: Icons.telegram,
            title: 'Telegram',
            value: '@chatapp_support',
            onTap: () => _launchUrl('https://t.me/chatapp_support'),
          ),
          const Divider(height: 24),
          _buildContactItem(
            icon: Icons.phone,
            title: 'Hotline',
            value: '1900-xxxx',
            subtitle: 'Hỗ trợ 24/7',
            onTap: () => _launchUrl('tel:1900xxxx'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.purple, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.purple,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thông tin ứng dụng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('Phiên bản', _appVersion),
          const Divider(height: 24),
          _buildInfoItem('Điều khoản sử dụng', 'Xem chi tiết', onTap: () {
            _showTermsOfService();
          }),
          const Divider(height: 24),
          _buildInfoItem('Chính sách quyền riêng tư', 'Xem chi tiết', onTap: () {
            _showPrivacyPolicy();
          }),
          const Divider(height: 24),
          _buildInfoItem('Giấy phép mã nguồn mở', 'Xem licenses', onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'Chat App',
              applicationVersion: _appVersion,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: onTap != null ? Colors.indigo : Colors.grey[600],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBugCard() {
    return InkWell(
      onTap: () => _showReportBugDialog(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[400]!, Colors.red[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bug_report, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Báo cáo lỗi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gặp vấn đề? Hãy cho chúng tôi biết',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRateUsCard() {
    return InkWell(
      onTap: () => _showRateDialog(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[400]!, Colors.orange[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đánh giá ứng dụng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bạn thích ứng dụng? Hãy đánh giá 5 sao!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // Detail dialogs
  void _showGuideDetail(_HelpItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: _getGuideContent(item.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _getGuideContent(String title) {
    switch (title) {
      case 'Cách gửi tin nhắn':
        return const Text(
          '1. Mở cuộc trò chuyện\n'
          '2. Nhập tin nhắn vào ô chat\n'
          '3. Nhấn biểu tượng để gửi:\n'
          '   • 📷 Camera: Chụp ảnh\n'
          '   • 🖼️ Gallery: Chọn ảnh từ thư viện\n'
          '   • 📁 File: Gửi file\n'
          '   • 🎤 Voice: Ghi âm và gửi\n'
          '4. Nhấn nút gửi để gửi tin nhắn',
        );
      case 'Cách tạo nhóm chat':
        return const Text(
          '1. Vào tab "Nhóm"\n'
          '2. Nhấn nút "+" ở góc phải\n'
          '3. Chọn "Tạo nhóm mới"\n'
          '4. Nhập tên nhóm\n'
          '5. Chọn thành viên từ danh sách\n'
          '6. Nhấn "Tạo nhóm" để hoàn tất',
        );
      case 'Cách gọi video call':
        return const Text(
          '1. Mở cuộc trò chuyện\n'
          '2. Nhấn biểu tượng video call ở góc phải\n'
          '3. Chờ người khác chấp nhận\n'
          '4. Bắt đầu cuộc gọi video\n'
          '5. Sử dụng các nút:\n'
          '   • 🎤 Tắt/bật micro\n'
          '   • 📷 Tắt/bật camera\n'
          '   • 🔄 Đổi camera trước/sau\n'
          '   • ❌ Kết thúc cuộc gọi',
        );
      case 'Mã hóa end-to-end':
        return const Text(
          'Mã hóa end-to-end bảo vệ tin nhắn của bạn:\n\n'
          '• Chỉ bạn và người nhận đọc được\n'
          '• Không ai khác có thể truy cập (kể cả chúng tôi)\n'
          '• Tin nhắn được mã hóa trên thiết bị\n'
          '• Giải mã chỉ trên thiết bị người nhận\n\n'
          'Biểu tượng 🔒 hiển thị khi mã hóa được bật.',
        );
      case 'Chat riêng tư':
        return const Text(
          'Thiết lập chat riêng tư với mật khẩu:\n\n'
          '1. Vào Cài đặt → Chat riêng tư\n'
          '2. Bật "Khóa Chat riêng tư"\n'
          '3. Thiết lập mật khẩu (tối thiểu 4 ký tự)\n'
          '4. Chat riêng tư sẽ yêu cầu mật khẩu để truy cập\n\n'
          'Lưu ý: Nếu quên mật khẩu, bạn sẽ mất quyền truy cập!',
        );
      case 'Tự động xóa tin nhắn':
        return const Text(
          'Cài đặt tự động xóa tin nhắn:\n\n'
          '1. Mở cuộc trò chuyện nhóm\n'
          '2. Nhấn menu → Thông tin nhóm\n'
          '3. Chọn "Tự động xóa tin nhắn"\n'
          '4. Chọn thời gian:\n'
          '   • 1 giờ\n'
          '   • 24 giờ\n'
          '   • 7 ngày\n'
          '   • 30 ngày\n'
          '5. Tin nhắn sẽ tự động xóa sau thời gian đã chọn',
        );
      default:
        return Text('Chi tiết hướng dẫn cho: $title');
    }
  }

  void _showFaqDetail(_HelpItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: _getFaqContent(item.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _getFaqContent(String title) {
    switch (title) {
      case 'Làm sao để thêm bạn bè?':
        return const Text(
          'Hiện tại, ứng dụng tự động kết nối với những người dùng Firebase Authentication.\n\n'
          'Bạn có thể:\n'
          '1. Tìm kiếm người dùng trong tab "Trò chuyện"\n'
          '2. Nhấn vào tên để bắt đầu cuộc trò chuyện\n'
          '3. Gửi tin nhắn đầu tiên để kết nối',
        );
      case 'Làm sao để xóa tin nhắn?':
        return const Text(
          'Xóa tin nhắn đã gửi:\n\n'
          '1. Nhấn giữ vào tin nhắn muốn xóa\n'
          '2. Chọn "Xóa tin nhắn"\n'
          '3. Xác nhận xóa\n\n'
          'Lưu ý: Tin nhắn sẽ bị xóa vĩnh viễn và không thể khôi phục!',
        );
      case 'Làm sao để thay đổi avatar?':
        return const Text(
          'Thay đổi ảnh đại diện:\n\n'
          '1. Vào Cài đặt (tab cuối cùng)\n'
          '2. Nhấn vào ảnh đại diện hiện tại\n'
          '3. Chọn nguồn:\n'
          '   • Chụp ảnh mới\n'
          '   • Chọn từ thư viện\n'
          '4. Cắt và xác nhận ảnh mới\n'
          '5. Ảnh đại diện sẽ được cập nhật',
        );
      case 'Làm sao để bật/tắt thông báo?':
        return const Text(
          'Quản lý thông báo:\n\n'
          '1. Vào Cài đặt → Thông báo\n'
          '2. Bật/tắt các tùy chọn:\n'
          '   • Thông báo tin nhắn mới\n'
          '   • Âm thanh thông báo\n'
          '   • Rung khi có tin nhắn\n'
          '   • Hiển thị preview\n\n'
          'Bạn cũng có thể tắt thông báo cho từng cuộc trò chuyện riêng lẻ.',
        );
      case 'Tại sao tin nhắn không gửi được?':
        return const Text(
          'Tin nhắn không gửi được có thể do:\n\n'
          '1. Không có kết nối internet\n'
          '   → Kiểm tra WiFi/4G\n\n'
          '2. File quá lớn (>10MB)\n'
          '   → Nén file hoặc gửi file nhỏ hơn\n\n'
          '3. Không có quyền truy cập\n'
          '   → Cấp quyền camera/storage trong Settings\n\n'
          '4. Lỗi server tạm thời\n'
          '   → Thử lại sau vài phút\n\n'
          'Nếu vẫn gặp lỗi, hãy liên hệ hỗ trợ!',
        );
      default:
        return Text('Câu trả lời cho: $title');
    }
  }

  void _showSecurityDetail(_HelpItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: _getSecurityContent(item.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _getSecurityContent(String title) {
    switch (title) {
      case 'Chính sách bảo mật':
        return const Text(
          'CHÍNH SÁCH BẢO MẬT\n\n'
          '1. Thu thập dữ liệu:\n'
          '   • Email, tên, ảnh đại diện\n'
          '   • Tin nhắn và file đính kèm\n'
          '   • Thông tin cuộc gọi\n\n'
          '2. Sử dụng dữ liệu:\n'
          '   • Cung cấp dịch vụ chat\n'
          '   • Cải thiện trải nghiệm người dùng\n'
          '   • Không bán cho bên thứ ba\n\n'
          '3. Bảo mật:\n'
          '   • Mã hóa end-to-end\n'
          '   • Lưu trữ an toàn trên Firebase\n'
          '   • Tuân thủ GDPR\n\n'
          'Chi tiết: https://chatapp.com/privacy',
        );
      case 'Quyền truy cập':
        return const Text(
          'Ứng dụng cần các quyền sau:\n\n'
          '📷 Camera:\n'
          '• Chụp ảnh và gửi\n'
          '• Video call\n\n'
          '🎤 Microphone:\n'
          '• Ghi âm tin nhắn thoại\n'
          '• Video call\n\n'
          '📁 Storage:\n'
          '• Lưu và gửi file\n'
          '• Tải ảnh/video\n\n'
          '📍 Location (tùy chọn):\n'
          '• Chia sẻ vị trí\n\n'
          'Bạn có thể quản lý quyền trong Settings → Apps → Chat App',
        );
      case 'Mã hóa end-to-end':
        return const Text(
          'CÔNG NGHỆ MÃ HÓA END-TO-END\n\n'
          '🔒 Cách hoạt động:\n'
          '1. Tin nhắn được mã hóa trên thiết bị bạn\n'
          '2. Chỉ người nhận có khóa giải mã\n'
          '3. Server chỉ chuyển tiếp dữ liệu đã mã hóa\n'
          '4. Không ai khác đọc được (kể cả chúng tôi)\n\n'
          '🛡️ Tính năng:\n'
          '• AES-256 encryption\n'
          '• RSA key exchange\n'
          '• Perfect Forward Secrecy\n\n'
          '✅ An toàn tuyệt đối cho tin nhắn riêng tư!',
        );
      case 'Báo cáo vi phạm':
        return const Text(
          'Báo cáo người dùng vi phạm:\n\n'
          '1. Mở cuộc trò chuyện\n'
          '2. Nhấn menu (⋮) → Báo cáo\n'
          '3. Chọn lý do:\n'
          '   • Spam\n'
          '   • Lừa đảo\n'
          '   • Quấy rối\n'
          '   • Nội dung không phù hợp\n'
          '   • Khác\n'
          '4. Mô tả chi tiết (tùy chọn)\n'
          '5. Gửi báo cáo\n\n'
          'Chúng tôi sẽ xem xét và xử lý trong vòng 24-48h.',
        );
      default:
        return Text('Chi tiết bảo mật cho: $title');
    }
  }

  void _showReportBugDialog() {
    final TextEditingController bugController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Báo cáo lỗi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vui lòng mô tả chi tiết lỗi bạn gặp phải:'),
            const SizedBox(height: 16),
            TextField(
              controller: bugController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Không thể gửi ảnh trong chat nhóm...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (bugController.text.isNotEmpty) {
                // TODO: Send bug report to server
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cảm ơn! Báo cáo lỗi đã được gửi.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Gửi báo cáo'),
          ),
        ],
      ),
    );
  }

  void _showRateDialog() {
    int rating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Đánh giá ứng dụng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bạn thích ứng dụng của chúng tôi?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: rating > 0
                  ? () {
                      Navigator.pop(context);
                      if (rating >= 4) {
                        // Open Play Store
                        _launchUrl('https://play.google.com/store/apps/details?id=com.chatapp');
                      } else {
                        // Show feedback form
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cảm ơn phản hồi! Chúng tôi sẽ cải thiện.'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Đánh giá'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Điều khoản sử dụng'),
        content: const SingleChildScrollView(
          child: Text(
            'ĐIỀU KHOẢN SỬ DỤNG\n\n'
            '1. Chấp nhận điều khoản\n'
            'Bằng cách sử dụng ứng dụng này, bạn đồng ý với các điều khoản sau.\n\n'
            '2. Sử dụng hợp pháp\n'
            'Bạn cam kết sử dụng ứng dụng cho mục đích hợp pháp và không vi phạm pháp luật.\n\n'
            '3. Nội dung người dùng\n'
            'Bạn chịu trách nhiệm về nội dung bạn chia sẻ. Không gửi nội dung vi phạm, spam, hoặc quấy rối.\n\n'
            '4. Quyền riêng tư\n'
            'Chúng tôi cam kết bảo vệ quyền riêng tư của bạn theo Chính sách bảo mật.\n\n'
            '5. Thay đổi điều khoản\n'
            'Chúng tôi có quyền cập nhật điều khoản này. Thay đổi sẽ được thông báo qua ứng dụng.\n\n'
            'Cập nhật: 14/01/2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chính sách quyền riêng tư'),
        content: const SingleChildScrollView(
          child: Text(
            'CHÍNH SÁCH QUYỀN RIÊNG TƯ\n\n'
            '1. Thông tin chúng tôi thu thập\n'
            '• Thông tin tài khoản: email, tên, ảnh đại diện\n'
            '• Nội dung: tin nhắn, file, ảnh, video\n'
            '• Dữ liệu sử dụng: thời gian online, tương tác\n\n'
            '2. Cách chúng tôi sử dụng\n'
            '• Cung cấp và cải thiện dịch vụ\n'
            '• Hỗ trợ khách hàng\n'
            '• Bảo mật và phòng chống gian lận\n'
            '• Tuân thủ pháp luật\n\n'
            '3. Chia sẻ thông tin\n'
            '• Chúng tôi KHÔNG bán dữ liệu của bạn\n'
            '• Chỉ chia sẻ khi có yêu cầu pháp lý\n'
            '• Sử dụng các đối tác tin cậy (Firebase, etc.)\n\n'
            '4. Bảo mật\n'
            '• Mã hóa end-to-end cho tin nhắn\n'
            '• Lưu trữ an toàn trên Firebase\n'
            '• Tuân thủ GDPR và các chuẩn quốc tế\n\n'
            '5. Quyền của bạn\n'
            '• Truy cập và tải xuống dữ liệu\n'
            '• Xóa tài khoản và dữ liệu\n'
            '• Từ chối thu thập dữ liệu\n\n'
            'Liên hệ: privacy@chatapp.com\n'
            'Cập nhật: 14/01/2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở: $url')),
        );
      }
    }
  }
}

class _HelpItem {
  final String title;
  final String subtitle;

  _HelpItem(this.title, this.subtitle);
}
