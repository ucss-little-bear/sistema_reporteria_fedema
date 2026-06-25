CREATE TABLE IF NOT EXISTS Aviso_Reporte_Visto (
    id_aviso_visto INT AUTO_INCREMENT PRIMARY KEY,
    id_reporte INT NOT NULL,
    id_usuario INT NOT NULL,
    id_rol INT NOT NULL,
    tipo_aviso VARCHAR(50) NOT NULL,
    fecha_visto DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_aviso_reporte_usuario (
        id_reporte,
        id_usuario,
        id_rol,
        tipo_aviso
    ),

    INDEX idx_aviso_usuario_tipo (
        id_usuario,
        id_rol,
        tipo_aviso
    )
);
