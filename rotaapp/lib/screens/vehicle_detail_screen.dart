// lib/screens/vehicle_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vehicle.dart'; // Vehicle modelini import ediyoruz
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
  late TextEditingController _markaController;
  late TextEditingController _seriController;
  late TextEditingController _modelController;
  late TextEditingController _yilController;
  late TextEditingController _yakitTipiController;
  late TextEditingController _vitesController;
  late TextEditingController _kasaTipiController;
  late TextEditingController _motorGucuController;
  late TextEditingController _motorHacmiController;
  late TextEditingController _cekisController;
  late TextEditingController _cityConsumptionController;
  late TextEditingController _highwayConsumptionController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _markaController = TextEditingController(text: widget.vehicle.marka);
    _seriController = TextEditingController(text: widget.vehicle.seri);
    _modelController = TextEditingController(text: widget.vehicle.model);
    _yilController = TextEditingController(text: widget.vehicle.yil.toString());
    _yakitTipiController = TextEditingController(text: widget.vehicle.yakitTipi);
    _vitesController = TextEditingController(text: widget.vehicle.vites);
    _kasaTipiController = TextEditingController(text: widget.vehicle.kasaTipi);
    _motorGucuController = TextEditingController(text: widget.vehicle.motorGucu);
    _motorHacmiController = TextEditingController(text: widget.vehicle.motorHacmi);
    _cekisController = TextEditingController(text: widget.vehicle.cekis);
    _cityConsumptionController =
        TextEditingController(text: widget.vehicle.cityConsumption?.toString() ?? ''); // Nullable olduğu için kontrol
    _highwayConsumptionController = TextEditingController(
        text: widget.vehicle.highwayConsumption?.toString() ?? ''); // Nullable olduğu için kontrol
  }

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
    _cityConsumptionController.dispose();
    _highwayConsumptionController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing && mounted) { // mounted kontrolü eklendi
        _initializeControllers(); 
      }
    });
  }

  Future<void> _saveChanges() async { // async yapıldı
    if (!mounted) return;

    // Değerleri doğrula (örneğin yıl ve tüketimler sayısal mı?)
    final int? yil = int.tryParse(_yilController.text);
    final double? cityConsumption = double.tryParse(_cityConsumptionController.text);
    final double? highwayConsumption = double.tryParse(_highwayConsumptionController.text);

    if (yil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir üretim yılı girin.')),
      );
      return;
    }
    // Diğer doğrulamalar eklenebilir

    final updatedVehicle = Vehicle(
      id: widget.vehicle.id,
      marka: _markaController.text,
      seri: _seriController.text,
      model: _modelController.text,
      yil: yil, // int.parse yerine tryParse ile alınan değer
      yakitTipi: _yakitTipiController.text,
      vites: _vitesController.text,
      kasaTipi: _kasaTipiController.text,
      motorGucu: _motorGucuController.text,
      motorHacmi: _motorHacmiController.text,
      cekis: _cekisController.text,
      cityConsumption: cityConsumption, // double.parse yerine tryParse
      highwayConsumption: highwayConsumption, // double.parse yerine tryParse
      // vehicleType alanı Vehicle modelinde yok, bu yüzden kaldırıldı.
      // Eğer vehicleType'ı Vehicle modeline eklediyseniz, buraya da ekleyin:
      // vehicleType: _vehicleTypeController.text, // Örneğin
    );

    try {
      // VehicleProvider'da updateVehicle metodu olduğundan emin olun
      await Provider.of<VehicleProvider>(context, listen: false)
          .updateVehicle(updatedVehicle); // await eklendi
      if (mounted) {
         _toggleEdit(); // State'i güncelle
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç bilgileri güncellendi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme başarısız: $error')),
        );
      }
    }
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
          Expanded( // Değer uzunsa sığması için
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.end, // Değeri sağa yasla
              overflow: TextOverflow.ellipsis, // Taşan metni ... ile göster
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller,
      {TextInputType? keyboardType, bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField( // TextField yerine TextFormField daha iyi validasyon sağlar
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // Daha kompakt görünüm
        ),
        validator: (value) { // Basit bir validasyon örneği
          if (value == null || value.isEmpty) {
            return '$label boş bırakılamaz';
          }
          if (isNumeric && double.tryParse(value) == null) {
            return 'Lütfen geçerli bir sayı girin';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.model), // Veya widget.vehicle.marka + widget.vehicle.model
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save_alt_outlined : Icons.edit_outlined), // Daha belirgin ikonlar
            tooltip: _isEditing ? 'Kaydet' : 'Düzenle',
            onPressed: _isEditing ? _saveChanges : _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form( // TextFormField kullanıyorsanız Form widget'ı ile sarmalayın
          // key: _formKey, // Eğer validasyon için bir GlobalKey kullanacaksanız
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Araç Bilgileri',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (_isEditing) ...[
                        _buildEditField('Marka', _markaController),
                        _buildEditField('Seri', _seriController),
                        _buildEditField('Model', _modelController),
                        _buildEditField('Üretim Yılı', _yilController, keyboardType: TextInputType.number, isNumeric: true),
                        _buildEditField('Yakıt Tipi', _yakitTipiController),
                        _buildEditField('Vites', _vitesController),
                        _buildEditField('Kasa Tipi', _kasaTipiController),
                        _buildEditField('Motor Gücü (BG)', _motorGucuController),
                        _buildEditField('Motor Hacmi (cc)', _motorHacmiController),
                        _buildEditField('Çekiş', _cekisController),
                        _buildEditField(
                            'Şehir İçi Tüketim (L/100km)', _cityConsumptionController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true), isNumeric: true),
                        _buildEditField(
                            'Şehir Dışı Tüketim (L/100km)', _highwayConsumptionController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true), isNumeric: true),
                      ] else ...[
                        _buildDetailItem('Marka', widget.vehicle.marka),
                        _buildDetailItem('Seri', widget.vehicle.seri),
                        _buildDetailItem('Model', widget.vehicle.model),
                        _buildDetailItem('Üretim Yılı', widget.vehicle.yil.toString()),
                        _buildDetailItem('Yakıt Tipi', widget.vehicle.yakitTipi),
                        _buildDetailItem('Vites', widget.vehicle.vites),
                        _buildDetailItem('Kasa Tipi', widget.vehicle.kasaTipi),
                        _buildDetailItem('Motor Gücü', widget.vehicle.motorGucu),
                        _buildDetailItem('Motor Hacmi', widget.vehicle.motorHacmi),
                        _buildDetailItem('Çekiş', widget.vehicle.cekis),
                        _buildDetailItem('Şehir İçi Tüketim',
                            '${widget.vehicle.cityConsumption?.toStringAsFixed(1) ?? '-'} L/100km'),
                        _buildDetailItem('Şehir Dışı Tüketim',
                            '${widget.vehicle.highwayConsumption?.toStringAsFixed(1) ?? '-'} L/100km'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!_isEditing)
                SizedBox( // Butonun tam genişlikte olması için
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // TODO: Araç silme işlevi eklenecek (VehicleProvider'a deleteVehicle metodu eklenmeli)
                      final confirmDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Aracı Sil'),
                          content: Text('${widget.vehicle.marka} ${widget.vehicle.model} aracını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('İptal')),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Sil', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirmDelete == true && mounted) {
                        try {
                          // await Provider.of<VehicleProvider>(context, listen: false).deleteVehicle(widget.vehicle.id);
                          // Navigator.of(context).pop(); // Detay ekranından çık
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   const SnackBar(content: Text('Araç silindi.')),
                          // );
                           ScaffoldMessenger.of(context).showSnackBar( // Şimdilik
                            const SnackBar(content: Text('Araç silme özelliği yakında.')),
                          );
                        } catch (error) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Silme başarısız: $error')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Bu Aracı Sil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              const SizedBox(height: 20), // Alt boşluk
            ],
          ),
        ),
      ),
    );
  }
}