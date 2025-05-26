import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const MapLocationPicker({
    Key? key,
    this.initialLocation,
    this.title = "Pick a Location",
  }) : super(key: key);

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  void _onTap(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  void _confirmLocation() {
    if (_pickedLocation != null) {
      Navigator.of(context).pop(_pickedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please tap the map to pick a location.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialLocation ?? const LatLng(30.0444, 31.2357), // Default: Cairo
          zoom: 14,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onTap: _onTap,
        markers: _pickedLocation == null
            ? {}
            : {
          Marker(
            markerId: const MarkerId("picked"),
            position: _pickedLocation!,
          )
        },
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _confirmLocation,
        label: const Text("Confirm Location"),
        icon: const Icon(Icons.check),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
