import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Segoe UI',
        useMaterial3: true,
      ),
      home: const DocumentScreen(),
    );
  }
}

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  PlatformFile? selectedFile;
  bool isAnalyzing = false;
  bool isDragging = false;
  Map<String, double> results = {};

  
  final Map<String, String> classDisplayNames = {
    'insan_kaynaklari': 'İnsan Kaynakları',
    'hukuk': 'Hukuk',
    'ar_ge': 'Ar-Ge',
    'finans': 'Finans',
    'musteri_hizmetleri': 'Müşteri Hizmetleri',
  };

  // API Baglantisi
  Future<void> startAnalysis(PlatformFile file) async {
    setState(() {
      selectedFile = file;
      isAnalyzing = true;
      results = {}; // Eski sonuclari temizleyebilmem icin
    });

    try {
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://98f2bacf138a.ngrok-free.app/predict'), //sunucuyu baslatip gelen guncel linki buraya eklemem gerekiyor
      );

      // pdf
      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path!,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        
        setState(() {
          // modelden gelen veriyi ayirdigim kisma aktariyorum burda cok hata aldigim icin test kodlari var
          results = data.map((key, value) => MapEntry(key, value.toDouble()));
        });
      } else {
        _showErrorMessage("Analiz sırasında bir hata oluştu: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorMessage("Sunucuya bağlanılamadı. IP adresini ve sunucuyu kontrol edin.");
    } finally {
      setState(() {
        isAnalyzing = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      startAnalysis(result.files.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Belge Departman Tahmini",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w200,
                    color: Color(0xFF1E293B),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 50),
                _buildMainCard(),
                const SizedBox(height: 40),
                if (selectedFile != null && !isAnalyzing) _buildRefreshButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: 950,
      constraints: const BoxConstraints(minHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DropTarget(
                onDragEntered: (details) => setState(() => isDragging = true),
                onDragExited: (details) => setState(() => isDragging = false),
                onDragDone: (detail) {
                  setState(() => isDragging = false);
                  if (detail.files.isNotEmpty) {
                    final file = detail.files.first;
                    startAnalysis(PlatformFile(
                      name: file.name,
                      size: 0,
                      path: file.path,
                    ));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isDragging ? const Color(0xFFF5F3FF) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      bottomLeft: Radius.circular(40),
                    ),
                    border: isDragging ? Border.all(color: const Color(0xFF6366F1), width: 2) : null,
                  ),
                  child: _buildUploadSection(),
                ),
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 60),
              color: const Color(0xFFF1F5F9),
            ),
            Expanded(child: _buildResultsSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDragging ? Icons.download_for_offline : Icons.picture_as_pdf_rounded,
              size: 70, 
              color: const Color(0xFF6366F1)
            ),
          ),
          const SizedBox(height: 30),
          Text(
            isDragging ? "Buraya Bırakın" : "PDF Analizi",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          Text(
            selectedFile?.name ?? "Analiz için PDF dosyasını sürükleyin veya seçin",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: pickFile,
            child: const Text("Dosya Seç", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (selectedFile == null) {
      return const Center(child: Text("Analiz sonucu burada görünecek..."));
    }

    if (isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6366F1)),
            SizedBox(height: 20),
            Text("Modeliniz analiz ediyor..."),
          ],
        ),
      );
    }

    // Modelin tahminini en yuksek departmandan dusuge dogru gosterecek
    var sortedKeys = results.keys.toList()
      ..sort((a, b) => results[b]!.compareTo(results[a]!));

    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: sortedKeys.map((key) {
          return _buildResultBar(classDisplayNames[key] ?? key, results[key]!);
        }).toList(),
      ),
    );
  }

  Widget _buildResultBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              Text(
                "%${(value * 100).toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10B981), fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 12,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: TextButton.icon(
        onPressed: () => setState(() => selectedFile = null),
        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
        label: const Text("Yeni Belge Yükle", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20)),
      ),
    );
  }
}


