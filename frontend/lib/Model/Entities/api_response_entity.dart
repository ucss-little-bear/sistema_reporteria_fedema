class ApiResponse<T> {
  String status;
  String? message;
  T? data;

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
