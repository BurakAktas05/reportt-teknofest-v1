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
    {'value': 'PARKING_VIOLATION', 'label': 'Hatalı Park'},
    {'value': 'ENVIRONMENTAL', 'label': 'Çevre Kirliliği'},
    {'value': 'SECURITY', 'label': 'Güvenlik İhlali'},
    {'value': 'INFRASTRUCTURE', 'label': 'Altyapı Sorunu'},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        title: const Text('Yeni İhbar Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera / Image Box
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
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
                    const Text(
                      'Güvenli Canlı Çekim',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Gap(4),
                    Text(
                      'Güvenlik için galeriden yükleme kapalıdır.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Dosyalarınız AI ile spam kontrolünden geçecektir.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ) : null,
              ),
            ),
            const Gap(32),

            // Map Box (Location)
            Text('Konum Bilgisi (Canlı GPS)', style: Theme.of(context).textTheme.titleLarge),
            const Gap(12),
            Container(
              width: double.infinity,
              height: 100,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: _isGettingLocation
                  ? const CircularProgressIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            _addressText,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
            const Gap(32),

            // Form
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
            const Gap(16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Kısa Başlık',
              ),
            ),
            const Gap(16),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'Lütfen durumu detaylıca açıklayın...',
                alignLabelWithHint: true,
              ),
            ),
            const Gap(40),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _handleSubmit,
                child: _isUploading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('İhbarı Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}
