class ApiResponse<T> {
  String status; // "success" o "error"
  String? message; // Mensaje descriptivo
  T? data; // Datos dinámicos (puede ser Usuario, Lista de Reportes, etc.)

  ApiResponse({required this.status, this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? fromJsonT,
  ) {
    return ApiResponse(
      status: json['status'],
      message: json['message'],
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : null,
    );
  }
}
