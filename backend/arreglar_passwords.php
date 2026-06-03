<?php
require_once 'Conexion.php';

try {
    $db = new Conexion();
    $conn = $db->conectar();


    $passwordPlano = "123456";


    $hashReal = password_hash($passwordPlano, PASSWORD_DEFAULT);


    $query = "UPDATE Usuario_Sistema SET contrasena_hash = :hash";
    $stmt = $conn->prepare($query);
    $stmt->bindParam(":hash", $hashReal);
    
    if ($stmt->execute()) {
        echo "<h1>¡Éxito!</h1>";
        echo "<p>Todas las contraseñas han sido restablecidas a: <strong>123456</strong></p>";
        echo "<p>Hash generado: " . $hashReal . "</p>";
        echo "<p><a href='javascript:window.close()'>Ya puedes cerrar esta pestaña e intentar loguearte en Flutter.</a></p>";
    } else {
        echo "<h1>Error</h1>";
        echo "No se pudo actualizar la base de datos.";
    }

} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
?>