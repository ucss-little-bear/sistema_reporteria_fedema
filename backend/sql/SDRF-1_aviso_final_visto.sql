ALTER TABLE Historial_Reporte
ADD COLUMN aviso_final_visto TINYINT(1) NOT NULL DEFAULT 0,
ADD COLUMN fecha_aviso_final_visto DATETIME NULL;
