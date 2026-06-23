<?php

ob_start();


ini_set('display_errors', 0);
ini_set('log_errors', 1);
error_reporting(E_ALL);
set_time_limit(300);
ini_set('memory_limit', '512M');


header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    ob_clean();
    exit(0);
}

$response = ["status" => "error", "message" => "Error inicial desconocido"];

try {

    ob_clean();


    if (!file_exists('Negocio.php')) {
        throw new Exception("El archivo Negocio.php no existe (Revise mayúsculas).");
    }
    require_once 'Negocio.php';

    $negocio = new Negocio();
    $input = file_get_contents("php://input");

    if (empty($input)) {

        $data = (object)$_POST;
    } else {
        $data = json_decode($input);
    }

    $accion = $data->accion ?? $_GET['accion'] ?? '';

    switch ($accion) {
        case 'login':
            if (isset($data->usuario) && isset($data->password)) {
                $response = $negocio->loginUsuario($data->usuario, $data->password);
            } else {
                $response = ["status" => "error", "message" => "Datos incompletos"];
            }
            break;

        case 'listar_usuarios':
            $response = $negocio->listarUsuarios();
            break;

        case 'editar_usuario':
            if (isset($data->id_usuario) && isset($data->nombres) && isset($data->usuario)) {
                $response = $negocio->editarUsuario(
                    $data->id_usuario,
                    $data->nombres,
                    $data->apellidos ?? '',
                    $data->dni ?? '',
                    $data->usuario,
                    $data->id_rol ?? 3,
                    $data->correo ?? ''
                );
            } else {
                $response = ["status" => "error", "message" => "Datos incompletos para editar"];
            }
            break;

        case 'cambiar_password':
            if (isset($data->id_usuario) && isset($data->new_password)) {
                $response = $negocio->cambiarPassword($data->id_usuario, $data->new_password);
            } else {
                $response = ["status" => "error", "message" => "Datos incompletos"];
            }
            break;

        case 'crear_usuario':

            if (isset($data->nombres) && isset($data->usuario) && isset($data->password)) {
                $response = $negocio->crearUsuario(
                    $data->nombres,
                    $data->apellidos ?? '',
                    $data->dni ?? '',
                    $data->usuario,
                    $data->password,
                    $data->id_rol ?? 3,
                    $data->correo ?? ''
                );
            } else {
                $response = ["status" => "error", "message" => "Datos incompletos"];
            }
            break;

        case 'cambiar_estado_usuario':
            if (isset($data->id_usuario) && isset($data->nuevo_estado)) {
                $response = $negocio->cambiarEstadoUsuario($data->id_usuario, $data->nuevo_estado);
            }
            break;

        case 'listar_reportes':

            $idU = $data->id_usuario ?? 0;
            $idR = $data->id_rol ?? 0;
            $response = ["status" => "success", "data" => $negocio->listarReportes($idU, $idR)];
            break;

        case 'obtener_avisos_pendientes':
            if (isset($data->id_usuario) && isset($data->id_rol)) {
                $response = $negocio->obtenerAvisosPendientes(
                    $data->id_usuario,
                    $data->id_rol
                );
            } else {
                $response = ["status" => "error", "message" => "Faltan datos para obtener avisos pendientes"];
            }
            break;

        case 'crear_reporte':
            if (isset($data->id_usuario) && isset($data->tipo_reporte) && isset($data->ruta)) {
                $params = isset($data->parametros) ? $data->parametros : "";
                $response = $negocio->crearReporte($data->id_usuario, $data->tipo_reporte, $params, $data->ruta);
            } else {
                $response = ["status" => "error", "message" => "Datos incompletos"];
            }
            break;

        case 'cambiar_estado_reporte':

            if (isset($data->id_reporte) && isset($data->id_usuario) && isset($data->id_rol)) {
                $response = $negocio->firmarReporte($data->id_reporte, $data->id_usuario, $data->id_rol);
            } else {
                $response = ["status" => "error", "message" => "Faltan datos de usuario para firmar"];
            }
            break;

        case 'firmar_lote_reportes':
            if (isset($data->ids) && is_array($data->ids) && isset($data->id_usuario) && isset($data->id_rol)) {
                $response = $negocio->firmarLoteBoletas($data->ids, $data->id_usuario, $data->id_rol);
            } else {
                $response = ["status" => "error", "message" => "Faltan datos para firma masiva"];
            }
            break;

        case 'listar_alumnos':
            if (isset($data->id_periodo)) {
                $response = $negocio->obtenerAlumnosPorSeccion($data->id_periodo);
            }
            break;

        case 'test_conexion':
            $response = ["status" => "success", "message" => "Conexión con controlador exitosa"];
            break;

        case 'procesar_asistencia_excel':
            if (isset($data->filas) && isset($data->id_usuario)) {
                $nombre = $data->nombre_archivo ?? 'asistencia.xlsx';
                $idDocente = isset($data->id_docente) ? $data->id_docente : null;
                $force = isset($data->force_upload) ? $data->force_upload : false;

                $response = $negocio->procesarAsistenciaExcel(
                    $data->filas,
                    $nombre,
                    $data->id_usuario,
                    $idDocente,
                    $force
                );
            } else {
                $response = ["status" => "error", "message" => "Faltan datos para asistencia"];
            }
            break;

        case 'procesar_notas_excel':
            if (isset($data->filas) && isset($data->id_usuario)) {
                $hojas = json_decode(json_encode($data->filas), true);
                $nombre = $data->nombre_archivo ?? 'notas.xlsx';
                $idDocente = isset($data->id_docente) ? $data->id_docente : null;
                $force = isset($data->force_upload) ? $data->force_upload : false;

                $response = $negocio->procesarNotasExcel(
                    $hojas,
                    $nombre,
                    $data->id_usuario,
                    $idDocente,
                    $force
                );
            } else {
                $response = ["status" => "error", "message" => "Faltan datos para notas"];
            }
            break;
        case 'listar_anios_reporte':
            $response = ["status" => "success", "data" => $negocio->listarAniosReporte()];
            break;

        case 'listar_niveles_reporte':
            if (isset($data->anio)) {
                $response = ["status" => "success", "data" => $negocio->listarNivelesReporte($data->anio)];
            } else {
                $response = ["status" => "error", "message" => "Falta año"];
            }
            break;

        case 'listar_salones_reporte':
            if (isset($data->anio) && isset($data->nivel)) {
                $response = ["status" => "success", "data" => $negocio->listarSalonesReporte($data->anio, $data->nivel)];
            } else {
                $response = ["status" => "error", "message" => "Faltan parámetros"];
            }
            break;

        case 'listar_bimestres_reporte':
            if (isset($data->id_periodo)) {
                $response = ["status" => "success", "data" => $negocio->listarBimestresReporte($data->id_periodo)];
            } else {
                $response = ["status" => "error", "message" => "Falta periodo"];
            }
            break;


        case 'generar_boleta_notas':
            if (isset($data->id_usuario) && isset($data->id_periodo) && isset($data->bimestre) && isset($data->fecha_inicio) && isset($data->fecha_fin)) {
                $force = isset($data->force) ? $data->force : false;
                $response = $negocio->generarBoletaNotas(
                    $data->id_usuario,
                    $data->id_periodo,
                    $data->bimestre,
                    $data->fecha_inicio,
                    $data->fecha_fin,
                    $force
                );
            } else {
                $response = ["status" => "error", "message" => "Faltan parámetros para generar la boleta"];
            }
            break;

        case 'listar_bimestres_nivel':
            if (isset($data->anio) && isset($data->nivel)) {
                $response = ["status" => "success", "data" => $negocio->listarBimestresPorNivel($data->anio, $data->nivel)];
            } else {
                $response = ["status" => "error", "message" => "Faltan datos (año, nivel)"];
            }
            break;

        case 'generar_reporte_rendimiento':
            if (isset($data->id_usuario, $data->anio, $data->nivel, $data->bimestre, $data->fecha_inicio, $data->fecha_fin)) {

                $force = isset($data->force) ? $data->force : false;
                $ignore = isset($data->ignore_missing) ? $data->ignore_missing : false;

                $response = $negocio->generarReporteRendimiento(
                    $data->id_usuario,
                    $data->anio,
                    $data->nivel,
                    $data->bimestre,
                    $data->fecha_inicio,
                    $data->fecha_fin,
                    $force,
                    $ignore
                );
            } else {
                $response = ["status" => "error", "message" => "Faltan parámetros"];
            }
            break;

        case 'buscar_estudiantes_certificado':
            if (isset($data->anio) && isset($data->busqueda)) {
                $response = ["status" => "success", "data" => $negocio->buscarEstudiantesCertificado($data->anio, $data->busqueda)];
            } else {
                $response = ["status" => "error", "message" => "Faltan datos de búsqueda"];
            }
            break;

        case 'validar_requisitos_certificado':
            if (isset($data->id_estudiante) && isset($data->id_periodo)) {
                $response = ["status" => "success", "data" => $negocio->validarRequisitosCertificado($data->id_estudiante, $data->id_periodo)];
            } else {
                $response = ["status" => "error", "message" => "Faltan datos"];
            }
            break;

        case 'generar_certificado_estudios':
            if (isset($data->id_usuario, $data->id_estudiante, $data->id_periodo, $data->anio)) {
                $force = isset($data->force) ? $data->force : false;
                $response = $negocio->generarCertificadoEstudios(
                    $data->id_usuario,
                    $data->id_estudiante,
                    $data->id_periodo,
                    $data->anio,
                    $force
                );
            } else {
                $response = ["status" => "error", "message" => "Parámetros incompletos"];
            }
            break;

        case 'obtener_datos_reporte':
            if (isset($data->id_reporte)) {
                $response = $negocio->obtenerDatosParaReporte($data->id_reporte);
            } else {
                $response = ["status" => "error", "message" => "Falta ID"];
            }
            break;

        default:
            $response = ["status" => "error", "message" => "Acción no reconocida: " . $accion];
            break;
    }
} catch (Throwable $e) {

    $response = [
        "status" => "error",
        "message" => "Error Crítico Backend: " . $e->getMessage(),
        "file" => basename($e->getFile()),
        "line" => $e->getLine()
    ];
}


ob_clean();
$json_final = json_encode($response);


if ($json_final === false) {
    echo json_encode([
        "status" => "error",
        "message" => "Fallo al generar JSON (Posible problema de caracteres): " . json_last_error_msg()
    ]);
} else {
    echo $json_final;
}

ob_end_flush();
