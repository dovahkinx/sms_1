// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' show SmsQuery;

import 'package:sms_guard/constant/constant.dart';
import 'package:sms_guard/services/sms_remover.dart';
import 'package:sms_guard/services/sms_service.dart';
import 'package:sms_guard/view/chat_messages_view.dart';
import 'package:sms_guard/view/send_sms_view.dart';
import 'package:sms_guard/view/spam_sms.dart';
import '../cubit/sms_cubit.dart';

import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // isloading getir
      if (context.read<SmsCubit>().state.isInit == false) {
        print("resumed");
        context.read<SmsCubit>().getMessages();
      }
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      print("paused");
      // isloading getir
      context.read<SmsCubit>().appPaused();
    }
    super.didChangeAppLifecycleState(state);
  }

  bool visible = true;

  late final ScrollController controller = ScrollController()
    ..addListener(_scrollListener);

  void _scrollListener() {
    if (controller.position.pixels == controller.position.maxScrollExtent) {
      context.read<SmsCubit>().getMessages();
    }
    //add more logic for your case
    if (controller.position.userScrollDirection == ScrollDirection.reverse &&
        visible) {
      visible = false;
      setState(() {
        print("visible: $visible");
      });
    }
    if (controller.position.userScrollDirection == ScrollDirection.forward &&
        !visible) {
      visible = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1.0 : 0.0,
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SendScreen(),
              ),
            );
          },
          icon: const Icon(Icons.edit),
          label: const Text("Yeni Mesaj"),
          tooltip: "Yeni mesaj oluştur",
        ),
      ),
      appBar: appbar(context),
      body: BlocConsumer<SmsCubit, SmsState>(
        listener: (context, state) {},
        builder: (context, state) {
          return Column(
            children: [
              if (visible) _buildSearchBar(),
              Expanded(
                child: state.isLoading 
                  ? _buildLoadingIndicator()
                  : state.myMessages.isEmpty 
                    ? _buildEmptyState()
                    : _buildMessageList(state),
              ),
            ],
          );
        },
      ),
    );
  }

  // Yükleme göstergesi
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Mesajlar yükleniyor...",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // Boş durum görünümü
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            "Henüz mesajınız yok",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni mesaj göndermek için butona tıklayın",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SendScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text("Yeni Mesaj"),
          ),
        ],
      ),
    );
  }

  // Arama çubuğu
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ListTile(
          onTap: () {
            // Arama işlemi
          },
          leading: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            "Mesajlarda ara...",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          trailing: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.primary,
            radius: 16,
            child: const Icon(Icons.mic, size: 18),
          ),
        ),
      ),
    );
  }

  // Mesaj listesi
  Widget _buildMessageList(SmsState state) {
    return ListView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: state.myMessages.length,
      itemBuilder: (context, index) {
        var thread = state.myMessages[index];
        
        bool isUnread = !thread.isRead;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              // Thread'i okundu olarak işaretle (Kotlin tarafında gerçekleşiyor)
              if (thread.threadId != null && isUnread) {
                // SmsService'i kullanarak okundu olarak işaretle
                await SmsService.instance
                    .markThreadAsRead(thread.threadId.toString());
              }

              // Mevcut işlemleri gerçekleştir
              context
                  .read<SmsCubit>()
                  .filterMessageForAdress(thread.address ?? '');
              _navigateToChatScreen(thread.address, thread.name);
            },
            onLongPress: () => _showMessageOptions(context, thread),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Hero(
                  tag: "avatar_${thread.address}",
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: thread.avatarColor,
                    child: thread.name == ""
                        ? _circleAvatarText("?")
                        : _circleAvatarText(thread.name),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (thread.name == null || thread.name!.isEmpty)
                            ? (thread.address ?? 'Bilinmeyen Gönderen')
                            : thread.name!,
                        style: TextStyle(
                          fontWeight:
                              isUnread ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      thread.formattedDate ?? '',
                      style: TextStyle(
                        color: isUnread
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight:
                            isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    isUnread
                        ? Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        thread.formattedSubtitle ?? '',
                        style: TextStyle(
                          color: isUnread ? Colors.black87 : Colors.grey[600],
                          fontWeight:
                              isUnread ? FontWeight.w500 : FontWeight.normal,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Mesaj seçenekleri menüsünü göster
  void _showMessageOptions(BuildContext context, var thread) {
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: thread.name == ""
                    ? _circleAvatarText("?")
                    : _circleAvatarText(thread.name),
              ),
              title: Text(
                (thread.name == null || thread.name!.isEmpty) 
                  ? (thread.address ?? 'Bilinmeyen Gönderen') 
                  : thread.name!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(thread.address ?? 'Bilinmeyen Gönderen'),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.chat_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text("Mesaj Gönder"),
              onTap: () {
                Navigator.pop(context);
                context.read<SmsCubit>().filterMessageForAdress(thread.address ?? '');
                _navigateToChatScreen(thread.address, thread.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: Colors.blue),
              title: const Text("Ara"),
              onTap: () {
                Navigator.pop(context);
                // Arama işlevi
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: Colors.amber),
              title: const Text("Arşivle"),
              onTap: () {
                Navigator.pop(context);
                // Arşivleme işlevi
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Sil"),
              onTap: () async {
                Navigator.pop(context);
                // Silme işlemini onayla
                await _deleteConversation(thread);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Konuşmayı silme
  Future<void> _deleteConversation(var thread) async {
    bool shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesajları Sil'),
        content: const Text('Bu kişiyle tüm mesajlarınız silinecek. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'SİL',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (shouldDelete && context.mounted) {
      try {
        // İlerleme göstergesini göster
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final result = await SmsRemover()
            .removeSmsByThreadId(thread.threadId.toString());

        // İlerleme göstergesini kapat
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // UI'ı güncelle
        if (context.mounted) {
          if (result.contains("başarıyla silindi")) {
            // Tam silme başarılı, yerel listeyi de güncelle
            context.read<SmsCubit>().forceRefresh();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            // Hiç silme başarılı değil
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                action: SnackBarAction(
                  label: 'TEKRAR DENE',
                  textColor: Colors.white,
                  onPressed: () => _deleteConversation(thread),
                ),
              ),
            );
          }
        }
      } catch (e) {
        // Hata durumunda ilerleme göstergesini kapat
        if (context.mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Silme işlemi sırasında hata oluştu: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  _navigateToChatScreen(address, name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          address: address,
          name: name,
        ),
      ),
    );
  }

  appbar(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      titleSpacing: 16,
      shape: const Border(
        bottom: BorderSide(
          color: Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Constant.homeTitle,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SpamScreen(),
              ),
            );
          },
          icon: Icon(
            Icons.block_outlined,
            color: Colors.red[700],
            size: 24,
          ),
          tooltip: "Spam Mesajlar",
        ),
        IconButton(
          onPressed: () {
            // Ayarlar veya diğer seçenekleri göster
            _showMoreOptions(context);
          },
          icon: Icon(
            Icons.more_vert,
            color: Colors.grey[800],
            size: 24,
          ),
          tooltip: "Daha Fazla",
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  // Daha fazla seçenekler menüsü
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text("Ayarlar"),
              onTap: () {
                Navigator.pop(context);
                // Ayarlar ekranına git
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: Colors.blue),
              title: const Text("Arşivlenmiş Mesajlar"),
              onTap: () {
                Navigator.pop(context);
                // Arşiv ekranına git
              },
            ),
            ListTile(
              leading: Icon(Icons.block_outlined, color: Colors.red[700]),
              title: const Text("Spam Mesajlar"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SpamScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.amber),
              title: const Text("Yardım ve Geri Bildirim"),
              onTap: () {
                Navigator.pop(context);
                // Yardım ekranına git
              },
            ),
          ],
        ),
      ),
    );
  }

  _circleAvatarText(text) {
    if (text == null || text.toString().isEmpty) {
      return const Icon(
        Icons.question_mark,
        color: Colors.white,
        size: 30,
      );
    }
    
    String textStr = text.toString();
    
    // Eğer text bir telefon numarası ise (rakam veya + ile başlıyorsa)
    if (textStr.startsWith(RegExp(r'[0-9+]'))) {
      return const Icon(
        Icons.person,
        color: Colors.white,
        size: 30,
      );
    } else {
      // Kurumsal gönderen veya kişi adı - ilk harfi göster
      return Text(
        textStr.substring(0, 1).toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 20)
      );
    }
  }

}
