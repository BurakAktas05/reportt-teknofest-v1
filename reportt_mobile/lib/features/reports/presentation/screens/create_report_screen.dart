import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:shimmer/shimmer.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';
import '../../../../services/evidence_hash_service.dart';
import '../../../../services/device_attestation_service.dart';
import '../../../../services/voice_input_service.dart';
import '../../../../services/on_device_ai_service.dart';
import '../../../../offline/offline_report_store.dart';
import '../../../../offline/sync_worker.dart';

class CreateReportScreen extends ConsumerStatefulWidget {
  const CreateReportScreen({super.key});

  @override
  ConsumerState<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends ConsumerState<CreateReportScreen> {
  String _selectedCategory = 'PARKING_VIOLATION';
  final List<Map<String, String>> _categories = [
    {'value': 'PARKING_VIOLATION', 'label': 'Hatalı Park / Duraklama'},
    {'value': 'TRAFFIC_OFFENSE', 'label': 'Trafik Kural İhlali'},
    {'value': 'VANDALISM', 'label': 'Kamu Malına Zarar / Vandalizm'},
    {'value': 'ENVIRONMENTAL', 'label': 'Çevre Kirliliği / Atık'},
    {'value': 'SECURITY', 'label': 'Güvenlik İhlali / Şüpheli'},
    {'value': 'INFRASTRUCTURE', 'label': 'Altyapı / Yol Sorunu'},
    {'value': 'VIOLENCE', 'label': 'Şiddet / Kavga'},
    {'value': 'OTHER', 'label': 'Diğer'},
  ];
  
  bool _isUploading = false;
  final List<File> _selectedMedia = []; // Fotoğraf + Video listesi
  final List<String?> _mediaHashes = []; // V2: SHA-256 hash listesi
  final _descController = TextEditingController();
  final _titleController = TextEditingController();

  // V3: Sesli ihbar
  final VoiceInputService _voiceService = VoiceInputService();
  bool _isListening = false;

  // V3: On-device AI sonucu
  String? _aiCategory;
  double? _aiConfidence;
  bool _isAnalyzingAi = false;

  double? _latitude;
  double? _longitude;
  String _addressText = 'Konum aranıyor...';
  bool _isGettingLocation = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _addressText = 'Konum servisleri kapalı.';
        _isGettingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _addressText = 'Konum izni reddedildi.';
          _isGettingLocation = false;
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _addressText = 'Konum izni kalıcı olarak reddedildi.';
        _isGettingLocation = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _addressText = '${place.street}, ${place.subAdministrativeArea}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      setState(() {
        _addressText = 'Konum alınamadı.';
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _selectedMedia.add(file);
        _mediaHashes.add(null);
      });

      final idx = _selectedMedia.length - 1;
      final hash = await EvidenceHashService.computeSha256(file);
      setState(() => _mediaHashes[idx] = hash);

      _runAiClassification(file);
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _selectedMedia.add(file);
        _mediaHashes.add(null);
      });

      final idx = _selectedMedia.length - 1;
      final hash = await EvidenceHashService.computeSha256(file);
      setState(() => _mediaHashes[idx] = hash);
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
      _mediaHashes.removeAt(index);
    });
  }

  /// V3: Fotoğrafı on-device AI ile sınıflandır
  Future<void> _runAiClassification(File file) async {
    setState(() => _isAnalyzingAi = true);
    try {
      final result = await OnDeviceAIService.classifyImage(file);
      if (mounted) {
        setState(() {
          _aiCategory = result['category'];
          _aiConfidence = result['confidence'];
        });
      }
    } catch (e) {
      debugPrint('[AI] Sınıflandırma hatası: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingAi = false);
    }
  }

  /// V3: Sesli ihbar — mikrofon toggle
  void _toggleVoiceInput() async {
    if (_isListening) {
      _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      final initialized = await _voiceService.initialize();
      if (!initialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mikrofon izni verilemedi veya cihaz desteklemiyor.')),
          );
        }
        return;
      }
      setState(() => _isListening = true);
      _voiceService.startListening(
        onResult: (text) {
          setState(() {
            _descController.text = text;
            _descController.selection = TextSelection.collapsed(offset: text.length);
          });
        },
        onFinal: (text) {
          setState(() => _isListening = false);
        },
      );
    }
  }

  void _handleSubmit() async {
    if (_selectedMedia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen kameradan bir kanıt fotoğrafı veya video çekin.')),
      );
      return;
    }

    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen başlık ve açıklama alanlarını doldurun.')),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir konum olmadan ihbar oluşturulamaz.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    // V2 Modül 1: Cihaz doğrulama token'ı al
    final attestationToken = await DeviceAttestationService.generateToken();

    // V2 Modül 1: Cihaz-içi aciliyet ön skoru hesapla (Hybrid Check)
    final clientUrgencyScore = DeviceAttestationService.computeClientUrgencyScore(
      _descController.text,
      _selectedCategory,
    );

    final payload = {
      'title': _titleController.text,
      'description': _descController.text,
      'category': _selectedCategory,
      'latitude': _latitude,
      'longitude': _longitude,
      'addressText': _addressText,
    };

    // V2 Modül 6: Çevrimdışı kontrolü
    final isOnline = await SyncWorker.isOnline();

    if (!isOnline) {
      // OFFLINE: Lokale kaydet
      try {
        await OfflineReportStore.save(
          payload: payload,
          imageFile: _selectedMedia.first,
          imageHash: _mediaHashes.isNotEmpty ? (_mediaHashes.first ?? '') : '',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('📴 İnternet yok — ihbar çevrimdışı kaydedildi. Bağlantı geldiğinde otomatik gönderilecek.'),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Çevrimdışı kayıt hatası: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
      return;
    }

    // ONLINE: Normal akış
    try {
      final repository = ref.read(reportRepositoryProvider);
      await repository.createReport(
        payload,
        _selectedMedia.map((f) => f.path).toList(),
        evidenceHashes: _mediaHashes.whereType<String>().toList(),
        deviceAttestationToken: attestationToken,
        clientUrgencyScore: clientUrgencyScore,
      );
      
      if (mounted) {
        ref.invalidate(myReportsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İhbarınız başarıyla oluşturuldu!'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        title: Text(_currentStep == 0 ? 'Adım 1: Kanıt ve Konum' : 'Adım 2: Detaylar', style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentStep == 0 ? _buildStep0() : _buildStep1(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _currentStep == 0 ? _buildStep0Buttons() : _buildStep1Buttons(),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return FadeInUp(
      key: const ValueKey(0),
      duration: const Duration(milliseconds: 400),
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Olay Yeri Kanıtları', style: Theme.of(context).textTheme.titleLarge),
          const Gap(12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.camera_alt), label: const Text('Fotoğraf'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
            const Gap(12),
            Expanded(child: OutlinedButton.icon(onPressed: _pickVideo, icon: const Icon(Icons.videocam), label: const Text('Video (30sn)'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          ]),
          const Gap(12),
          if (_selectedMedia.isEmpty)
            Container(width: double.infinity, height: 150,
              decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300, width: 2)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 40), const Gap(8),
                Text('Henüz kanıt eklenmedi', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ]))
          else
            SizedBox(height: 140, child: ListView.separated(
              scrollDirection: Axis.horizontal, itemCount: _selectedMedia.length,
              separatorBuilder: (_, __) => const Gap(10),
              itemBuilder: (context, i) {
                final file = _selectedMedia[i];
                final ext = file.path.split('.').last.toLowerCase();
                final isVideo = ['mp4', 'mov', 'avi', '3gp'].contains(ext);
                return Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14),
                    child: isVideo
                      ? Container(width: 140, height: 140, color: Colors.black87, child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48)))
                      : Image.file(file, width: 140, height: 140, fit: BoxFit.cover)),
                  Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => _removeMedia(i),
                    child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                  if (isVideo) Positioned(bottom: 6, left: 6, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                    child: const Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                ]);
              })),
          if (_mediaHashes.any((h) => h != null)) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                Icon(Icons.verified_user, color: Colors.green.shade700, size: 18), const Gap(8),
                Expanded(child: Text('Dijital Mühür: ${_mediaHashes.where((h) => h != null).length} dosya mühürlendi',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontFamily: 'monospace'))),
              ])),
          ],

          // V3: On-device AI Sınıflandırma Sonucu
          if (_isAnalyzingAi) ...[
            const Gap(16),
            Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy, color: Colors.grey),
                    const Gap(12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 150, height: 12, color: Colors.white),
                        const Gap(8),
                        Container(width: 100, height: 10, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_aiCategory != null) ...[
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy, color: AppColors.primary),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Sınıflandırması: $_aiCategory', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Güven Oranı: %${((_aiConfidence ?? 0) * 100).toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Önerilen kategoriyi seç
                      final hasCategory = _categories.any((c) => c['value'] == _aiCategory);
                      if (hasCategory) {
                        setState(() {
                          _selectedCategory = _aiCategory!;
                          _currentStep = 1; // Detaylara geç
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('AI önerisi uygulandı: $_aiCategory')),
                        );
                      }
                    },
                    child: const Text('Kullan'),
                  )
                ],
              ),
            ),
          ],

          const Gap(32),

          Text('Konum Bilgisi (Canlı GPS)', style: Theme.of(context).textTheme.titleLarge),
          const Gap(12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: _isGettingLocation
                ? const CircularProgressIndicator()
                : Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 32),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          _addressText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildStep1() {
    return FadeInUp(
      key: const ValueKey(1),
      duration: const Duration(milliseconds: 400),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('İhbar Detayları', style: Theme.of(context).textTheme.titleLarge),
          const Gap(16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: _categories.map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const Gap(24),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Kısa Başlık (Örn: Kaldırıma Park)'),
          ),
          const Gap(24),
          TextFormField(
            controller: _descController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Açıklama (Plaka ve Detaylar)',
              alignLabelWithHint: true,
              suffixIcon: IconButton(
                onPressed: _toggleVoiceInput,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : AppColors.primary,
                ),
                tooltip: _isListening ? 'Dinleniyor... Durdurmak için tıkla' : 'Sesli giriş',
              ),
            ),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  Text('Dinleniyor... Konuşun.', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildStep0Buttons() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (_selectedMedia.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen kanıt fotoğrafı veya video çekin.')));
            return;
          }
          if (_latitude == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS konumu bekleniyor...')));
            return;
          }
          setState(() => _currentStep = 1);
        },
        child: const Text('Devam Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStep1Buttons() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton(
              onPressed: _isUploading ? null : () => setState(() => _currentStep = 0),
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Geri'),
            ),
          ),
          const Gap(16),
          Expanded(
            flex: 2,
            child: _isUploading
                ? Pulse(
                    infinite: true,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          Gap(12),
                          Text('Gönderiliyor...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _handleSubmit,
                    child: const Text('İhbarı Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
          ),
        ],
      ),
    );
  }
}
