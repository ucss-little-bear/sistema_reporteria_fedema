class Reporte {
  final int idReporte;
  final int idTipoReporte;
  final String tipoReporte;
  final int idEstadoReporte;
  final String estadoReporte;
  final String fechaGeneracion;
  final String? rutaArchivo;
  final String? parametros;
  final String? informacionAdicional;
  final String? generador;

  Reporte({
    required this.idReporte,
    required this.idTipoReporte,
    required this.tipoReporte,
    required this.idEstadoReporte,
    required this.estadoReporte,
    required this.fechaGeneracion,
    this.rutaArchivo,
    this.parametros,
    this.informacionAdicional,
    this.generador,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) {
    return Reporte(
      idReporte: int.tryParse(json['id_reporte'].toString()) ?? 0,
      idTipoReporte: int.tryParse(json['id_tipo_reporte'].toString()) ?? 0,
      tipoReporte: json['tipo_reporte'] ?? 'Desconocido',
      idEstadoReporte: int.tryParse(json['id_estado_reporte'].toString()) ?? 0,
      estadoReporte: json['estado_reporte'] ?? 'Desconocido',
      fechaGeneracion: json['fecha_generacion'] ?? '',
      rutaArchivo: json['ruta_archivo'],
      parametros: json['parametros'],
      informacionAdicional: json['informacion_adicional'],
      generador: json['generador'],
    );
  }
}
