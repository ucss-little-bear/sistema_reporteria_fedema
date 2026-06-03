class Usuario {
  final int idUsuario;
  final int idRol;
  final String nombres;
  final String apellidos;
  final int? dni;
  final String nombreUsuario;
  final String? correo;
  final String? rolDescripcion;
  final int estado;

  Usuario({
    required this.idUsuario,
    required this.idRol,
    required this.nombres,
    required this.apellidos,
    this.dni,
    required this.nombreUsuario,
    this.correo,
    this.rolDescripcion,
    required this.estado,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idUsuario: int.parse(json['id_usuario'].toString()),
      idRol: int.parse(json['id_rol'].toString()),
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',

      dni: json['dni'] != null ? int.tryParse(json['dni'].toString()) : null,
      nombreUsuario: json['nombre_usuario'] ?? '',
      correo: json['correo'] ?? '',
      rolDescripcion: json['rol'],
      estado: json['estado'] != null ? int.parse(json['estado'].toString()) : 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'id_rol': idRol,
      'nombres': nombres,
      'apellidos': apellidos,
      'dni': dni,
      'nombre_usuario': nombreUsuario,
      'correo': correo,
      'rol': rolDescripcion,
      'estado': estado,
    };
  }
}
