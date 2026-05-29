<?php
class Conexion {
    // Intentamos leer las variables de entorno de la nube; si no existen, usamos tus datos locales por defecto
    private $host;
    private $db_name;
    private $username;
    private $password;
    public $conn;

    public function __construct() {
        $this->host = getenv('MYSQLHOST') ?: "localhost";
        $this->db_name = getenv('MYSQLDATABASE') ?: "bdcolegio";
        $this->username = getenv('MYSQLUSER') ?: "root";
        $this->password = getenv('MYSQLPASSWORD') ?: "";
    }

    public function conectar() {
        $this->conn = null;

        try {
            // Usamos utf8mb4 para compatibilidad total con caracteres especiales y emojis
            $dsn = "mysql:host=" . $this->host . ";dbname=" . $this->db_name . ";charset=utf8mb4";
            
            $this->conn = new PDO($dsn, $this->username, $this->password);
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            
            // Forzar collation correcta para evitar error 1267
            $this->conn->exec("set names utf8mb4");
            $this->conn->exec("SET CHARACTER SET utf8mb4");
            
        } catch(PDOException $exception) {
            // Lanzamos la excepción para que el Controlador la capture y la convierta en JSON
            throw new Exception("Error de conexión a BD: " . $exception->getMessage());
        }

        return $this->conn;
    }
}
?>