class Usuario {
  final int idUsuario;
  final int idRol;
  final String nombres;
  final String apellidos;
  final int? dni;
  final String nombreUsuario;
  final String? correo;
  final String? rolDescripcion;
  final bool tienePinConfigurado;
  final int estado;
  final bool primerLogin; // ¡Nuestro nuevo interruptor!

  Usuario({
    required this.idUsuario,
    required this.idRol,
    required this.nombres,
    required this.apellidos,
    this.dni,
    required this.nombreUsuario,
    this.correo,
    this.rolDescripcion,
    required this.tienePinConfigurado,
    required this.estado,
    this.primerLogin = false, 
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
      tienePinConfigurado: json['tienePinConfigurado'] ?? false,
      estado: json['estado'] != null ? int.parse(json['estado'].toString()) : 1,
      // Aquí le enseñamos a leer el interruptor de la base de datos
      primerLogin: json['primer_login'] != null ? int.parse(json['primer_login'].toString()) == 1 : false,
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
      'primer_login': primerLogin ? 1 : 0,
    };
  }

  Usuario copyWith({
    int? idUsuario,
    int? idRol,
    String? nombres,
    String? apellidos,
    int? dni,
    String? nombreUsuario,
    String? correo,
    String? rolDescripcion,
    int? estado,
    bool? tienePinConfigurado,
  }) {
    return Usuario(
      idUsuario: idUsuario ?? this.idUsuario,
      idRol: idRol ?? this.idRol,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      dni: dni ?? this.dni, // Mantiene el actual si no se pasa uno nuevo
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      correo: correo ?? this.correo,
      rolDescripcion: rolDescripcion ?? this.rolDescripcion,
      estado: estado ?? this.estado,
      tienePinConfigurado: tienePinConfigurado ?? this.tienePinConfigurado,
    );
  }
}
