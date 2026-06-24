<?php

if (!file_exists('Conexion.php')) {
    die(json_encode(["status" => "error", "message" => "Falta conexion.php"]));
}
require_once 'Conexion.php';

class Negocio {
    private $conn;
    private $db;
    

    public function __construct() {
        $this->db = new Conexion();
        $this->conn = $this->db->conectar();
        
        if (!$this->conn) {
            throw new Exception("No se pudo establecer conexión en Negocio");
        }
    }





    public function loginUsuario($usuario, $password) {
        try {


            $query = "SELECT u.id_usuario, u.nombres, u.apellidos, u.id_rol, r.descripcion as rol, u.contrasena_hash, u.estado 
                      FROM Usuario_Sistema u 
                      JOIN Rol r ON u.id_rol = r.id_rol 
                      WHERE u.nombre_usuario = :usuario LIMIT 1";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":usuario", $usuario);
            
            if (!$stmt->execute()) {

                $error = $stmt->errorInfo();
                return ["status" => "error", "message" => "Error SQL: " . $error[2]];
            }

            if ($stmt->rowCount() > 0) {
                $row = $stmt->fetch(PDO::FETCH_ASSOC);
                

                if ($row['estado'] == 0) {
                    return ["status" => "error", "message" => "Usuario inactivo."];
                }




                if (password_verify($password, $row['contrasena_hash'])) {

                    unset($row['contrasena_hash']);
                    return ["status" => "success", "data" => $row];
                } else {
                    return ["status" => "error", "message" => "Contraseña incorrecta."];
                }
            } else {
                return ["status" => "error", "message" => "Usuario no encontrado."];
            }
        } catch (PDOException $e) {
            return ["status" => "error", "message" => "Error BD: " . $e->getMessage()];
        } catch (Exception $e) {
            return ["status" => "error", "message" => "Error General: " . $e->getMessage()];
        }
    }

