import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../data/report_repository.dart';

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
  File? _selectedImage;
  final _descController = TextEditingController();
  final _titleController = TextEditingController();

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
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _handleSubmit() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen kameradan bir kanıt fotoğrafı çekin.')),
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
    
    try {
      final repository = ref.read(reportRepositoryProvider);
      await repository.createReport(
        {
          'title': _titleController.text,
          'description': _descController.text,
          'category': _selectedCategory,
          'latitude': _latitude,
          'longitude': _longitude,
          'addressText': _addressText,
        },
        _selectedImage!.path,
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
    return SingleChildScrollView(
      key: const ValueKey(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Olay Yeri Fotoğrafı', style: Theme.of(context).textTheme.titleLarge),
          const Gap(12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 2),
                image: _selectedImage != null 
                  ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                  : null,
              ),
              child: _selectedImage == null ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: AppColors.primary, size: 32),
                  ),
                  const Gap(16),
                  const Text('Kamerayı Aç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Gap(4),
                  Text('Galeriden yükleme güvenlik için kapalıdır.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ) : null,
            ),
          ),
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
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İhbar Detayları', style: Theme.of(context).textTheme.titleLarge),
          const Gap(16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
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
            decoration: const InputDecoration(
              labelText: 'Açıklama (Plaka ve Detaylar)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0Buttons() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (_selectedImage == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen kanıt fotoğrafı çekin.')));
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
            child: ElevatedButton(
              onPressed: _isUploading ? null : _handleSubmit,
              child: _isUploading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('İhbarı Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
