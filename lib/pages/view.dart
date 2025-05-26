part of '../main.dart';

class VisualisationCartePage extends StatefulWidget {
  const VisualisationCartePage({Key? key}) : super(key: key);

  @override
  _VisualisationCartePageState createState() => _VisualisationCartePageState();
}

class _VisualisationCartePageState extends State<VisualisationCartePage> {
  final MapController _siteController = MapController();
  final MapController _floorController = MapController();
  SiteProvider? _siteProv;

  bool _isFloor = false;
  Carte? _siteCarte;
  double _siteEffW = 180, _siteEffH = 90;
  ImageProvider? _siteImage;
  List<Polygon> _sitePolys = [];

  Batiment? _selBat;
  int? _selFloorId;
  List<Etage> _floors = [];
  List<Marker> _floorMarkers = [];
  Carte? _floorCarte;
  double _floorEffW = 180, _floorEffH = 90;
  ImageProvider? _floorImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _siteProv = Provider.of<SiteProvider>(context, listen: false);
      _siteProv!.addListener(_onSiteChanged);
      _loadSite();
    });
  }

  @override
  void dispose() {
    _siteProv?.removeListener(_onSiteChanged);
    super.dispose();
  }

  void _onSiteChanged() {
    setState(() {
      _isFloor = false;
      _siteCarte = null;
      _siteImage = null;
      _sitePolys.clear();
      _selBat = null;
      _selFloorId = null;
      _floors.clear();
      _floorMarkers.clear();
      _floorCarte = null;
      _floorImage = null;
    });
    _loadSite();
  }

  Future<void> _loadSite() async {
    final sel = _siteProv!.selectedSite;
    if (sel == null) return;
    final carte = await APICarte.getCarteBySiteId(sel.id);
    if (carte == null) return;

    // Télécharge et décode image
    final bytes = (await http.get(Uri.parse(carte.chemin))).bodyBytes;
    ui.decodeImageFromList(bytes, (img) {
      final w = img.width.toDouble(), h = img.height.toDouble();
      final scale = min(90 / h, 180 / w);
      setState(() {
        _siteEffW = w * scale;
        _siteEffH = h * scale;
        _siteCarte = carte;
        _siteImage = MemoryImage(bytes);
        // Polygones
        final site =
            _siteProv!.getCompleteSiteById(_siteProv!.selectedSite!.id)!;
        _sitePolys = site.batiments.map((bat) {
          final pts = (bat.polygonPoints['points'] as List)
              .map((p) => LatLng(p[0], p[1]))
              .toList();
          return Polygon(
            points: pts,
            color: Colors.blue.withOpacity(0.3),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          );
        }).toList();
      });
    });
  }

  Future<void> _loadFloor(int floorId) async {
    if (_selBat == null) return;
    final data = await APIBatiment.getBuildingAllData(_selBat!.id);
    if (data == null) return;
    setState(() {
      _floors = data.etages;
      _selFloorId = floorId;
      _isFloor = true;
      _floorMarkers = Baes.allBaes.where((b) => b.etageId == floorId).map((b) {
        final hasErr = b.erreurs.any((e) => !e.isSolved && !e.isIgnored);
        return Marker(
          point: LatLng(b.position['lat'], b.position['lng']),
          width: 30,
          height: 30,
          child:
              Icon(Icons.lightbulb, color: hasErr ? Colors.red : Colors.green),
        );
      }).toList();
    });

    final carte = Carte.allCartes.firstWhere((c) => c.etageId == floorId);
    final bytes = (await http.get(Uri.parse(carte.chemin))).bodyBytes;
    ui.decodeImageFromList(bytes, (img) {
      final w = img.width.toDouble(), h = img.height.toDouble();
      final scale = min(90 / h, 180 / w);
      setState(() {
        _floorEffW = w * scale;
        _floorEffH = h * scale;
        _floorCarte = carte;
        _floorImage = MemoryImage(bytes);
      });
    });
  }

  void _onSiteTap(TapPosition _, LatLng p) {
    final site = _siteProv!.getCompleteSiteById(_siteProv!.selectedSite!.id)!;
    for (var bat in site.batiments) {
      final poly = (bat.polygonPoints['points'] as List)
          .map((e) => LatLng(e[0], e[1]))
          .toList();
      if (_pointInPoly(p, poly)) {
        _selBat = bat;
        _loadFloor(bat.etages.first.id);
        break;
      }
    }
  }

  bool _pointInPoly(LatLng pt, List<LatLng> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      var xi = poly[i].latitude, yi = poly[i].longitude;
      var xj = poly[j].latitude, yj = poly[j].longitude;
      final intersect = ((yi > pt.longitude) != (yj > pt.longitude)) &&
          (pt.latitude < (xj - xi) * (pt.longitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFloor ? 'Vue étage' : 'Vue site'),
        leading: _isFloor
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => setState(() => _isFloor = false),
              )
            : null,
      ),
      body: Stack(children: [
        // ─── Site ──────────────────────────────────────────
        if (!_isFloor)
          _siteCarte == null || _siteImage == null
              ? Center(child: CircularProgressIndicator())
              : SiteMapView(
                  key: ValueKey('site_${_siteCarte!.siteId}'),
                  controller: _siteController,
                  carte: _siteCarte!,
                  image: _siteImage!,
                  effH: _siteEffH,
                  effW: _siteEffW,
                  polygons: _sitePolys,
                  onTap: _onSiteTap,
                ),

        // ─── Étage ─────────────────────────────────────────
        if (_isFloor)
          _floorCarte == null || _floorImage == null
              ? Center(child: CircularProgressIndicator())
              : FloorMapView(
                  key: ValueKey('floor_${_selFloorId}'),
                  controller: _floorController,
                  carte: _floorCarte!,
                  image: _floorImage!,
                  effH: _floorEffH,
                  effW: _floorEffW,
                  markers: _floorMarkers,
                ),

        // ─── Dropdown étage ─────────────────────────────────
        if (_isFloor)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _isFloor = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selFloorId,
                      hint: const Text("Sélectionner un étage"),
                      items: _floors
                          .map((e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null && v != _selFloorId) {
                          _loadFloor(v);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class SiteMapView extends StatefulWidget {
  final MapController controller;
  final Carte carte;
  final ImageProvider image;
  final double effH, effW;
  final List<Polygon> polygons;
  final void Function(TapPosition, LatLng) onTap;

  const SiteMapView({
    Key? key,
    required this.controller,
    required this.carte,
    required this.image,
    required this.effH,
    required this.effW,
    required this.polygons,
    required this.onTap,
  }) : super(key: key);

  @override
  _SiteMapViewState createState() => _SiteMapViewState();
}

class _SiteMapViewState extends State<SiteMapView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.move(
        LatLng(widget.carte.centerLat, widget.carte.centerLng),
        widget.carte.zoom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: LatLng(widget.carte.centerLat, widget.carte.centerLng),
        initialZoom: widget.carte.zoom,
        maxZoom: widget.carte.zoom + 10,
        minZoom: widget.carte.zoom - 10,
        onTap: widget.onTap,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(widget.effH, widget.effW),
              ),
              imageProvider: widget.image,
            ),
          ],
        ),
        if (widget.polygons.isNotEmpty) PolygonLayer(polygons: widget.polygons),
      ],
    );
  }
}

class FloorMapView extends StatefulWidget {
  final MapController controller;
  final Carte carte;
  final ImageProvider image;
  final double effH, effW;
  final List<Marker> markers;

  const FloorMapView({
    Key? key,
    required this.controller,
    required this.carte,
    required this.image,
    required this.effH,
    required this.effW,
    required this.markers,
  }) : super(key: key);

  @override
  _FloorMapViewState createState() => _FloorMapViewState();
}

class _FloorMapViewState extends State<FloorMapView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.move(
        LatLng(widget.carte.centerLat, widget.carte.centerLng),
        widget.carte.zoom,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        crs: const CrsSimple(),
        initialCenter: LatLng(widget.carte.centerLat, widget.carte.centerLng),
        initialZoom: widget.carte.zoom,
        maxZoom: widget.carte.zoom + 10,
        minZoom: widget.carte.zoom - 10,
      ),
      children: [
        OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: LatLngBounds(
                const LatLng(0, 0),
                LatLng(widget.effH, widget.effW),
              ),
              imageProvider: widget.image,
            ),
          ],
        ),
        if (widget.markers.isNotEmpty) MarkerLayer(markers: widget.markers),
      ],
    );
  }
}
