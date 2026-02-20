import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dropdown_search/dropdown_search.dart';
class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final salaryController = TextEditingController();
  final noofpersonsController = TextEditingController();
  final timeController = TextEditingController();
  final dateContoller = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );

  bool isSubmitting = false;
  List<String> designations = [];
  List<String> locations = [];
  String? selectedDesignation;
  String? selectedLocation;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([getlocation(), getDesignation()]);
  }

  // API Methods remain the same logic...
  Future<void> getDesignation() async {
    try {
      final response = await ApiService().dio.get("/api/method/application.application.utils.py.api.get_designation");
      if (response.statusCode == 200 && response.data["message"] != null) {
        final List data = response.data["message"];
        if (mounted) setState(() => designations = data.map((e) => e.toString()).toList());
      }
    } catch (e) { debugPrint("Designation error: $e"); }
  }

  Future<void> getlocation() async {
    try {
      final response = await ApiService().dio.get("/api/method/application.application.utils.py.api.get_locations");
      if (response.statusCode == 200 && response.data["message"] != null) {
        final List data = response.data["message"];
        if (mounted) {
          setState(() {
            locations = data.map((e) => e.toString()).toList();
            if (!locations.contains("Add New Location")) locations.add("Add New Location");
          });
        }
      }
    } catch (e) { debugPrint("Location error: $e"); }
  }

  Future<bool> addlocationApi(String location,String street,String latitude,String longitude) async {
    try {
      final response = await ApiService().dio.post("/api/method/application.application.utils.py.api.add_location", data: {"location": location,'street':street,'latitude':latitude,'longitude':longitude});
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDesignation == null || selectedLocation == null) {
      _showError("Please complete all selections");
      return;
    }
    setState(() => isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final postData = {
        "job_title": titleController.text.trim(),
        "designation": selectedDesignation,
        "salary": salaryController.text.trim(),
        "no_of_persons": noofpersonsController.text.trim(),
        "posted_by": prefs.getString('savedEmail'),
        "location": selectedLocation,
        "date": dateContoller.text.trim(),
        "time": timeController.text.trim(),
      };
      final response = await ApiService().dio.post("/api/method/application.application.utils.py.api.post_job", data: postData);
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job Posted Successfully 🎉"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) { _showError("Post failed: $e"); }
    finally { if (mounted) setState(() => isSubmitting = false); }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Create Job Posting", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("Basic Info", Icons.info_outline),
              _buildCard([
                _buildTextField(titleController, "Job Title", Icons.work_outline),
                const SizedBox(height: 16),
                _buildDropdown("Select Designation", Icons.badge_outlined, selectedDesignation, designations, (val) => setState(() => selectedDesignation = val)),
              ]),
              
              const SizedBox(height: 25),
              _buildSectionHeader("Job Details", Icons.list_alt),
              _buildCard([
                _buildTextField(salaryController, "Salary", Icons.payments_outlined, isNumber: true),
                const SizedBox(height: 16),
                _buildTextField(noofpersonsController, "No.of Persons", Icons.groups_outlined, isNumber: true),
              ]),

              const SizedBox(height: 25),
              _buildSectionHeader("Logistics", Icons.location_city_outlined),
              _buildCard([
                _buildLocationDropdown(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(dateContoller, "Start Date", Icons.calendar_today, isDate: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTimePickerField()),
                  ],
                ),
              ]),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                  ),
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("PUBLISH JOB", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          // Icon(icon, size: 20, color: Colors.indigo),
          // const SizedBox(width: 8),
          // Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, bool isDate = false}) {
    return TextFormField(
      controller: controller,
      readOnly: isDate,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onTap: isDate ? () => _selectDate() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
    );
  }

 Widget _buildDropdown(String label, IconData icon, String? value, List<String> items, Function(String?) onChanged) {
  return DropdownButtonFormField<String>(
    value: value,
    isExpanded: true, // 1. Allow the dropdown to fill width
    items: items.map((d) => DropdownMenuItem(
      value: d,
      child: Text(
        d,
        overflow: TextOverflow.ellipsis, // 2. Handle long text with "..."
        maxLines: 1,
      ),
    )).toList(),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.indigo.withOpacity(0.7)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
      // 3. Optional: Reduce content padding if still tight
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
    ),
    validator: (v) => v == null ? "Required" : null,
  );
}

  Widget _buildLocationDropdown() {
    return DropdownSearch<String>(
      items: (filter, loadProps) => locations,
      suffixProps: const DropdownSuffixProps(
        dropdownButtonProps: DropdownButtonProps(iconOpened: Icon(Icons.arrow_drop_down)),
      ),
      decoratorProps: DropDownDecoratorProps(
        decoration: InputDecoration(
          labelText: "Work Location",
          prefixIcon: Icon(Icons.location_city, color: Colors.indigo.withOpacity(0.7)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: "Search location...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        
        itemBuilder: (context, item, isSelected, isHovered) {
          bool isAddButton = item == "Add New Location";
          return ListTile(
            title: Text(
              item,
              style: TextStyle(
                color: isAddButton ? Colors.indigo : Colors.black87,
                fontWeight: isAddButton ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
      selectedItem: selectedLocation,
      onChanged: (val) async {
        if (val == "Add New Location") {
          final dynamic result = await _showAddLocationDialog();
          if (result != null && result is Map) {
            if (await addlocationApi(result['city'], result['street'], result['latitude'], result['longitude'])) {
              setState(() {
                locations.insert(0, result['city']);
                selectedLocation = result['city'];
              });
            }
          }
        } else {
          setState(() => selectedLocation = val);
        }
      },
      validator: (v) => v == null ? "Required" : null,
    );
  }

  Widget _buildTimePickerField() {
    return InkWell(
      onTap: () async {
        TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
        if (picked != null) setState(() => timeController.text = picked.format(context));
      },
      child: IgnorePointer(
        child: TextFormField(
          controller: timeController,
          decoration: InputDecoration(
            labelText: "Time",
            prefixIcon: Icon(Icons.access_time, color: Colors.indigo.withOpacity(0.7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (v) => v == null || v.isEmpty ? "Required" : null,
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (picked != null) setState(() => dateContoller.text = picked.toIso8601String().split('T').first);
  }

  Future<Map<String, String>?> _showAddLocationDialog() async {
  
  TextEditingController controller = TextEditingController();
  TextEditingController streetcontoller = TextEditingController();
  TextEditingController latitudeController = TextEditingController();
  TextEditingController longitudeController = TextEditingController();
  LatLng? selectedPoint;

 return showDialog<Map<String, String>>( 
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Location"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: streetcontoller,
              decoration: const InputDecoration(
                hintText: "Street",
                prefixIcon: Icon(Icons.streetview)
              ),
            ),
            // const SizedBox(height:15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "City",
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            // TextField(
            //   controller: latitudeController,
            //   readOnly: true,
            //   decoration: const InputDecoration(
            //     hintText: "Latitude",
            //     prefixIcon: Icon(Icons.streetview),
            //   ),
            // ),
            // TextField(
            //   controller: longitudeController,
            //   readOnly: true,
            //   decoration: const InputDecoration(
            //     hintText: "Longitude",
            //     prefixIcon: Icon(Icons.streetview),
            //   ),
            // ),
            const SizedBox(height: 15),

            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(11.0168, 76.9558),
                    initialZoom: 12,
                    onTap: (tapPosition, point) async {
                      setDialogState(() => selectedPoint = point);
                      print('-------------------------------');
                      print(point);
                      try {
                        List<Placemark> placemarks = await placemarkFromCoordinates(
                          point.latitude, 
                          point.longitude
                        );
                        print(tapPosition);
                        print("plaecemarksers ....................");
                        print(placemarks);
                        if (placemarks.isNotEmpty) {
                          Placemark place = placemarks[0];
                          String street = place.street ?? '';
                          String subLocality = place.subLocality ?? '';
                          String city = place.locality ?? '';
                          String postCode = place.postalCode ?? '';
                          String fullName = "$street, $subLocality, $city - $postCode".trim();
                        
                          fullName = fullName.replaceAll(RegExp(r', ,|,,'), ',').trim();
                          
                          streetcontoller.text = fullName.isEmpty ? "Unknown Location" : fullName;
                          controller.text = city;
                          latitudeController.text = point.latitude.toStringAsFixed(6);
                          longitudeController.text = point.longitude.toStringAsFixed(6);
                        }
                      } catch (e) {
                        controller.text = "Error finding address";
                        controller.text = "Unknown City";
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: '',
                    ),
                    // MARKER LAYER: Shows where you tapped
                    if (selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPoint!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text("Tap on the map to select a city", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                "city": controller.text.trim(),
                "street": streetcontoller.text.trim(),
                "latitude": latitudeController.text.trim(),
                "longitude": longitudeController.text.trim(),
              });
            }, 
            child: const Text("Confirm"),
          ),
        ],
      ),
    ),
  );
}
}