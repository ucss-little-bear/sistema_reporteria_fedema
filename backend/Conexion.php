<?php
class Conexion {

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

            $dsn = "mysql:host=" . $this->host . ";dbname=" . $this->db_name . ";charset=utf8mb4";
            
            $this->conn = new PDO($dsn, $this->username, $this->password);
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            

            $this->conn->exec("set names utf8mb4");
            $this->conn->exec("SET CHARACTER SET utf8mb4");
            
        } catch(PDOException $exception) {

            throw new Exception("Error de conexión a BD: " . $exception->getMessage());
        }

        return $this->conn;
    }
}
?>