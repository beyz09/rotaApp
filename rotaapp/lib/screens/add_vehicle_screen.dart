import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle.dart';
// uuid paketi eklenmeli: flutter pub add uuid

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _fuelTypeController = TextEditingController();
  final _cityConsumptionController = TextEditingController();
  final _highwayConsumptionController = TextEditingController();

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _fuelTypeController.dispose();
    _cityConsumptionController.dispose();
    _highwayConsumptionController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final vehicle = Vehicle(
        id: DateTime.now().toString(),
        brand: _brandController.text,
        model: _modelController.text,
        fuelType: _fuelTypeController.text,
        cityConsumption: double.parse(_cityConsumptionController.text),
        highwayConsumption: double.parse(_highwayConsumptionController.text),
      );

      Provider.of<VehicleProvider>(context, listen: false).addVehicle(vehicle);
      Navigator.pop(context);
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
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Marka',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen marka giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen model giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fuelTypeController,
                decoration: const InputDecoration(
                  labelText: 'Yakıt Tipi',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen yakıt tipi giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityConsumptionController,
                decoration: const InputDecoration(
                  labelText: 'Şehir İçi Tüketim (L/100km)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen şehir içi tüketim giriniz';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Lütfen geçerli bir sayı giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _highwayConsumptionController,
                decoration: const InputDecoration(
                  labelText: 'Şehir Dışı Tüketim (L/100km)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen şehir dışı tüketim giriniz';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Lütfen geçerli bir sayı giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
}