    public function cambiarPassword($idUsuario, $newPassword) {
        try {
            $hash = password_hash($newPassword, PASSWORD_DEFAULT);
            
            $query = "UPDATE Usuario_Sistema SET contrasena_hash = :pass WHERE id_usuario = :id";
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":pass", $hash);
            $stmt->bindParam(":id", $idUsuario);

            if ($stmt->execute()) {
                return ["status" => "success", "message" => "Contraseña actualizada"];
            }
            return ["status" => "error", "message" => "No se pudo actualizar la contraseña"];
        } catch (PDOException $e) {
            return ["status" => "error", "message" => "Error BD: " . $e->getMessage()];
        }
    }





    public function listarUsuarios() {
        try {
            $query = "SELECT u.id_usuario, u.id_rol, u.nombres, u.apellidos, u.DNI as dni, u.correo, u.nombre_usuario, u.estado, r.descripcion as rol 
                      FROM Usuario_Sistema u 
                      JOIN Rol r ON u.id_rol = r.id_rol
                      ORDER BY u.apellidos ASC";
            
            $stmt = $this->conn->prepare($query);
            $stmt->execute();
            return ["status" => "success", "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)];
        } catch (PDOException $e) {
            return ["status" => "error", "message" => $e->getMessage()];
        }
    }

    public function crearUsuario($nombres, $apellidos, $dni, $usuario, $password, $idRol, $correo) {
        try {

            $this->conn->beginTransaction();

            $hash = password_hash($password, PASSWORD_DEFAULT);


            $query = "INSERT INTO Usuario_Sistema (id_rol, nombres, apellidos, DNI, nombre_usuario, contrasena_hash, correo, estado) 
                      VALUES (:rol, :nom, :ape, :dni, :user, :pass, :correo, 1)";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":rol", $idRol);
            $stmt->bindParam(":nom", $nombres);
            $stmt->bindParam(":ape", $apellidos);
            $stmt->bindParam(":dni", $dni);
            $stmt->bindParam(":user", $usuario);
            $stmt->bindParam(":pass", $hash);
            $stmt->bindParam(":correo", $correo);

            if (!$stmt->execute()) {
                $this->conn->rollBack();
                return ["status" => "error", "message" => "Error al crear usuario en sistema"];
            }


            if ($idRol == 3) {

                $stmtCheck = $this->conn->prepare("SELECT id_docente FROM Docente WHERE DNI = ?");
                $stmtCheck->execute([$dni]);
                
                if ($stmtCheck->rowCount() == 0) {

                    $sqlDoc = "INSERT INTO Docente (nombres, apellidos, DNI) VALUES (?, ?, ?)";
                    $stmtDoc = $this->conn->prepare($sqlDoc);
                    if (!$stmtDoc->execute([$nombres, $apellidos, $dni])) {
                        $this->conn->rollBack();
                        return ["status" => "error", "message" => "Error al registrar en tabla Docente"];
                    }
                } else {

                    $sqlUpdDoc = "UPDATE Docente SET nombres = ?, apellidos = ? WHERE DNI = ?";
                    $stmtUpdDoc = $this->conn->prepare($sqlUpdDoc);
                    $stmtUpdDoc->execute([$nombres, $apellidos, $dni]);
                }
            }

            $this->conn->commit();
            return ["status" => "success", "message" => "Usuario creado correctamente"];
        } catch (PDOException $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            return ["status" => "error", "message" => "Error BD: " . $e->getMessage()];
        }
    }


    public function editarUsuario($idUsuario, $nombres, $apellidos, $dni, $usuario, $idRol, $correo) {
        try {
            $this->conn->beginTransaction();



            $stmtOld = $this->conn->prepare("SELECT DNI FROM Usuario_Sistema WHERE id_usuario = ?");
            $stmtOld->execute([$idUsuario]);
            $oldDni = $stmtOld->fetchColumn();

            $query = "UPDATE Usuario_Sistema 
                      SET nombres = :nom, apellidos = :ape, DNI = :dni, nombre_usuario = :user, id_rol = :rol, correo = :correo 
                      WHERE id_usuario = :id";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":nom", $nombres);
            $stmt->bindParam(":ape", $apellidos);
            $stmt->bindParam(":dni", $dni);
            $stmt->bindParam(":user", $usuario);
            $stmt->bindParam(":rol", $idRol);
            $stmt->bindParam(":correo", $correo);
            $stmt->bindParam(":id", $idUsuario);

            if (!$stmt->execute()) {
                $this->conn->rollBack();
                return ["status" => "error", "message" => "No se pudo actualizar el usuario"];
            }


            if ($idRol == 3) {


                $stmtCheck = $this->conn->prepare("SELECT id_docente FROM Docente WHERE DNI = ?");
                $stmtCheck->execute([$dni]);
                
                if ($stmtCheck->rowCount() > 0) {

                    $sqlDoc = "UPDATE Docente SET nombres = ?, apellidos = ? WHERE DNI = ?";
                    $stmtDoc = $this->conn->prepare($sqlDoc);
                    $stmtDoc->execute([$nombres, $apellidos, $dni]);
                } else {

                    if ($oldDni && $oldDni != $dni) {
                        $stmtCheckOld = $this->conn->prepare("SELECT id_docente FROM Docente WHERE DNI = ?");
                        $stmtCheckOld->execute([$oldDni]);
                        if ($stmtCheckOld->rowCount() > 0) {

                            $sqlDoc = "UPDATE Docente SET nombres = ?, apellidos = ?, DNI = ? WHERE DNI = ?";
                            $stmtDoc = $this->conn->prepare($sqlDoc);
                            $stmtDoc->execute([$nombres, $apellidos, $dni, $oldDni]);
                        } else {

                            $sqlDoc = "INSERT INTO Docente (nombres, apellidos, DNI) VALUES (?, ?, ?)";
                            $stmtDoc = $this->conn->prepare($sqlDoc);
                            $stmtDoc->execute([$nombres, $apellidos, $dni]);
                        }
                    } else {

                        $sqlDoc = "INSERT INTO Docente (nombres, apellidos, DNI) VALUES (?, ?, ?)";
                        $stmtDoc = $this->conn->prepare($sqlDoc);
                        $stmtDoc->execute([$nombres, $apellidos, $dni]);
                    }
                }
            }

            $this->conn->commit();
            return ["status" => "success", "message" => "Usuario actualizado correctamente"];
        } catch (PDOException $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            return ["status" => "error", "message" => "Error BD: " . $e->getMessage()];
        }
    }

    public function cambiarEstadoUsuario($idUsuario, $nuevoEstado) {
        try {
            $query = "UPDATE Usuario_Sistema SET estado = :estado WHERE id_usuario = :id";
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":estado", $nuevoEstado);
            $stmt->bindParam(":id", $idUsuario);

            if ($stmt->execute()) {
                return ["status" => "success", "message" => "Estado actualizado"];
            }
            return ["status" => "error", "message" => "No se pudo actualizar"];
        } catch (PDOException $e) {
            return ["status" => "error", "message" => $e->getMessage()];
        }
    }





    public function registrarArchivoSIAGIE($tipoArchivo, $nombre, $ruta, $idUsuario) {
        try {
            $query = "INSERT INTO Archivo_SIAGIE (tipo_archivo, nombre_archivo, ruta_archivo, fecha_importacion, id_usuario) 
                      VALUES (:tipo, :nombre, :ruta, CURDATE(), :usuario)";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":tipo", $tipoArchivo);
            $stmt->bindParam(":nombre", $nombre);
            $stmt->bindParam(":ruta", $ruta);
            $stmt->bindParam(":usuario", $idUsuario);
            
            if ($stmt->execute()) {
                return ["status" => "success", "id_archivo" => $this->conn->lastInsertId()];
            }
            return ["status" => "error", "message" => "No se pudo registrar el archivo."];
        } catch (PDOException $e) {
            return ["status" => "error", "message" => $e->getMessage()];
        }
    }





    public function crearReporte($idUsuario, $tipoReporte, $parametros, $ruta) {
        try {
            $estadoInicial = 1; 
            
            $query = "INSERT INTO Historial_Reporte (id_usuario, id_tipo_reporte, id_estado_reporte, fecha_generacion, parametros, ruta_archivo) 
                      VALUES (:usuario, :tipo, :estado, NOW(), :params, :ruta)";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":usuario", $idUsuario);
            $stmt->bindParam(":tipo", $tipoReporte);
            $stmt->bindParam(":estado", $estadoInicial);
            $stmt->bindParam(":params", $parametros);
            $stmt->bindParam(":ruta", $ruta);

            if ($stmt->execute()) {
                return ["status" => "success", "id_reporte" => $this->conn->lastInsertId()];
            }
            return ["status" => "error", "message" => "Error al crear reporte."];
        } catch (PDOException $e) {
            return ["status" => "error", "message" => $e->getMessage()];
        }
    }

    public function listarReportes($idUsuario = null, $idRol = null) {

        $sql = "SELECT 
                    h.id_reporte,
                    h.id_tipo_reporte,
                    t.descripcion as tipo_reporte,
                    h.id_estado_reporte,
                    e.descripcion as estado_reporte,
                    h.fecha_generacion,
                    h.parametros,
                    h.ruta_archivo,
                    h.informacion_adicional,
                    CONCAT(u.nombres, ' ', u.apellidos) as generador,
                    -- Recuperamos también las firmas para mostrarlas si es necesario
                    h.firma_secretaria,
                    h.firma_directora,
                    h.firma_docente
                FROM Historial_Reporte h
                JOIN Tipo_Reporte t ON h.id_tipo_reporte = t.id_tipo_reporte
                JOIN Estado_Reporte e ON h.id_estado_reporte = e.id_estado_reporte
                JOIN Usuario_Sistema u ON h.id_usuario = u.id_usuario";






        













        
        if ($idRol == 3) {

            $stmtU = $this->conn->prepare("SELECT CONCAT(apellidos, ', ', nombres) as nombre_completo FROM Usuario_Sistema WHERE id_usuario = ?");
            $stmtU->execute([$idUsuario]);
            $nombreDocente = $stmtU->fetchColumn();
            




            

            $sql .= " WHERE h.informacion_adicional LIKE '%$nombreDocente%'";
        }
        


        $sql .= " ORDER BY h.fecha_generacion DESC";

        $stmt = $this->conn->prepare($sql);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function obtenerAvisosPendientes($idUsuario, $idRol) {
        try {
            $idUsuario = (int)$idUsuario;
            $idRol = (int)$idRol;

            $avisos = [];
            $totalDocumentos = 0;

            if ($idRol === 2) {
                // Directora: reportes generados pendientes de revisión/firma
                $stmt = $this->conn->prepare("
                    SELECT COUNT(*) 
                    FROM Historial_Reporte 
                    WHERE id_estado_reporte = 1
                ");
                $stmt->execute();
                $cantidad = (int)$stmt->fetchColumn();

                if ($cantidad > 0) {
                    $totalDocumentos += $cantidad;
                    $avisos[] = [
                        "id" => "firmar_generados",
                        "titulo" => "Reportes generados pendientes",
                        "descripcion" => "Existen reportes generados pendientes de revisión por Dirección.",
                        "cantidad" => $cantidad,
                        "estado_id" => 1,
                        "modulo_titulo" => "Firmar Generados"
                    ];
                }
            }

            if ($idRol === 1) {
                // Secretaría Académica: reportes revisados pendientes de validación/firma
                $stmt = $this->conn->prepare("
                    SELECT COUNT(*) 
                    FROM Historial_Reporte 
                    WHERE id_estado_reporte = 2
                ");
                $stmt->execute();
                $cantidad = (int)$stmt->fetchColumn();

                if ($cantidad > 0) {
                    $totalDocumentos += $cantidad;
                    $avisos[] = [
                        "id" => "firmar_revisados",
                        "titulo" => "Reportes revisados pendientes",
                        "descripcion" => "Existen reportes revisados listos para validación de Secretaría Académica.",
                        "cantidad" => $cantidad,
                        "estado_id" => 2,
                        "modulo_titulo" => "Firmar Revisados"
                    ];
                }

                // Secretaría Académica: documentos finales disponibles
                $stmt = $this->conn->prepare("
                    SELECT COUNT(*) 
                    FROM Historial_Reporte 
                    WHERE id_estado_reporte = 3
                ");
                $stmt->execute();
                $cantidad = (int)$stmt->fetchColumn();

                if ($cantidad > 0) {
                    $totalDocumentos += $cantidad;
                    $avisos[] = [
                        "id" => "reportes_finales",
                        "titulo" => "Reportes finales disponibles",
                        "descripcion" => "Existen documentos finales disponibles para consulta o exportación.",
                        "cantidad" => $cantidad,
                        "estado_id" => 3,
                        "modulo_titulo" => "Reportes Finales"
                    ];
                }
            }

            if ($idRol === 3) {
                // Docente: obtener su nombre tal como se usa en informacion_adicional
                $stmtU = $this->conn->prepare("
                    SELECT CONCAT(apellidos, ', ', nombres) AS nombre_completo 
                    FROM Usuario_Sistema 
                    WHERE id_usuario = ?
                ");
                $stmtU->execute([$idUsuario]);
                $nombreDocente = $stmtU->fetchColumn();

                if ($nombreDocente) {
                    // Docente: boletas pendientes de firma final
                    $stmt = $this->conn->prepare("
                        SELECT COUNT(*) 
                        FROM Historial_Reporte 
                        WHERE id_estado_reporte = 5
                        AND id_tipo_reporte = 1
                        AND informacion_adicional LIKE ?
                    ");
                    $stmt->execute(["%$nombreDocente%"]);
                    $cantidad = (int)$stmt->fetchColumn();

                    if ($cantidad > 0) {
                        $totalDocumentos += $cantidad;
                        $avisos[] = [
                            "id" => "firmar_boletas",
                            "titulo" => "Boletas pendientes de firma",
                            "descripcion" => "Existen boletas de notas listas para firma final del docente.",
                            "cantidad" => $cantidad,
                            "estado_id" => 5,
                            "modulo_titulo" => "Firmar Boletas"
                        ];
                    }

                    // Docente: boletas finales disponibles
                    $stmt = $this->conn->prepare("
                        SELECT COUNT(*) 
                        FROM Historial_Reporte 
                        WHERE id_estado_reporte = 3
                        AND id_tipo_reporte = 1
                        AND COALESCE(aviso_final_visto, 0) = 0
                        AND informacion_adicional LIKE ?
                    ");
                    $stmt->execute(["%$nombreDocente%"]);
                    $cantidad = (int)$stmt->fetchColumn();

                    if ($cantidad > 0) {
                        $totalDocumentos += $cantidad;
                        $avisos[] = [
                            "id" => "boletas_finales",
                            "titulo" => "Boletas finales disponibles",
                            "descripcion" => "Existen boletas finales disponibles para consulta o descarga.",
                            "cantidad" => $cantidad,
                            "estado_id" => 3,
                            "modulo_titulo" => "Boletas Finales"
                        ];
                    }
                }
            }

            return [
                "status" => "success",
                "message" => "Avisos consultados correctamente.",
                "total" => $totalDocumentos,
                "data" => $avisos
            ];

        } catch (Exception $e) {
            return [
                "status" => "error",
                "message" => "Error al obtener avisos pendientes: " . $e->getMessage()
            ];
        }
    }

    public function marcarBoletasFinalesVistas($idUsuario, $idRol) {
        try {
            $idUsuario = (int)$idUsuario;
            $idRol = (int)$idRol;

            if ($idRol !== 3) {
                return [
                    "status" => "error",
                    "message" => "Solo el rol Docente puede marcar boletas finales como vistas."
                ];
            }

            $stmtU = $this->conn->prepare("
                SELECT CONCAT(apellidos, ', ', nombres) AS nombre_completo
                FROM Usuario_Sistema
                WHERE id_usuario = ?
            ");
            $stmtU->execute([$idUsuario]);
            $nombreDocente = $stmtU->fetchColumn();

            if (!$nombreDocente) {
                return [
                    "status" => "error",
                    "message" => "No se encontró el docente asociado al usuario."
                ];
            }

            $stmt = $this->conn->prepare("
                UPDATE Historial_Reporte
                SET aviso_final_visto = 1,
                    fecha_aviso_final_visto = NOW()
                WHERE id_estado_reporte = 3
                AND id_tipo_reporte = 1
                AND COALESCE(aviso_final_visto, 0) = 0
                AND informacion_adicional LIKE ?
            ");

            $stmt->execute(["%$nombreDocente%"]);

            return [
                "status" => "success",
                "message" => "Boletas finales marcadas como vistas correctamente.",
                "data" => [
                    "actualizados" => $stmt->rowCount()
                ]
            ];

        } catch (Exception $e) {
            return [
                "status" => "error",
                "message" => "Error al marcar boletas finales como vistas: " . $e->getMessage()
            ];
        }
    }

    public function cambiarEstadoReporte($idReporte, $nuevoEstado) {
        try {
            $sql = "UPDATE Historial_Reporte SET id_estado_reporte = ? WHERE id_reporte = ?";
            $stmt = $this->conn->prepare($sql);
            $stmt->execute([$nuevoEstado, $idReporte]);
            
            if ($stmt->rowCount() > 0) {
                return ["status" => "success", "message" => "Estado actualizado correctamente."];
            } else {
                return ["status" => "error", "message" => "No se encontró el reporte o ya tenía ese estado."];
            }
        } catch (Exception $e) {
            return ["status" => "error", "message" => "Error DB: " . $e->getMessage()];
        }
    }

    public function firmarReporte($idReporte, $idUsuario, $idRol) {
        try {
            $firma = $this->generarEstampaFirma($idUsuario);
            

            $campoFirma = "";
            $nuevoEstado = 0;






            $stmtTipo = $this->conn->prepare("SELECT id_tipo_reporte FROM Historial_Reporte WHERE id_reporte = ?");
            $stmtTipo->execute([$idReporte]);
            $tipoReporte = $stmtTipo->fetchColumn();

            if ($idRol == 2) {
                $campoFirma = "firma_directora";
                $nuevoEstado = 2;
            } elseif ($idRol == 1) {
                $campoFirma = "firma_secretaria";
                $nuevoEstado = ($tipoReporte == 1) ? 5 : 3; 
            } elseif ($idRol == 3) {
                $campoFirma = "firma_docente";
                $nuevoEstado = 3;
            } else {
                return ["status" => "error", "message" => "Rol no autorizado para firmar."];
            }

            $sql = "UPDATE Historial_Reporte SET id_estado_reporte = ?, $campoFirma = ? WHERE id_reporte = ?";
            $stmt = $this->conn->prepare($sql);
            $stmt->execute([$nuevoEstado, $firma, $idReporte]);
            
            if ($stmt->rowCount() > 0) {
                return ["status" => "success", "message" => "Firmado correctamente."];
            } else {
                return ["status" => "error", "message" => "No se pudo firmar el reporte."];
            }
        } catch (Exception $e) {
            return ["status" => "error", "message" => "Error DB: " . $e->getMessage()];
        }
    }

    public function firmarLoteBoletas($listaIds, $idUsuario, $idRol) {
        try {
            if (empty($listaIds)) return ["status" => "error", "message" => "Lista vacía"];
            
            $firma = $this->generarEstampaFirma($idUsuario);
            $campoFirma = "";
            $nuevoEstado = 0;

            if ($idRol == 2) {
                $campoFirma = "firma_directora";
                $nuevoEstado = 2;
            } elseif ($idRol == 1) {
                $campoFirma = "firma_secretaria";
                $nuevoEstado = 5; 
            } elseif ($idRol == 3) {
                $campoFirma = "firma_docente";
                $nuevoEstado = 3;
            }

            $inQuery = implode(',', array_fill(0, count($listaIds), '?'));
            $params = array_merge([$nuevoEstado, $firma], $listaIds);

            $sql = "UPDATE Historial_Reporte SET id_estado_reporte = ?, $campoFirma = ? WHERE id_reporte IN ($inQuery)";
            
            $stmt = $this->conn->prepare($sql);
            $stmt->execute($params);
            
            return ["status" => "success", "message" => "Se firmaron " . $stmt->rowCount() . " reportes."];
        } catch (Exception $e) {
            return ["status" => "error", "message" => "Error DB: " . $e->getMessage()];
        }
    }
    
    public function obtenerAlumnosPorSeccion($periodoId) {
        try {
            $query = "SELECT e.id_estudiante, e.nombres, e.apellidos, e.codigo_matricula 
                      FROM Historial_Academico ha
                      JOIN Estudiante e ON ha.id_estudiante = e.id_estudiante
                      WHERE ha.id_periodo = :periodo";
            
            $stmt = $this->conn->prepare($query);
            $stmt->bindParam(":periodo", $periodoId);
            $stmt->execute();
            
            return ["status" => "success", "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)];
        } catch (PDOException $e) {
            return ["status" => "error", "message" => $e->getMessage()];
        }
    }

    public function procesarAsistenciaExcel($filas, $nombreArchivo, $idUsuario, $idDocenteSeleccionado = null, $forceUpload = false) {
        try {
            mb_internal_encoding("UTF-8");

            $anio = null; $mesTexto = null; $seccionRaw = null; $gradoRaw = null; $nivelRaw = null;
            $filaInicio = -1; $colNombres = -1;
            $esArchivoNotas = false;

            foreach ($filas as $idx => $fila) {
                foreach ($fila as $col => $val) {
                    $v = $this->limpiarTextoBusqueda($val);
                    
                    if (strpos($v, 'BIMESTRE') !== false || strpos($v, 'GENERALIDADES') !== false || strpos($v, 'AREAS') !== false) {
                        $esArchivoNotas = true;
                    }

                    if ($anio == null && strpos($v, 'ANO') !== false && mb_strlen($v) < 10) $anio = $this->buscarValorEnCeldasAdyacentes($fila, $col);
                    if ($mesTexto == null && (strpos($v, 'MES') !== false) && mb_strlen($v) < 10) $mesTexto = $this->buscarValorEnCeldasAdyacentes($fila, $col);
                    if ($seccionRaw == null && strpos($v, 'SECCION') !== false && mb_strlen($v) < 20) $seccionRaw = $this->buscarValorEnCeldasAdyacentes($fila, $col);
                    if ($gradoRaw == null && strpos($v, 'GRADO') !== false) $gradoRaw = $this->buscarValorEnCeldasAdyacentes($fila, $col);
                    if ($nivelRaw == null && strpos($v, 'NIVEL') !== false) $nivelRaw = $this->buscarValorEnCeldasAdyacentes($fila, $col);
                    
                    if ($filaInicio == -1) {
                        if (strpos($v, 'NOMBRES') !== false || strpos($v, 'APELLIDOS') !== false || strpos($v, 'ALUMNO') !== false) {
                            $filaInicio = $idx + 1; 
                            $colNombres = $col;
                        }
                    }
                }
                if ($anio && $mesTexto && $filaInicio != -1 && $nivelRaw) break;
                if ($idx > 300) break; 
            }

            if (!$anio || !$mesTexto || $filaInicio == -1) {
                if ($esArchivoNotas) return ["status" => "error", "message" => "⚠️ Error: Subió un archivo de NOTAS en la opción de ASISTENCIA."];
                return ["status" => "error", "message" => "Faltan datos de Asistencia."];
            }


            $seccion = mb_substr($this->sanitizarTexto($seccionRaw ?? 'U'), 0, 50, 'UTF-8');
            $grado = mb_substr($this->sanitizarTexto($gradoRaw ?? 'U'), 0, 50, 'UTF-8');
            $nivel = $nivelRaw ? mb_substr($this->sanitizarTexto($nivelRaw), 0, 50, 'UTF-8') : 'IMPORTADO';
            $mesGuardar = mb_substr($this->sanitizarTexto($mesTexto), 0, 20, 'UTF-8'); 

            $idPeriodo = $this->gestionarPeriodo($anio, $grado, $seccion, $nivel, $idDocenteSeleccionado);
            if (is_array($idPeriodo)) return $idPeriodo; 

            if (!$forceUpload) {
                $sqlCheck = "SELECT COUNT(*) as total FROM Asistencia a JOIN Historial_Academico h ON a.id_historial = h.id_historial WHERE h.id_periodo = ? AND a.mes = ?";
                $stmtCheck = $this->conn->prepare($sqlCheck);
                $stmtCheck->execute([$idPeriodo, $mesGuardar]);
                $resCheck = $stmtCheck->fetch(PDO::FETCH_ASSOC);

                if ($resCheck['total'] > 0) {
                    return [
                        "status" => "duplicate_warning", 
                        "message" => "Ya existe asistencia para el mes de $mesGuardar. Se encontraron {$resCheck['total']} registros. ¿Desea sobrescribir?",
                        "data" => ["mes" => $mesGuardar, "total" => $resCheck['total']]
                    ];
                }
            } else {
                $sqlDel = "DELETE a FROM Asistencia a JOIN Historial_Academico h ON a.id_historial = h.id_historial WHERE h.id_periodo = ? AND a.mes = ?";
                $stmtDel = $this->conn->prepare($sqlDel);
                $stmtDel->execute([$idPeriodo, $mesGuardar]);
            }

            $this->conn->beginTransaction();

            $stmtArch = $this->conn->prepare("INSERT INTO Archivo_SIAGIE (tipo_archivo, nombre_archivo, ruta_archivo, fecha_importacion, id_usuario) VALUES (1, ?, 'Carga_Excel', CURDATE(), ?)");
            $stmtArch->execute([$nombreArchivo, $idUsuario]);
            $idArchivo = $this->conn->lastInsertId();

            $mesNumero = $this->getMesNumero($mesGuardar);
            $mapaEstados = ['.' => 1, 'F' => 2, 'T' => 3, 'J' => 4, 'U' => 5]; 
            $count = 0;

            for ($i = $filaInicio; $i < count($filas); $i++) {
                $fila = $filas[$i];
                if (!isset($fila[$colNombres])) continue;
                
                $nombreRaw = $this->sanitizarTexto($fila[$colNombres]);
                if (empty($nombreRaw) || strpos($nombreRaw, ',') === false) continue;

                $partes = explode(',', $nombreRaw);
                $apellidos = trim($partes[0]);
                $nombres = trim($partes[1]);

                $idEstudiante = $this->obtenerIdEstudiante($nombres, $apellidos, null, true); 
                $idHistorial = $this->obtenerIdHistorial($idEstudiante, $idPeriodo);

                $colDia = $colNombres + 1;
                for ($dia = 1; $dia <= 31; $dia++) {
                    if (isset($fila[$colDia])) {
                        $marca = trim($fila[$colDia]);
                        $idEstado = isset($mapaEstados[$marca]) ? $mapaEstados[$marca] : null;
                        if ($idEstado && checkdate($mesNumero, $dia, $anio)) {
                            $fecha = "$anio-$mesNumero-$dia";
                            $stmtAsis = $this->conn->prepare("INSERT INTO Asistencia (id_historial, id_archivo, mes, fecha, id_estado) VALUES (?, ?, ?, ?, ?)");
                            $stmtAsis->execute([$idHistorial, $idArchivo, $mesGuardar, $fecha, $idEstado]);
                            $count++;
                        }
                    }
                    $colDia++;
                }
            }

            $this->conn->commit();
            return ["status" => "success", "message" => "Asistencia: $count registros procesados."];

        } catch (Exception $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            throw $e;
        }
    }




    public function procesarNotasExcel($hojas, $nombreArchivo, $idUsuario, $idDocenteSeleccionado = null, $forceUpload = false) {
        try {
            mb_internal_encoding("UTF-8");
            $this->conn->beginTransaction();

            $datosGen = $this->extraerGeneralidades($hojas);
            if (!$datosGen['anio'] || !$datosGen['grado']) return ["status" => "error", "message" => "Faltan datos generales."];

            $anio = $datosGen['anio'];
            

            $grado = mb_substr($this->sanitizarTexto($datosGen['grado']), 0, 50, 'UTF-8');
            $seccion = mb_substr($this->sanitizarTexto($datosGen['seccion']), 0, 50, 'UTF-8');
            $nivel = $datosGen['nivel'] ? mb_substr($this->sanitizarTexto($datosGen['nivel']), 0, 50, 'UTF-8') : 'IMPORTADO';

            $bimestreNum = $this->getBimestreNumero($datosGen['bimestre']);
            $mapaCursos = $datosGen['mapaCursos']; 

            $idPeriodo = $this->gestionarPeriodo($anio, $grado, $seccion, $nivel, $idDocenteSeleccionado);
            if (is_array($idPeriodo)) return $idPeriodo; 

            if (!$forceUpload) {
                $sqlCheck = "SELECT COUNT(*) as total FROM Calificacion c JOIN Historial_Academico h ON c.id_historial = h.id_historial WHERE h.id_periodo = ? AND c.bimestre = ?";
                $stmtCheck = $this->conn->prepare($sqlCheck);
                $stmtCheck->execute([$idPeriodo, $bimestreNum]);
                $resCheck = $stmtCheck->fetch(PDO::FETCH_ASSOC);

                if ($resCheck['total'] > 0) {
                    $this->conn->rollBack(); 
                    return ["status" => "duplicate_warning", "message" => "Ya existen notas para el Bimestre $bimestreNum. ($resCheck[total] regs). ¿Sobrescribir?", "data" => ["bimestre" => $bimestreNum, "total" => $resCheck['total']]];
                }
            } else {
                $sqlDel = "DELETE c FROM Calificacion c JOIN Historial_Academico h ON c.id_historial = h.id_historial WHERE h.id_periodo = ? AND c.bimestre = ?";
                $stmtDel = $this->conn->prepare($sqlDel);
                $stmtDel->execute([$idPeriodo, $bimestreNum]);
            }

            $stmtArch = $this->conn->prepare("INSERT INTO Archivo_SIAGIE (tipo_archivo, nombre_archivo, ruta_archivo, fecha_importacion, id_usuario) VALUES (2, ?, 'Carga_Notas', CURDATE(), ?)");
            $stmtArch->execute([$nombreArchivo, $idUsuario]);
            $idArchivo = $this->conn->lastInsertId();

            $totalNotas = 0;
            $cursosProcesados = 0;

            foreach ($hojas as $nombreHoja => $filas) {
                if (stripos($nombreHoja, 'Generalidades') !== false || stripos($nombreHoja, 'Parametros') !== false) continue;

                $codigoCurso = trim(explode('-', $nombreHoja)[0]); 
                $nombreCursoReal = isset($mapaCursos[$codigoCurso]) ? $mapaCursos[$codigoCurso] : $nombreHoja;

                $idCurso = $this->obtenerIdCurso($this->sanitizarTexto($nombreCursoReal), $grado, $nivel);
                $resCurso = $this->procesarHojaCurso($filas, $idCurso, $idPeriodo, $idArchivo, $bimestreNum);
                $totalNotas += $resCurso;
                $cursosProcesados++;
            }

            $this->conn->commit();
            return ["status" => "success", "message" => "Notas: $totalNotas calificaciones procesadas."];

        } catch (Exception $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            throw $e;
        }
    }



    
    private function limpiarTexto($cadena) {
        if ($cadena === null) return "";
        $cadena = mb_strtoupper(trim($cadena), 'UTF-8');
        $originales = ['Á', 'É', 'Í', 'Ó', 'Ú', 'Ñ'];
        $reemplazos = ['A', 'E', 'I', 'O', 'U', 'N'];
        return str_replace($originales, $reemplazos, $cadena);
    }

    private function buscarValorEnCeldasAdyacentes($fila, $colOrigen) {
        for ($offset = 1; $offset <= 5; $offset++) {
            if (isset($fila[$colOrigen + $offset])) {
                $valor = trim($fila[$colOrigen + $offset]);
                if (!empty($valor)) return $valor;
            }
        }
        return null;
    }
    

    private function gestionarPeriodo($anio, $grado, $seccion, $nivel, $idDocenteSeleccionado) {
        $sqlPer = "SELECT id_periodo FROM Periodo WHERE año_lectivo = ? AND seccion = ? AND grado = ? LIMIT 1";
        $stmtPer = $this->conn->prepare($sqlPer);
        $stmtPer->execute([$anio, $seccion, $grado]);
        $periodo = $stmtPer->fetch(PDO::FETCH_ASSOC);

        if ($periodo) return $periodo['id_periodo'];
        
        if ($idDocenteSeleccionado == null) {
            $docentes = $this->listarDocentesParaSelect();
            return [
                "status" => "require_teacher_selection",
                "message" => "Nuevo Salón detectado ($grado - $seccion - $nivel).",
                "data" => ["grado" => $grado, "seccion" => $seccion, "anio" => $anio, "docentes" => $docentes]
            ];
        } else {

            $stmtInsPer = $this->conn->prepare("INSERT INTO Periodo (id_docente, año_lectivo, nivel, grado, seccion) VALUES (?, ?, ?, ?, ?)");
            $stmtInsPer->execute([$idDocenteSeleccionado, $anio, $nivel, $grado, $seccion]);
            return $this->conn->lastInsertId();
        }
    }

    private function listarDocentesParaSelect() {
        try {


            $sql = "SELECT d.id_docente, CONCAT(d.nombres, ' ', d.apellidos) as nombre_completo 
                    FROM Docente d
                    JOIN Usuario_Sistema u ON d.DNI = u.DNI
                    WHERE u.estado = 1
                    ORDER BY d.apellidos ASC";
            
            $stmt = $this->conn->query($sql);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            return [];
        }
    }

    private function obtenerIdEstudiante($nombres, $apellidos, $codigoMatricula = null, $crearSiNoExiste = false) {
        $stmt = $this->conn->prepare("SELECT id_estudiante, codigo_matricula FROM Estudiante WHERE TRIM(UPPER(nombres)) = TRIM(UPPER(?)) AND TRIM(UPPER(apellidos)) = TRIM(UPPER(?)) LIMIT 1");
        $stmt->execute([$nombres, $apellidos]);
        $res = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($res) {
            if (empty($res['codigo_matricula']) && !empty($codigoMatricula)) {
                $stmtUpd = $this->conn->prepare("UPDATE Estudiante SET codigo_matricula = ? WHERE id_estudiante = ?");
                $stmtUpd->execute([$codigoMatricula, $res['id_estudiante']]);
            }
            return $res['id_estudiante'];
        }
        
        if ($crearSiNoExiste) {
            $stmtIns = $this->conn->prepare("INSERT INTO Estudiante (nombres, apellidos, codigo_matricula, id_estado_estudiante) VALUES (?, ?, ?, 1)");
            $stmtIns->execute([$nombres, $apellidos, $codigoMatricula]); 
            return $this->conn->lastInsertId();
        }
        return null;
    }

    private function obtenerIdHistorial($idEstudiante, $idPeriodo) {
        $stmt = $this->conn->prepare("SELECT id_historial FROM Historial_Academico WHERE id_estudiante = ? AND id_periodo = ? LIMIT 1");
        $stmt->execute([$idEstudiante, $idPeriodo]);
        $res = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($res) return $res['id_historial'];
        
        $stmtIns = $this->conn->prepare("INSERT INTO Historial_Academico (id_estudiante, id_periodo) VALUES (?, ?)");
        $stmtIns->execute([$idEstudiante, $idPeriodo]);
        return $this->conn->lastInsertId();
    }

    private function getMesNumero($mesTxt) {
        $mesTxt = $this->limpiarTexto($mesTxt);
        $meses = ['ENERO'=>'01','FEBRERO'=>'02','MARZO'=>'03','ABRIL'=>'04','MAYO'=>'05','JUNIO'=>'06','JULIO'=>'07','AGOSTO'=>'08','SETIEMBRE'=>'09','SEPTIEMBRE'=>'09','OCTUBRE'=>'10','NOVIEMBRE'=>'11','DICIEMBRE'=>'12'];
        return isset($meses[$mesTxt]) ? $meses[$mesTxt] : date('m');
    }

    private function getBimestreNumero($txt) {
        $txt = $this->limpiarTexto($txt);
        if (strpos($txt, 'PRIMER') !== false || strpos($txt, '1') !== false) return 1;
        if (strpos($txt, 'SEGUNDO') !== false || strpos($txt, '2') !== false) return 2;
        if (strpos($txt, 'TERCER') !== false || strpos($txt, '3') !== false) return 3;
        if (strpos($txt, 'CUARTO') !== false || strpos($txt, '4') !== false) return 4;
        return 1;
    }


    private function extraerGeneralidades($hojas) {
        $datos = ['anio'=>null, 'grado'=>null, 'seccion'=>null, 'bimestre'=>null, 'nivel'=>null, 'mapaCursos'=>[]];
        
        $filasGen = null;
        foreach ($hojas as $k => $v) {
            if (stripos($k, 'Generalidades') !== false) { $filasGen = $v; break; }
        }
        if (!$filasGen) return $datos;

        foreach ($filasGen as $fila) {
            foreach ($fila as $idx => $celda) {
                $val = $this->limpiarTexto($celda);
                if (strpos($val, 'ANO ACADEMICO') !== false) $datos['anio'] = $this->buscarValorEnCeldasAdyacentes($fila, $idx);
                if (strpos($val, 'GRADO') !== false && !$datos['grado']) $datos['grado'] = $this->buscarValorEnCeldasAdyacentes($fila, $idx);
                if (strpos($val, 'SECCION') !== false && !$datos['seccion']) $datos['seccion'] = $this->buscarValorEnCeldasAdyacentes($fila, $idx);
                if (strpos($val, 'PERIODO DE EV') !== false && !$datos['bimestre']) $datos['bimestre'] = $this->buscarValorEnCeldasAdyacentes($fila, $idx);
                

                if (strpos($val, 'NIVEL') !== false && !$datos['nivel']) $datos['nivel'] = $this->buscarValorEnCeldasAdyacentes($fila, $idx);

                if (preg_match('/^(\d+):/', $val, $matches)) {
                    $codigo = $matches[1]; 
                    $nombreCompleto = $this->buscarValorEnCeldasAdyacentes($fila, $idx);
                    if ($nombreCompleto) $datos['mapaCursos'][$codigo] = $nombreCompleto;
                }
            }
        }
        return $datos;
    }

    private function procesarHojaCurso($filas, $idCurso, $idPeriodo, $idArchivo, $bimestre) {
        $count = 0;
        $mapaCompetencias = []; 
        for ($i = count($filas) - 1; $i >= 0; $i--) {
            $fila = $filas[$i];
            if (!isset($fila[1])) continue;
            
            if (preg_match('/^0?(\d+)\s*=\s*(.+)/', trim($fila[1]), $matches)) {
                $codExcel = str_pad($matches[1], 2, "0", STR_PAD_LEFT);
                $nombreComp = trim($matches[2]);
                $idComp = $this->obtenerIdCompetencia($idCurso, $nombreComp);
                $mapaCompetencias[$codExcel] = $idComp;
            }
            if (strpos($this->limpiarTexto(implode(" ", $fila)), 'LEYENDA') !== false) break; 
        }

        $filaInicio = -1;
        $colNombres = -1;
        $colMatricula = -1;
        $mapaColumnas = []; 
        
        foreach ($filas as $idx => $fila) {
            foreach ($fila as $c => $val) {
                $v = $this->limpiarTexto($val);
                if (strpos($v, 'NOMBRES') !== false) {
                    $filaInicio = $idx + 1;
                    $colNombres = $c;
                    if (isset($fila[$c-1]) && strpos($this->limpiarTexto($fila[$c-1]), 'COD') !== false) $colMatricula = $c-1;
                    
                    for ($j = $c + 1; $j < count($fila); $j++) {
                        $headVal = trim($fila[$j]); 
                        if (is_numeric($headVal)) {
                            $cod = str_pad($headVal, 2, "0", STR_PAD_LEFT);
                            if (!isset($mapaColumnas[$cod])) $mapaColumnas[$j] = $cod; 
                        }
                    }
                    break 2;
                }
            }
        }

        if ($filaInicio == -1) return 0;

        for ($i = $filaInicio; $i < count($filas); $i++) {
            $fila = $filas[$i];
            if (!isset($fila[$colNombres])) continue;
            
            $nombreRaw = $this->limpiarTexto($fila[$colNombres]);
            if (strpos($nombreRaw, ',') === false) continue;
            
            $partes = explode(',', $nombreRaw);
            $apellidos = trim($partes[0]);
            $nombres = trim($partes[1]);
            $matricula = ($colMatricula != -1 && isset($fila[$colMatricula])) ? trim($fila[$colMatricula]) : null;
            
            $idEstudiante = $this->obtenerIdEstudiante($nombres, $apellidos, $matricula, true);
            $idHistorial = $this->obtenerIdHistorial($idEstudiante, $idPeriodo);

            foreach ($mapaColumnas as $colNota => $codExcel) {
                if (!isset($mapaCompetencias[$codExcel])) continue;
                
                $idCompetencia = $mapaCompetencias[$codExcel];
                $nota = isset($fila[$colNota]) ? trim($fila[$colNota]) : '';
                $comentario = isset($fila[$colNota + 1]) ? trim($fila[$colNota + 1]) : '';

                if ($nota !== '') {
                    $sqlCal = "INSERT INTO Calificacion (id_historial, id_archivo, id_competencia, bimestre, nota_competencia, comentario) 
                               VALUES (?, ?, ?, ?, ?, ?)";
                    $stmtCal = $this->conn->prepare($sqlCal);
                    $stmtCal->execute([$idHistorial, $idArchivo, $idCompetencia, $bimestre, $nota, $comentario]);
                    $count++;
                }
            }
        }
        return $count;
    }


    private function obtenerIdCurso($nombre, $grado, $nivel) {
        $stmt = $this->conn->prepare("SELECT id_curso FROM Curso WHERE nombre_curso = ? LIMIT 1");
        $stmt->execute([$nombre]);
        $res = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($res) return $res['id_curso'];
        
        $stmtIns = $this->conn->prepare("INSERT INTO Curso (nombre_curso, grado, nivel) VALUES (?, ?, ?)");
        $stmtIns->execute([$nombre, $grado, $nivel]);
        return $this->conn->lastInsertId();
    }

    private function obtenerIdCompetencia($idCurso, $nombre) {
        $nombre = mb_substr($nombre, 0, 80, 'UTF-8');
        $stmt = $this->conn->prepare("SELECT id_competencia FROM Competencia WHERE id_curso = ? AND nombre_competencia = ? LIMIT 1");
        $stmt->execute([$idCurso, $nombre]);
        $res = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($res) return $res['id_competencia'];
        
        $stmtIns = $this->conn->prepare("INSERT INTO Competencia (id_curso, nombre_competencia) VALUES (?, ?)");
        $stmtIns->execute([$idCurso, $nombre]);
        return $this->conn->lastInsertId();
    }


    public function listarAniosReporte() {
        $sql = "SELECT DISTINCT año_lectivo FROM Periodo ORDER BY año_lectivo DESC";
        return $this->conn->query($sql)->fetchAll(PDO::FETCH_COLUMN);
    }


    public function listarNivelesReporte($anio) {
        $sql = "SELECT DISTINCT nivel FROM Periodo WHERE año_lectivo = ? ORDER BY nivel";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$anio]);
        return $stmt->fetchAll(PDO::FETCH_COLUMN);
    }


    public function listarSalonesReporte($anio, $nivel) {

        $sql = "SELECT id_periodo, CONCAT(grado, ' - ', seccion) as nombre 
                FROM Periodo WHERE año_lectivo = ? AND nivel = ? ORDER BY grado, seccion";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$anio, $nivel]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }


    public function listarBimestresReporte($idPeriodo) {

        $sql = "SELECT DISTINCT c.bimestre 
                FROM Calificacion c
                JOIN Historial_Academico h ON c.id_historial = h.id_historial
                WHERE h.id_periodo = ?
                ORDER BY c.bimestre";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$idPeriodo]);
        return $stmt->fetchAll(PDO::FETCH_COLUMN);
    }




    public function generarBoletaNotas($idUsuario, $idPeriodo, $bimestre, $fechaInicio, $fechaFin, $force = false) {
        try {
            $this->conn->beginTransaction();
            


            $sqlInfo = "SELECT p.año_lectivo, p.nivel, p.grado, p.seccion, 
                               CONCAT(d.apellidos, ', ', d.nombres) as docente
                        FROM Periodo p
                        LEFT JOIN Docente d ON p.id_docente = d.id_docente
                        WHERE p.id_periodo = ?";
            
            $stmtP = $this->conn->prepare($sqlInfo);
            $stmtP->execute([$idPeriodo]);
            $pData = $stmtP->fetch(PDO::FETCH_ASSOC);
            
            if (!$pData) {
                return ["status" => "error", "message" => "Periodo no encontrado"];
            }



            $docente = $pData['docente'] ?? 'Por Asignar';
            $infoAd = "{$pData['año_lectivo']}|{$pData['nivel']}|{$pData['grado']}|{$pData['seccion']}|B$bimestre|$docente";


            if (!$force) {
                $stmtCheck = $this->conn->prepare("SELECT COUNT(*) FROM Historial_Reporte WHERE id_tipo_reporte = 1 AND informacion_adicional = ?");
                $stmtCheck->execute([$infoAd]);
                if ($stmtCheck->fetchColumn() > 0) return ["status" => "duplicate_warning", "message" => "Ya existen boletas para este salón y bimestre. ¿Reemplazar?"];
            } else {
                $stmtDel = $this->conn->prepare("DELETE FROM Historial_Reporte WHERE id_tipo_reporte = 1 AND informacion_adicional = ?");
                $stmtDel->execute([$infoAd]);
            }


            $stmtAl = $this->conn->prepare("SELECT e.id_estudiante, e.nombres, e.apellidos, e.codigo_matricula, h.id_historial FROM Estudiante e JOIN Historial_Academico h ON e.id_estudiante = h.id_estudiante WHERE h.id_periodo = ? AND e.codigo_matricula IS NOT NULL AND e.codigo_matricula != ''");
            $stmtAl->execute([$idPeriodo]);
            $alumnos = $stmtAl->fetchAll(PDO::FETCH_ASSOC);
            if (empty($alumnos)) return ["status" => "error", "message" => "No hay alumnos con matrícula."];




            $gen = 0;
            foreach ($alumnos as $al) {
                $idH = $al['id_historial'];
                

                $query = "
                    SELECT 
                        cur.nombre_curso, 
                        com.nombre_competencia, 
                        UPPER(TRIM(cal.nota_competencia)) as nota_competencia, 
                        cal.comentario, 
                        (SELECT COUNT(*) FROM Asistencia a WHERE a.id_historial = $idH AND a.id_estado = 1 AND a.fecha BETWEEN '$fechaInicio' AND '$fechaFin') as asis, 
                        (SELECT COUNT(*) FROM Asistencia a WHERE a.id_historial = $idH AND a.id_estado = 2 AND a.fecha BETWEEN '$fechaInicio' AND '$fechaFin') as fal, 
                        (SELECT COUNT(*) FROM Asistencia a WHERE a.id_historial = $idH AND a.id_estado = 3 AND a.fecha BETWEEN '$fechaInicio' AND '$fechaFin') as tar 
                    FROM Calificacion cal 
                    JOIN Competencia com ON cal.id_competencia = com.id_competencia 
                    JOIN Curso cur ON com.id_curso = cur.id_curso 
                    WHERE cal.id_historial = $idH AND cal.bimestre = $bimestre 
                    ORDER BY cur.nombre_curso, com.nombre_competencia
                ";


                $param = "Alumno: {$al['apellidos']}, {$al['nombres']} | Matrícula: {$al['codigo_matricula']}";
                
                $stmtIns = $this->conn->prepare("INSERT INTO Historial_Reporte (id_usuario, id_tipo_reporte, id_estado_reporte, fecha_generacion, parametros, ruta_archivo, informacion_adicional) VALUES (?, 1, 1, NOW(), ?, ?, ?)");
                $stmtIns->execute([$idUsuario, $param, $query, $infoAd]);
                $gen++;
            }

            $this->conn->commit();
            return ["status" => "success", "message" => "Se generaron $gen boletas.", "data" => ["generados" => $gen]];

        } catch (Exception $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            return ["status" => "error", "message" => $e->getMessage()];
        }
    }

    public function listarBimestresPorNivel($anio, $nivel) {
        $sql = "SELECT DISTINCT c.bimestre 
                FROM Calificacion c
                JOIN Historial_Academico h ON c.id_historial = h.id_historial
                JOIN Periodo p ON h.id_periodo = p.id_periodo
                WHERE p.año_lectivo = ? AND p.nivel = ?
                ORDER BY c.bimestre";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$anio, $nivel]);
        return $stmt->fetchAll(PDO::FETCH_COLUMN);
    }


    public function generarReporteRendimiento($idUsuario, $anio, $nivel, $bimestre, $fechaInicio, $fechaFin, $forceOverwrite = false, $ignoreMissing = false) {
        try {
            $this->conn->beginTransaction();


            $sqlSalones = "SELECT id_periodo, CONCAT(grado, ' ', seccion) as nombre FROM Periodo WHERE año_lectivo = ? AND nivel = ?";
            $stmtS = $this->conn->prepare($sqlSalones);
            $stmtS->execute([$anio, $nivel]);
            $todosSalones = $stmtS->fetchAll(PDO::FETCH_ASSOC);

            if (empty($todosSalones)) return ["status" => "error", "message" => "No existen salones para $nivel en $anio."];

            $salonesIncluidos = []; $salonesFaltantes = [];

            if (!$ignoreMissing) {
                foreach ($todosSalones as $salon) {
                    $idPer = $salon['id_periodo'];
                    $stmtN = $this->conn->prepare("SELECT COUNT(*) FROM Calificacion c JOIN Historial_Academico h ON c.id_historial = h.id_historial WHERE h.id_periodo = ? AND c.bimestre = ?");
                    $stmtN->execute([$idPer, $bimestre]);
                    if ($stmtN->fetchColumn() == 0) { $salonesFaltantes[] = $salon['nombre'] . " (Notas)"; continue; }

                    $stmtA = $this->conn->prepare("SELECT COUNT(*) FROM Asistencia a JOIN Historial_Academico h ON a.id_historial = h.id_historial WHERE h.id_periodo = ? AND a.fecha BETWEEN ? AND ?");
                    $stmtA->execute([$idPer, $fechaInicio, $fechaFin]);
                    if ($stmtA->fetchColumn() == 0) { $salonesFaltantes[] = $salon['nombre'] . " (Asistencia)"; continue; }

                    $salonesIncluidos[] = $salon['nombre'];
                }
                if (!empty($salonesFaltantes)) return ["status" => "integrity_warning", "message" => "Faltan datos en:", "data" => ["faltantes" => $salonesFaltantes, "advertencia" => "Se excluirán estos salones."]];
            } else {
                foreach ($todosSalones as $salon) {
                    $stmtCheck = $this->conn->prepare("SELECT COUNT(*) FROM Calificacion c JOIN Historial_Academico h ON c.id_historial = h.id_historial WHERE h.id_periodo = ? AND c.bimestre = ?");
                    $stmtCheck->execute([$salon['id_periodo'], $bimestre]);
                    if ($stmtCheck->fetchColumn() > 0) $salonesIncluidos[] = $salon['nombre'];
                }
            }

            if (empty($salonesIncluidos)) return ["status" => "error", "message" => "Ningún salón tiene notas."];


            $listaSalonesStr = implode(", ", $salonesIncluidos);
            if (strlen($listaSalonesStr) > 100) $listaSalonesStr = substr($listaSalonesStr, 0, 97) . "...";
            $identificador = "REPORTE RENDIMIENTO | AÑO: $anio | NIVEL: $nivel | BIM: $bimestre";
            
            if (!$forceOverwrite) {
                $stmtCheck = $this->conn->prepare("SELECT COUNT(*) FROM Historial_Reporte WHERE id_tipo_reporte = 2 AND parametros LIKE ?");
                $stmtCheck->execute([$identificador . '%']);
                if ($stmtCheck->fetchColumn() > 0) return ["status" => "duplicate_warning", "message" => "Ya existe. ¿Sobrescribir?"];
            } else {
                $stmtDel = $this->conn->prepare("DELETE FROM Historial_Reporte WHERE id_tipo_reporte = 2 AND parametros LIKE ?");
                $stmtDel->execute([$identificador . '%']);
            }


            $strSalonesFull = implode(", ", $salonesIncluidos);
            

            $queryRendimiento = "
                SELECT 
                    '$strSalonesFull' as salones_reportados,
                    p.grado, p.seccion,
                    e.codigo_matricula, CONCAT(e.apellidos, ', ', e.nombres) as alumno,
                    cur.nombre_curso,
                    cal.nota_competencia,
                    (SELECT COUNT(*) FROM Asistencia a WHERE a.id_historial = h.id_historial AND a.fecha BETWEEN '$fechaInicio' AND '$fechaFin' AND a.id_estado = 1) as asis_puntual,
                    (SELECT COUNT(*) FROM Asistencia a WHERE a.id_historial = h.id_historial AND a.fecha BETWEEN '$fechaInicio' AND '$fechaFin' AND a.id_estado = 2) as faltas,
                    (SELECT COUNT(*) FROM Asistencia a WHERE a.id_historial = h.id_historial AND a.fecha BETWEEN '$fechaInicio' AND '$fechaFin' AND a.id_estado = 3) as tardanzas
                FROM Estudiante e
                JOIN Historial_Academico h ON e.id_estudiante = h.id_estudiante
                JOIN Periodo p ON h.id_periodo = p.id_periodo
                JOIN Calificacion cal ON h.id_historial = cal.id_historial
                JOIN Competencia com ON cal.id_competencia = com.id_competencia
                JOIN Curso cur ON com.id_curso = cur.id_curso
                WHERE p.año_lectivo = $anio AND p.nivel = '$nivel' AND cal.bimestre = $bimestre
                ORDER BY p.grado, p.seccion, e.apellidos, cur.nombre_curso
            ";

            $stmtIns = $this->conn->prepare("INSERT INTO Historial_Reporte (id_usuario, id_tipo_reporte, id_estado_reporte, fecha_generacion, parametros, ruta_archivo, informacion_adicional) VALUES (?, 2, 1, NOW(), ?, ?, NULL)");
            $stmtIns->execute([$idUsuario, "$identificador | SALONES: $listaSalonesStr", $queryRendimiento]);

            $this->conn->commit();
            return ["status" => "success", "message" => "Reporte generado."];

        } catch (Exception $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            return ["status" => "error", "message" => "Error: " . $e->getMessage()];
        }
    }

    public function buscarEstudiantesCertificado($anio, $busqueda) {
        $busqueda = "%" . strtoupper(trim($busqueda)) . "%";
        $sql = "SELECT e.id_estudiante, CONCAT(e.apellidos, ', ', e.nombres) as nombre_completo,
                       p.grado, p.seccion, p.nivel, p.id_periodo
                FROM Estudiante e
                JOIN Historial_Academico h ON e.id_estudiante = h.id_estudiante
                JOIN Periodo p ON h.id_periodo = p.id_periodo
                WHERE p.año_lectivo = ? 
                AND (e.nombres LIKE ? OR e.apellidos LIKE ? OR e.codigo_matricula LIKE ?)
                LIMIT 10";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$anio, $busqueda, $busqueda, $busqueda]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }


    public function validarRequisitosCertificado($idEstudiante, $idPeriodo) {

        $sql = "SELECT COUNT(DISTINCT bimestre) 
                FROM Calificacion c
                JOIN Historial_Academico h ON c.id_historial = h.id_historial
                WHERE h.id_estudiante = ? AND h.id_periodo = ?";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$idEstudiante, $idPeriodo]);
        $bimestres = $stmt->fetchColumn();


        $sqlPer = "SELECT grado, nivel, año_lectivo FROM Periodo WHERE id_periodo = ?";
        $stmtPer = $this->conn->prepare($sqlPer);
        $stmtPer->execute([$idPeriodo]);
        $pData = $stmtPer->fetch(PDO::FETCH_ASSOC);


        $sqlHermanos = "SELECT CONCAT(grado, ' - ', seccion) as nombre, id_periodo 
                        FROM Periodo 
                        WHERE año_lectivo = ? AND nivel = ? AND grado = ? AND id_periodo != ?";
        $stmtH = $this->conn->prepare($sqlHermanos);
        $stmtH->execute([$pData['año_lectivo'], $pData['nivel'], $pData['grado'], $idPeriodo]);
        $salonesHermanos = $stmtH->fetchAll(PDO::FETCH_ASSOC);

        $advertencias = [];

        foreach ($salonesHermanos as $hermano) {
            $sqlCheck = "SELECT COUNT(*) FROM Calificacion c JOIN Historial_Academico h ON c.id_historial = h.id_historial WHERE h.id_periodo = ?";
            $stmtC = $this->conn->prepare($sqlCheck);
            $stmtC->execute([$hermano['id_periodo']]);
            if ($stmtC->fetchColumn() == 0) {
                $advertencias[] = "El salón " . $hermano['nombre'] . " no tiene notas registradas.";
            }
        }

        return [
            "apto" => ($bimestres >= 3),
            "bimestres_encontrados" => $bimestres,
            "mensaje" => ($bimestres < 3) ? "El estudiante solo tiene notas en $bimestres bimestre(s). Se requiere mínimo 3." : "Apto para certificado.",
            "advertencias_grado" => $advertencias,
            "grado_info" => "{$pData['grado']} - {$pData['nivel']}"
        ];
    }


    public function generarCertificadoEstudios($idUsuario, $idEstudiante, $idPeriodo, $anio, $force = false) {
        try {
            $this->conn->beginTransaction();
            

            $stmtData = $this->conn->prepare("SELECT UPPER(TRIM(p.grado)) as grado, UPPER(TRIM(p.nivel)) as nivel, UPPER(TRIM(p.seccion)) as seccion, e.codigo_matricula, UPPER(TRIM(CONCAT(e.apellidos, ', ', e.nombres))) as alumno FROM Periodo p JOIN Historial_Academico h ON p.id_periodo = h.id_periodo JOIN Estudiante e ON h.id_estudiante = e.id_estudiante WHERE h.id_estudiante = ? AND h.id_periodo = ?");
            $stmtData->execute([$idEstudiante, $idPeriodo]);
            $alumnoData = $stmtData->fetch(PDO::FETCH_ASSOC);
            if (!$alumnoData) return ["status" => "error", "message" => "Alumno no encontrado."];
            $grado = $alumnoData['grado']; $nivel = $alumnoData['nivel'];


            $sqlRanking = "
                SELECT r.puesto, r.total
                FROM (
                    SELECT 
                        p.id_estudiante, 
                        p.prom, 
                        @r := @r + 1 AS puesto, 
                        t.total
                    FROM (
                        SELECT 
                            h.id_estudiante,
                            IFNULL(AVG(
                                CASE 
                                    WHEN cal.nota_competencia LIKE '%AD%' THEN 4 
                                    WHEN cal.nota_competencia LIKE '%A%' AND cal.nota_competencia NOT LIKE '%AD%' THEN 3 
                                    WHEN cal.nota_competencia LIKE '%B%' THEN 2 
                                    WHEN cal.nota_competencia LIKE '%C%' THEN 1 
                                    ELSE 0 
                                END
                            ), 0) as prom
                        FROM Calificacion cal
                        JOIN Historial_Academico h ON cal.id_historial = h.id_historial
                        JOIN Periodo p ON h.id_periodo = p.id_periodo
                        WHERE p.año_lectivo = ? 
                          AND UPPER(TRIM(p.nivel)) = ? 
                          AND UPPER(TRIM(p.grado)) = ?
                        GROUP BY h.id_estudiante
                        ORDER BY prom DESC
                    ) p
                    CROSS JOIN (SELECT @r := 0) vars
                    CROSS JOIN (
                        SELECT COUNT(DISTINCT h2.id_estudiante) as total
                        FROM Historial_Academico h2
                        JOIN Periodo p2 ON h2.id_periodo = p2.id_periodo
                        WHERE p2.año_lectivo = ? 
                          AND UPPER(TRIM(p2.nivel)) = ? 
                          AND UPPER(TRIM(p2.grado)) = ?
                    ) t
                ) r
                WHERE r.id_estudiante = ?
            ";
            
            $stmtRank = $this->conn->prepare($sqlRanking);

            $stmtRank->execute([$anio, $nivel, $grado, $anio, $nivel, $grado, $idEstudiante]);
            $rankData = $stmtRank->fetch(PDO::FETCH_ASSOC);

            if (!$rankData) return ["status" => "error", "message" => "No se pudo calcular ranking (Verifique notas)."];
            
            $puesto = $rankData['puesto']; 
            $total = $rankData['total'];
            
            $merito = "Regular";
            if ($puesto <= ceil($total / 10)) $merito = "Décimo Superior";
            else if ($puesto <= ceil($total / 5)) $merito = "Quinto Superior";
            else if ($puesto <= ceil($total / 3)) $merito = "Tercio Superior";



            $parametros = "CERTIFICADO | AÑO: $anio | ALUMNO: {$alumnoData['alumno']} | COD: {$alumnoData['codigo_matricula']}";
            
            if (!$force) {


                $searchParam = "%CERTIFICADO%AÑO: $anio%COD: {$alumnoData['codigo_matricula']}%";
                $stmtCheck = $this->conn->prepare("SELECT COUNT(*) FROM Historial_Reporte WHERE id_tipo_reporte = 3 AND parametros LIKE ?");
                $stmtCheck->execute([$searchParam]);
                if ($stmtCheck->fetchColumn() > 0) return ["status" => "duplicate_warning", "message" => "Certificado existente. ¿Reemplazar?"];
            } else {
                $searchParam = "%CERTIFICADO%AÑO: $anio%COD: {$alumnoData['codigo_matricula']}%";
                $stmtDel = $this->conn->prepare("DELETE FROM Historial_Reporte WHERE id_tipo_reporte = 3 AND parametros LIKE ?");
                $stmtDel->execute([$searchParam]);
            }


            $queryCertificado = "SELECT '{$alumnoData['alumno']}' as alumno, '{$alumnoData['codigo_matricula']}' as codigo, '$grado' as grado, '$nivel' as nivel, '{$alumnoData['seccion']}' as seccion, '$puesto' as puesto_obtenido, '$total' as total_alumnos_grado, '$merito' as merito_alcanzado, cur.nombre_curso, (SELECT CASE ROUND(AVG(CASE WHEN c2.nota_competencia LIKE '%AD%' THEN 4 WHEN c2.nota_competencia LIKE '%A%' AND c2.nota_competencia NOT LIKE '%AD%' THEN 3 WHEN c2.nota_competencia LIKE '%B%' THEN 2 ELSE 1 END)) WHEN 4 THEN 'AD' WHEN 3 THEN 'A' WHEN 2 THEN 'B' ELSE 'C' END FROM Calificacion c2 JOIN Historial_Academico h2 ON c2.id_historial = h2.id_historial JOIN Competencia com2 ON c2.id_competencia = com2.id_competencia WHERE h2.id_estudiante = $idEstudiante AND com2.id_curso = cur.id_curso) as nota_final_curso FROM Curso cur WHERE UPPER(TRIM(cur.grado)) = '$grado' AND UPPER(TRIM(cur.nivel)) = '$nivel' ORDER BY cur.nombre_curso";
            $queryCertificado = preg_replace('/\s+/', ' ', $queryCertificado);
            
            $stmtS = $this->conn->prepare("SELECT GROUP_CONCAT(DISTINCT seccion SEPARATOR ', ') FROM Periodo WHERE año_lectivo = ? AND UPPER(TRIM(nivel)) = ? AND UPPER(TRIM(grado)) = ?");
            $stmtS->execute([$anio, $nivel, $grado]);
            $salones = "Salones: " . $stmtS->fetchColumn();

            $stmtIns = $this->conn->prepare("INSERT INTO Historial_Reporte (id_usuario, id_tipo_reporte, id_estado_reporte, fecha_generacion, parametros, ruta_archivo, informacion_adicional) VALUES (?, 3, 1, NOW(), ?, ?, ?)");
            $stmtIns->execute([$idUsuario, $parametros, $queryCertificado, $salones]);

            $this->conn->commit();
            return ["status" => "success", "message" => "Certificado generado.\nPuesto: $puesto de $total ($merito)."];

        } catch (Exception $e) {
            if ($this->conn->inTransaction()) $this->conn->rollBack();
            return ["status" => "error", "message" => "Error: " . $e->getMessage()];
        }
    }


    private function limpiarTextoBusqueda($cadena) {

        if ($cadena === null) return "";
        $cadena = mb_strtoupper(trim($cadena), 'UTF-8');
        $originales = ['Á', 'É', 'Í', 'Ó', 'Ú', 'Ñ'];
        $reemplazos = ['A', 'E', 'I', 'O', 'U', 'N'];
        return str_replace($originales, $reemplazos, $cadena);
    }



    private function sanitizarTexto($cadena) {
        if ($cadena === null) return "";
        

        $cadena = mb_strtoupper(trim($cadena), 'UTF-8');
        

        $cadena = preg_replace('/\s+/', ' ', $cadena);
        


        $originales = ['Á', 'É', 'Í', 'Ó', 'Ú'];
        $reemplazos = ['A', 'E', 'I', 'O', 'U'];
        
        return str_replace($originales, $reemplazos, $cadena);
    }

    public function obtenerDatosParaReporte($idReporte) {
        try {
            $stmt = $this->conn->prepare("SELECT ruta_archivo, id_tipo_reporte, parametros, informacion_adicional, firma_secretaria, firma_directora, firma_docente FROM Historial_Reporte WHERE id_reporte = ?");
            $stmt->execute([$idReporte]);
            $fila = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$fila || empty($fila['ruta_archivo'])) {
                return ["status" => "error", "message" => "No hay datos generados."];
            }

            $stmtT = $this->conn->prepare("SELECT descripcion FROM Tipo_Reporte WHERE id_tipo_reporte = ?");
            $stmtT->execute([$fila['id_tipo_reporte']]);
            $tipo = $stmtT->fetchColumn();

            $sqlGuardado = $fila['ruta_archivo'];
            $stmtEjecutar = $this->conn->prepare($sqlGuardado);
            $stmtEjecutar->execute();
            $resultados = $stmtEjecutar->fetchAll(PDO::FETCH_ASSOC);

            return [
                "status" => "success",
                "data" => [
                    "info" => [
                        "tipo_reporte" => $tipo, 
                        "parametros" => $fila['parametros'], 
                        "informacion_adicional" => $fila['informacion_adicional'],
                        "firma_secretaria" => $fila['firma_secretaria'],
                        "firma_directora" => $fila['firma_directora'],
                        "firma_docente" => $fila['firma_docente']
                    ],
                    "resultados" => $resultados
                ]
            ];

        } catch (Exception $e) {
            return ["status" => "error", "message" => "Error datos: " . $e->getMessage()];
        }
    }

    private function generarEstampaFirma($idUsuario) {
        $sql = "SELECT nombres, apellidos, DNI, correo FROM Usuario_Sistema WHERE id_usuario = ?";
        $stmt = $this->conn->prepare($sql);
        $stmt->execute([$idUsuario]);
        


        $raw = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$raw) return "Firma Inválida (Usuario no encontrado)";
        
        $u = array_change_key_case($raw, CASE_LOWER);

        $fecha = date("d/m/Y H:i:s");
        return "Firmado digitalmente por: {$u['nombres']} {$u['apellidos']}\nDNI: {$u['dni']}\nCorreo: {$u['correo']}\nFecha: $fecha";
    }
}
?>