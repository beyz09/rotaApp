// lib/screens/add_vehicle_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; // Benzersiz ID için
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _markaController = TextEditingController();
  final _seriController = TextEditingController();
  final _modelController = TextEditingController();
  final _yilController = TextEditingController();
  final _yakitTipiController = TextEditingController();
  final _vitesController = TextEditingController();
  final _kasaTipiController = TextEditingController();
  final _motorGucuController = TextEditingController();
  final _motorHacmiController = TextEditingController();
  final _cekisController = TextEditingController();

  // cityConsumption ve highwayConsumption için opsiyonel controller'lar
  // Vehicle modelinizde bu alanlar nullable (double?) ise ve formda olmasını istiyorsanız:
  // final _cityConsumptionController = TextEditingController();
  // final _highwayConsumptionController = TextEditingController();

  @override
  void dispose() {
    _markaController.dispose();
    _seriController.dispose();
    _modelController.dispose();
    _yilController.dispose();
    _yakitTipiController.dispose();
    _vitesController.dispose();
    _kasaTipiController.dispose();
    _motorGucuController.dispose();
    _motorHacmiController.dispose();
    _cekisController.dispose();
    // _cityConsumptionController.dispose(); // Eğer kullanılıyorsa
    // _highwayConsumptionController.dispose(); // Eğer kullanılıyorsa
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final String newId = const Uuid().v4();

      final newVehicle = Vehicle(
        id: newId,
        marka: _markaController.text,
        seri: _seriController.text,
        model: _modelController.text,
        yil: int.tryParse(_yilController.text) ?? 0,
        yakitTipi: _yakitTipiController.text,
        vites: _vitesController.text,
        kasaTipi: _kasaTipiController.text,
        motorGucu: _motorGucuController.text,
        motorHacmi: _motorHacmiController.text,
        cekis: _cekisController.text,
        // cityConsumption ve highwayConsumption Vehicle modelinizde varsa:
        // cityConsumption: double.tryParse(_cityConsumptionController.text),
        // highwayConsumption: double.tryParse(_highwayConsumptionController.text),
      );

      try {
        await Provider.of<VehicleProvider>(context, listen: false)
            .addNewVehicleToFirestore(newVehicle);

        if (mounted) {
          Navigator.pop(context, true); // Başarılı ekleme sonrası true döndür
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Araç eklenirken hata oluştu: $error')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Araç Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextFormField(controller: _markaController, labelText: 'Marka*'),
              _buildTextFormField(controller: _seriController, labelText: 'Seri*'),
              _buildTextFormField(controller: _modelController, labelText: 'Model*'),
              _buildTextFormField(
                controller: _yilController,
                labelText: 'Yıl*',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Yıl gerekli';
                  if (int.tryParse(value) == null || value.length != 4) return 'Geçerli bir yıl girin (örn: 2020)';
                  return null;
                },
              ),
              _buildTextFormField(controller: _yakitTipiController, labelText: 'Yakıt Tipi*'),
              _buildTextFormField(controller: _vitesController, labelText: 'Vites*'),
              _buildTextFormField(controller: _kasaTipiController, labelText: 'Kasa Tipi*'),
              _buildTextFormField(controller: _motorGucuController, labelText: 'Motor Gücü*'),
              _buildTextFormField(controller: _motorHacmiController, labelText: 'Motor Hacmi*'),
              _buildTextFormField(controller: _cekisController, labelText: 'Çekiş*'),
              const SizedBox(height: 16),

              // Eğer cityConsumption ve highwayConsumption alanlarını
              // Vehicle modelinize eklediyseniz ve formda olmasını istiyorsanız:
              // _buildTextFormField(
              //   controller: _cityConsumptionController,
              //   labelText: 'Şehir İçi Tüketim (L/100km) (Opsiyonel)',
              //   keyboardType: TextInputType.numberWithOptions(decimal: true),
              //   validator: (value) {
              //     if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
              //       return 'Geçerli bir sayı giriniz';
              //     }
              //     return null;
              //   },
              // ),
              // _buildTextFormField(
              //   controller: _highwayConsumptionController,
              //   labelText: 'Şehir Dışı Tüketim (L/100km) (Opsiyonel)',
              //   keyboardType: TextInputType.numberWithOptions(decimal: true),
              //   validator: (value) {
              //     if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
              //       return 'Geçerli bir sayı giriniz';
              //     }
              //     return null;
              //   },
              // ),
              // const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Aracı Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        ),
        keyboardType: keyboardType,
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return '$labelText alanı boş bırakılamaz';
          }
          return null;
        },
      ),
    );
  }
}