-- SCRIPT BD
ALTER TABLE Usuario_Sistema 
ADD COLUMN primer_login TINYINT(1) DEFAULT 1 AFTER contrasena_hash;