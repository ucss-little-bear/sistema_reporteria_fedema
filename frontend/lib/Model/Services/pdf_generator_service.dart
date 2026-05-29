import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGeneratorService {
  Future<Uint8List> generarPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final info = data['info'] ?? {};
    final List<dynamic> filas = data['resultados'] ?? [];
    final String tipo = (info['tipo_reporte'] ?? 'Documento').toString();

    // Configuración de página
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          if (tipo.contains('Boleta')) {
            return _buildContenidoBoleta(info, filas);
          } else if (tipo.contains('Certificado')) {
            return _buildContenidoCertificado(info, filas);
          } else if (tipo.contains('Rendimiento')) {
            return _buildContenidoRendimiento(info, filas);
          } else {
            return _buildContenidoGenerico(info, filas);
          }
        },
        footer: (context) => _buildFooter(context),
      ),
    );

    return pdf.save();
  }

  // ============================================================
  // 1. LÓGICA REPORTE DE RENDIMIENTO
  // ============================================================
  List<pw.Widget> _buildContenidoRendimiento(
    Map<String, dynamic> info,
    List<dynamic> filas,
  ) {
    String rawParam = (info['parametros'] ?? "").toString();
    String anio = "---";
    String nivel = "---";
    String bimestre = "---";
    String salones = "---";

    if (rawParam.contains('|')) {
      final parts = rawParam.split('|');
      for (var p in parts) {
        if (p.trim().startsWith("AÑO:")) anio = p.replaceAll("AÑO:", "").trim();
        if (p.trim().startsWith("NIVEL:"))
          nivel = p.replaceAll("NIVEL:", "").trim();
        if (p.trim().startsWith("BIM:"))
          bimestre = p.replaceAll("BIM:", "").trim();
        if (p.trim().startsWith("SALONES:"))
          salones = p.replaceAll("SALONES:", "").trim();
      }
    }

    final stats = _calcularEstadisticas(filas);

    return [
      _buildHeader("REPORTE DE RENDIMIENTO ACADÉMICO"),
      pw.SizedBox(height: 15),
      _buildInfoPanelRendimiento(anio, nivel, bimestre, salones),
      pw.SizedBox(height: 20),

      pw.Text(
        "1. ANÁLISIS GRÁFICO",
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
      ),
      pw.SizedBox(height: 10),

      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildGraficoNotas(stats['distribucionNotas']),
          pw.SizedBox(width: 20),
          _buildGraficoAsistencia(
            stats['totalAsistencias'],
            stats['totalFaltas'],
            stats['totalTardanzas'],
          ),
        ],
      ),

      pw.SizedBox(height: 25),
      pw.Text(
        "2. INDICADORES DE ATENCIÓN (TOPS)",
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
      ),
      pw.SizedBox(height: 10),

      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _buildTopTable(
              "Rendimiento Bajo (Promedio)",
              stats['topBajasNotas'],
              isGrade: true,
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Expanded(
            child: _buildTopTable(
              "Ausentismo/Tardanzas",
              stats['topAsistencia'],
              isGrade: false,
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 50),
      _buildFirmasSection('Rendimiento', info),
    ];
  }

  // ============================================================
  // 2. LÓGICA CERTIFICADO
  // ============================================================
  List<pw.Widget> _buildContenidoCertificado(
    Map<String, dynamic> info,
    List<dynamic> filas,
  ) {
    String rawParam = (info['parametros'] ?? "").toString();
    String alumno = "---";
    String codigo = "---";
    String anio = "---";

    if (rawParam.contains('|')) {
      final parts = rawParam.split('|');
      for (var p in parts) {
        if (p.trim().startsWith("ALUMNO:"))
          alumno = p.replaceAll("ALUMNO:", "").trim();
        if (p.trim().startsWith("COD:"))
          codigo = p.replaceAll("COD:", "").trim();
        if (p.trim().startsWith("AÑO:")) anio = p.replaceAll("AÑO:", "").trim();
      }
    }

    final row = filas.isNotEmpty ? filas.first : {};
    String puesto = row['puesto_obtenido']?.toString() ?? "-";
    String total = row['total_alumnos_grado']?.toString() ?? "-";
    String merito = row['merito_alcanzado']?.toString() ?? "-";

    final dataCursos = filas
        .map(
          (r) => [
            (r['nombre_curso'] ?? '-').toString(),
            (r['nota_final_curso'] ?? '-').toString(),
          ],
        )
        .toList();

    return [
      _buildHeader("CERTIFICADO DE ESTUDIOS"),
      pw.SizedBox(height: 20),

      pw.Container(
        width: double.infinity,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Se otorga el presente documento a:",
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              alumno,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                pw.Text(
                  "Código de Matrícula: ",
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  codigo,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Text(
                  "Año Lectivo: ",
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  anio,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 25),

      pw.Center(
        child: pw.Container(
          width: 400,
          padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                "CONSTANCIA DE MÉRITO ACADÉMICO",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                "El estudiante ocupa el PUESTO $puesto de $total alumnos.",
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
              pw.RichText(
                textAlign: pw.TextAlign.center,
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: "MÉRITO: ",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text: merito,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      pw.SizedBox(height: 30),

      pw.Text(
        "PROMEDIOS FINALES",
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
      pw.SizedBox(height: 5),
      pw.TableHelper.fromTextArray(
        headers: ['Curso', 'Nota Final'],
        data: dataCursos,
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.white,
        ),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
        columnWidths: {
          0: const pw.FlexColumnWidth(4),
          1: const pw.FlexColumnWidth(1),
        },
        border: pw.TableBorder.all(color: PdfColors.grey),
      ),

      pw.SizedBox(height: 50),
      _buildFirmasSection('Certificado', info),
    ];
  }

  // ============================================================
  // 3. LÓGICA BOLETA
  // ============================================================
  List<pw.Widget> _buildContenidoBoleta(
    Map<String, dynamic> info,
    List<dynamic> filas,
  ) {
    String rawParam = (info['parametros'] ?? "").toString();
    String alumno = "---";
    String codigo = "---";
    if (rawParam.contains('|')) {
      final parts = rawParam.split('|');
      for (var p in parts) {
        if (p.trim().startsWith("Alumno:"))
          alumno = p.replaceAll("Alumno:", "").trim();
        if (p.trim().startsWith("Matrícula:"))
          codigo = p.replaceAll("Matrícula:", "").trim();
      }
    }

    String rawInfo = (info['informacion_adicional'] ?? "").toString();
    List<String> partsInfo = rawInfo.split('|');
    String anio = partsInfo.isNotEmpty ? partsInfo[0] : "2025";
    String nivel = partsInfo.length > 1 ? partsInfo[1] : "-";
    String grado = partsInfo.length > 2 ? partsInfo[2] : "-";
    String seccion = partsInfo.length > 3 ? partsInfo[3] : "-";
    String bimestre = partsInfo.length > 4 ? partsInfo[4] : "-";
    String docente = partsInfo.length > 5 ? partsInfo[5] : "---";

    String asis = "0", fal = "0", tar = "0";
    if (filas.isNotEmpty) {
      asis = filas[0]['asis']?.toString() ?? "0";
      fal = filas[0]['fal']?.toString() ?? "0";
      tar = filas[0]['tar']?.toString() ?? "0";
    }

    return [
      _buildHeader("BOLETA DE NOTAS"),
      pw.SizedBox(height: 15),
      _buildInfoTableBoleta(
        alumno,
        codigo,
        nivel,
        grado,
        seccion,
        bimestre,
        anio,
        docente,
      ),
      pw.SizedBox(height: 20),
      if (filas.isEmpty)
        pw.Center(
          child: pw.Text(
            "No hay calificaciones.",
            style: const pw.TextStyle(color: PdfColors.red),
          ),
        )
      else
        _buildGradesTable(filas),
      pw.SizedBox(height: 20),
      _buildAttendanceTable(asis, fal, tar),
      pw.SizedBox(height: 50),
      _buildFirmasSection('Boleta de Notas', info),
    ];
  }

  List<pw.Widget> _buildContenidoGenerico(
    Map<String, dynamic> info,
    List<dynamic> filas,
  ) {
    return [
      _buildHeader("REPORTE"),
      pw.SizedBox(height: 20),
      pw.Text("Sin formato específico."),
    ];
  }

  // ============================================================
  // 4. SECCIÓN DE FIRMAS (DISEÑO TIPO ROBÓTICO / DIGITAL)
  // ============================================================

  pw.Widget _buildFirmasSection(String tipo, Map<String, dynamic> info) {
    bool necesitaFirmaDocente = tipo.contains('Boleta');

    String? firmaSec = info['firma_secretaria']?.toString();
    if (firmaSec == null || firmaSec.isEmpty || firmaSec == "null")
      firmaSec = null;

    String? firmaDir = info['firma_directora']?.toString();
    if (firmaDir == null || firmaDir.isEmpty || firmaDir == "null")
      firmaDir = null;

    String? firmaDoc = info['firma_docente']?.toString();
    if (firmaDoc == null || firmaDoc.isEmpty || firmaDoc == "null")
      firmaDoc = null;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _firmaBlock("Secretaría Académica", firmaSec),
        if (necesitaFirmaDocente) _firmaBlock("Docente Tutor", firmaDoc),
        _firmaBlock("Directora", firmaDir),
      ],
    );
  }

  // Bloque de firma ESTILO DIGITAL SIMPLE
  pw.Widget _firmaBlock(String cargo, String? firmaDigital) {
    return pw.Column(
      // Centramos la columna para que la línea y el cargo queden centrados
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (firmaDigital != null)
          pw.Container(
            width: 140, // Ancho fijo del bloque de texto
            padding: const pw.EdgeInsets.only(bottom: 4),
            // Sin bordes ni colores de fondo
            child: pw.Text(
              firmaDigital,
              // Fuente Courier (Robótica/Máquina de escribir)
              style: pw.TextStyle(
                font: pw.Font.courier(),
                fontSize: 5, // Letra pequeña típica de metadatos digitales
                color: PdfColors.black, // Color negro simple
              ),
              textAlign: pw
                  .TextAlign
                  .left, // Texto alineado a la izquierda como pediste
            ),
          )
        else
          pw.Container(height: 40, width: 140), // Espacio vacío
        // Línea de firma
        pw.Container(width: 140, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),

        // Cargo
        pw.Text(
          cargo,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  // --- MÉTODOS AUXILIARES ---

  Map<String, dynamic> _calcularEstadisticas(List<dynamic> filas) {
    Map<String, dynamic> alumnos = {};
    for (var row in filas) {
      String cod = row['codigo_matricula'].toString();
      String nombre = row['alumno'].toString();
      String notaLetra = row['nota_competencia'].toString();

      int asis = int.tryParse(row['asis_puntual'].toString()) ?? 0;
      int fal = int.tryParse(row['faltas'].toString()) ?? 0;
      int tar = int.tryParse(row['tardanzas'].toString()) ?? 0;

      if (!alumnos.containsKey(cod)) {
        alumnos[cod] = {
          'nombre': nombre,
          'sumNotas': 0.0,
          'countNotas': 0,
          'asis': asis,
          'fal': fal,
          'tar': tar,
        };
      }
      double valorNota = _convertirNota(notaLetra);
      alumnos[cod]['sumNotas'] += valorNota;
      alumnos[cod]['countNotas']++;
    }

    Map<String, int> distNotas = {'AD': 0, 'A': 0, 'B': 0, 'C': 0};
    int totAsis = 0, totFal = 0, totTar = 0;
    List<Map<String, dynamic>> listaRanking = [];

    alumnos.forEach((key, value) {
      double promedio = value['countNotas'] > 0
          ? value['sumNotas'] / value['countNotas']
          : 0;
      value['promedio'] = promedio;
      if (promedio >= 3.5)
        distNotas['AD'] = (distNotas['AD']!) + 1;
      else if (promedio >= 2.5)
        distNotas['A'] = (distNotas['A']!) + 1;
      else if (promedio >= 1.5)
        distNotas['B'] = (distNotas['B']!) + 1;
      else
        distNotas['C'] = (distNotas['C']!) + 1;

      totAsis += (value['asis'] as int);
      totFal += (value['fal'] as int);
      totTar += (value['tar'] as int);
      listaRanking.add(value);
    });

    List<Map<String, dynamic>> topBajas = List.from(listaRanking);
    topBajas.sort((a, b) => a['promedio'].compareTo(b['promedio']));
    List<Map<String, dynamic>> topFaltas = List.from(listaRanking);
    topFaltas.sort(
      (a, b) => ((b['fal'] + b['tar']) as int).compareTo(
        (a['fal'] + a['tar']) as int,
      ),
    );

    return {
      'distribucionNotas': distNotas,
      'totalAsistencias': totAsis,
      'totalFaltas': totFal,
      'totalTardanzas': totTar,
      'topBajasNotas': topBajas.take(5).toList(),
      'topAsistencia': topFaltas.take(5).toList(),
    };
  }

  double _convertirNota(String nota) {
    switch (nota.toUpperCase().trim()) {
      case 'AD':
        return 4.0;
      case 'A':
        return 3.0;
      case 'B':
        return 2.0;
      case 'C':
        return 1.0;
      default:
        return 0.0;
    }
  }

  String _convertirPromedioALetra(double prom) {
    if (prom >= 3.5) return 'AD';
    if (prom >= 2.5) return 'A';
    if (prom >= 1.5) return 'B';
    return 'C';
  }

  pw.Widget _buildInfoPanelRendimiento(
    String anio,
    String nivel,
    String bim,
    String salones,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _rowInfo("Año Lectivo:", anio, "Periodo:", "Bimestre $bim"),
          pw.SizedBox(height: 5),
          _rowInfo(
            "Nivel:",
            nivel,
            "Salones:",
            salones.length > 50 ? "${salones.substring(0, 50)}..." : salones,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildGraficoNotas(Map<String, int> dist) {
    int maxVal = 1;
    dist.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });
    return pw.Container(
      width: 220,
      height: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            "Distribución de Calificaciones",
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _barColumn("AD", dist['AD']!, maxVal, PdfColors.blue),
                _barColumn("A", dist['A']!, maxVal, PdfColors.green),
                _barColumn("B", dist['B']!, maxVal, PdfColors.orange),
                _barColumn("C", dist['C']!, maxVal, PdfColors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _barColumn(String label, int val, int max, PdfColor color) {
    double heightPct = val / max;
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text("$val", style: const pw.TextStyle(fontSize: 8)),
        pw.Container(width: 20, height: 80 * heightPct + 1, color: color),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildGraficoAsistencia(int asis, int fal, int tar) {
    int total = asis + fal + tar;
    if (total == 0) total = 1;
    return pw.Container(
      width: 220,
      height: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              "Resumen de Asistencia",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 15),
          _barRow("Asistencias", asis, total, PdfColors.blue),
          pw.SizedBox(height: 8),
          _barRow("Faltas", fal, total, PdfColors.red),
          pw.SizedBox(height: 8),
          _barRow("Tardanzas", tar, total, PdfColors.orange),
        ],
      ),
    );
  }

  pw.Widget _barRow(String label, int val, int total, PdfColor color) {
    double widthPct = val / total;
    return pw.Row(
      children: [
        pw.Container(
          width: 60,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Expanded(
          child: pw.Stack(
            children: [
              pw.Container(height: 10, color: PdfColors.grey200),
              pw.Container(height: 10, width: 110 * widthPct, color: color),
            ],
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Container(
          width: 25,
          child: pw.Text(
            "$val",
            style: const pw.TextStyle(fontSize: 9),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTopTable(
    String title,
    List<Map<String, dynamic>> data, {
    required bool isGrade,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(5),
          color: PdfColors.grey200,
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FixedColumnWidth(40),
          },
          children: data.map((alumno) {
            String valor;
            if (isGrade) {
              valor = _convertirPromedioALetra(alumno['promedio']);
            } else {
              int totalNegativo =
                  (alumno['fal'] as int) + (alumno['tar'] as int);
              valor = "$totalNegativo";
            }
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    alumno['nombre'],
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.all(4),
                  color: isGrade
                      ? (valor == 'C' ? PdfColors.red50 : null)
                      : null,
                  child: pw.Text(
                    valor,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: (isGrade && valor == 'C')
                          ? PdfColors.red
                          : PdfColors.black,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  pw.Widget _buildHeader(String titulo) {
    return pw.Column(
      children: [
        pw.Text(
          "IEPD LA FE DE MARÍA",
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          "Sistema de Gestión Académica",
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 1, color: PdfColors.black),
        pw.SizedBox(height: 10),
        pw.Text(
          titulo.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoTableBoleta(
    String alu,
    String cod,
    String niv,
    String gra,
    String sec,
    String bim,
    String anio,
    String doc,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          _rowInfo("Estudiante:", alu, "Código:", cod),
          pw.SizedBox(height: 4),
          _rowInfo("Nivel:", niv, "Grado/Sección:", "$gra - $sec"),
          pw.SizedBox(height: 4),
          _rowInfo("Periodo:", "Bimestre $bim - $anio", "Docente:", doc),
        ],
      ),
    );
  }

  pw.Widget _rowInfo(String label1, String val1, String label2, String val2) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: "$label1 ",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.TextSpan(
                  text: val1,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        pw.Expanded(
          flex: 1,
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: "$label2 ",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.TextSpan(
                  text: val2,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildGradesTable(List<dynamic> filas) {
    Map<String, List<dynamic>> cursos = {};
    for (var row in filas) {
      String curso = row['nombre_curso']?.toString() ?? "SIN CURSO";
      if (!cursos.containsKey(curso)) cursos[curso] = [];
      cursos[curso]!.add(row);
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _cellHeader("ÁREA CURRICULAR"),
            _cellHeader("COMPETENCIA"),
            _cellHeader("NOTA"),
            _cellHeader("OBSERVACIÓN"),
          ],
        ),
        ...cursos.entries
            .map((entry) {
              String nombreCurso = entry.key;
              List<dynamic> competencias = entry.value;
              return List.generate(competencias.length, (index) {
                var comp = competencias[index];
                String nota = comp['nota_competencia']?.toString() ?? "-";
                return pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      child: index == 0
                          ? pw.Text(
                              nombreCurso,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            )
                          : null,
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        comp['nombre_competencia']?.toString() ?? "-",
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.all(5),
                      color: (nota == 'C') ? PdfColors.red50 : null,
                      child: pw.Text(
                        nota,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                          color: (nota == 'C')
                              ? PdfColors.red
                              : PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        comp['comentario']?.toString() ?? "",
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                );
              });
            })
            .expand((element) => element)
            .toList(),
      ],
    );
  }

  pw.Widget _cellHeader(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
      ),
    ),
  );

  pw.Widget _buildAttendanceTable(String asis, String fal, String tar) {
    return pw.Container(
      width: 300,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey600),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _cellSimpleHeader("ASISTENCIAS"),
              _cellSimpleHeader("FALTAS"),
              _cellSimpleHeader("TARDANZAS"),
            ],
          ),
          pw.TableRow(
            children: [_cellCenter(asis), _cellCenter(fal), _cellCenter(tar)],
          ),
        ],
      ),
    );
  }

  pw.Widget _cellSimpleHeader(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    ),
  );
  pw.Widget _cellCenter(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Center(
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    ),
  );

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        "Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())} - Pág ${context.pageNumber}/${context.pagesCount}",
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }
}
