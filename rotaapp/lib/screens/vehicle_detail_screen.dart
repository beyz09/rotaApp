import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _plateController;
  late TextEditingController _yearController;
  late TextEditingController _fuelTypeController;
  late TextEditingController _cityConsumptionController;
  late TextEditingController _highwayConsumptionController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _brandController = TextEditingController(text: widget.vehicle.brand);
    _modelController = TextEditingController(text: widget.vehicle.model);
    _plateController = TextEditingController(text: widget.vehicle.plate);
    _yearController =
        TextEditingController(text: widget.vehicle.year.toString());
    _fuelTypeController = TextEditingController(text: widget.vehicle.fuelType);
    _cityConsumptionController =
        TextEditingController(text: widget.vehicle.cityConsumption.toString());
    _highwayConsumptionController = TextEditingController(
        text: widget.vehicle.highwayConsumption.toString());
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _fuelTypeController.dispose();
    _cityConsumptionController.dispose();
    _highwayConsumptionController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _initializeControllers(); // Düzenleme modundan çıkınca değerleri sıfırla
      }
    });
  }

  void _saveChanges() {
    final updatedVehicle = Vehicle(
      id: widget.vehicle.id,
      brand: _brandController.text,
      model: _modelController.text,
      plate: _plateController.text,
      year: int.parse(_yearController.text),
      fuelType: _fuelTypeController.text,
      cityConsumption: double.parse(_cityConsumptionController.text),
      highwayConsumption: double.parse(_highwayConsumptionController.text),
      vehicleType: widget.vehicle.vehicleType,
    );

    Provider.of<VehicleProvider>(context, listen: false)
        .updateVehicle(updatedVehicle);
    _toggleEdit();
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.plate),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _saveChanges : _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Araç Bilgileri',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (_isEditing) ...[
                      _buildEditField('Marka', _brandController),
                      _buildEditField('Model', _modelController),
                      _buildEditField('Plaka', _plateController),
                      _buildEditField('Üretim Yılı', _yearController,
                          keyboardType: TextInputType.number),
                      _buildEditField('Yakıt Tipi', _fuelTypeController),
                      _buildEditField(
                          'Şehir İçi Tüketim', _cityConsumptionController,
                          keyboardType: TextInputType.number),
                      _buildEditField(
                          'Şehir Dışı Tüketim', _highwayConsumptionController,
                          keyboardType: TextInputType.number),
                    ] else ...[
                      _buildDetailItem('Marka', widget.vehicle.brand),
                      _buildDetailItem('Model', widget.vehicle.model),
                      _buildDetailItem('Plaka', widget.vehicle.plate),
                      _buildDetailItem(
                          'Üretim Yılı', widget.vehicle.year.toString()),
                      _buildDetailItem('Yakıt Tipi', widget.vehicle.fuelType),
                      _buildDetailItem('Şehir İçi Tüketim',
                          '${widget.vehicle.cityConsumption} L/100km'),
                      _buildDetailItem('Şehir Dışı Tüketim',
                          '${widget.vehicle.highwayConsumption} L/100km'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isEditing)
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Araç silme işlevi eklenecek
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Araç silme özelliği yakında eklenecek'),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Aracı Sil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
