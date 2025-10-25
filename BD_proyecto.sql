CREATE DATABASE IF NOT EXISTS inventario
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE inventario;

CREATE TABLE productos (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  categoria VARCHAR(50),
  precio DECIMAL(10,2),
  stock INT NOT NULL DEFAULT 0,
  fecha_caducidad DATE,
  INDEX idx_categoria (categoria),
  INDEX idx_caducidad (fecha_caducidad)
) ENGINE=InnoDB;

CREATE TABLE productos_caducados (
  id INT UNSIGNED PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  categoria VARCHAR(50),
  precio DECIMAL(10,2),
  stock INT,
  fecha_caducidad DATE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_caducados_prod
    FOREIGN KEY (id) REFERENCES productos(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE productos_sin_stock (
  id INT UNSIGNED PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  categoria VARCHAR(50),
  precio DECIMAL(10,2),
  stock INT,
  fecha_caducidad DATE,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sinstock_prod
    FOREIGN KEY (id) REFERENCES productos(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE empleados (
  id_trabajador BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  apellido_paterno VARCHAR(50) NOT NULL,
  dni VARCHAR(20) NOT NULL UNIQUE,
  edad INT NOT NULL,
  categoria VARCHAR(100),
  contrasena_numerica CHAR(8) NOT NULL,
  CONSTRAINT chk_edad CHECK (edad >= 18),
  CONSTRAINT chk_contrasena CHECK (REGEXP_LIKE(contrasena_numerica, '^[0-9]{8}$'))
) ENGINE=InnoDB;

INSERT INTO productos (nombre, categoria, precio, stock, fecha_caducidad) VALUES
('Leche Entera','Lácteos',4.50,120,'2025-12-15'),
('Yogurt Natural','Lácteos',2.80,80,'2025-11-10'),
('Queso Fresco','Lácteos',12.00,50,'2025-10-25'),
('Pan Integral','Panadería',3.20,100,'2025-10-05'),
('Galletas de Avena','Snacks',5.00,200,'2026-01-15'),
('Cereal de Maíz','Desayuno',6.50,150,'2026-03-10'),
('Aceite de Girasol','Abarrotes',15.90,70,'2026-05-20'),
('Arroz Extra','Granos',7.20,300,'2026-08-01'),
('Frijoles Negros','Granos',8.10,250,'2026-07-18'),
('Jugo de Naranja','Bebidas',4.80,90,'2025-11-22'),
('Refresco Cola','Bebidas',3.50,200,'2026-04-14'),
('Agua Mineral','Bebidas',1.20,400,'2027-01-01'),
('Chocolate en Barra','Dulces',2.50,300,'2026-09-30'),
('Caramelos Surtidos','Dulces',6.00,500,'2026-12-12'),
('Café Molido','Bebidas',18.00,60,'2027-05-05');

DELIMITER //

CREATE TRIGGER productos_ai
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
  IF NEW.fecha_caducidad IS NOT NULL AND NEW.fecha_caducidad < CURDATE() THEN
    INSERT INTO productos_caducados (id,nombre,categoria,precio,stock,fecha_caducidad)
    VALUES (NEW.id,NEW.nombre,NEW.categoria,NEW.precio,NEW.stock,NEW.fecha_caducidad)
    ON DUPLICATE KEY UPDATE nombre=NEW.nombre,categoria=NEW.categoria,precio=NEW.precio,stock=NEW.stock,fecha_caducidad=NEW.fecha_caducidad;
  ELSE
    DELETE FROM productos_caducados WHERE id = NEW.id;
  END IF;

  IF NEW.stock <= 0 THEN
    INSERT INTO productos_sin_stock (id,nombre,categoria,precio,stock,fecha_caducidad)
    VALUES (NEW.id,NEW.nombre,NEW.categoria,NEW.precio,NEW.stock,NEW.fecha_caducidad)
    ON DUPLICATE KEY UPDATE nombre=NEW.nombre,categoria=NEW.categoria,precio=NEW.precio,stock=NEW.stock,fecha_caducidad=NEW.fecha_caducidad;
  ELSE
    DELETE FROM productos_sin_stock WHERE id = NEW.id;
  END IF;
END//

CREATE TRIGGER productos_au
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
  IF NEW.fecha_caducidad IS NOT NULL AND NEW.fecha_caducidad < CURDATE() THEN
    INSERT INTO productos_caducados (id,nombre,categoria,precio,stock,fecha_caducidad)
    VALUES (NEW.id,NEW.nombre,NEW.categoria,NEW.precio,NEW.stock,NEW.fecha_caducidad)
    ON DUPLICATE KEY UPDATE nombre=NEW.nombre,categoria=NEW.categoria,precio=NEW.precio,stock=NEW.stock,fecha_caducidad=NEW.fecha_caducidad;
  ELSE
    DELETE FROM productos_caducados WHERE id = NEW.id;
  END IF;

  IF NEW.stock <= 0 THEN
    INSERT INTO productos_sin_stock (id,nombre,categoria,precio,stock,fecha_caducidad)
    VALUES (NEW.id,NEW.nombre,NEW.categoria,NEW.precio,NEW.stock,NEW.fecha_caducidad)
    ON DUPLICATE KEY UPDATE nombre=NEW.nombre,categoria=NEW.categoria,precio=NEW.precio,stock=NEW.stock,fecha_caducidad=NEW.fecha_caducidad;
  ELSE
    DELETE FROM productos_sin_stock WHERE id = NEW.id;
  END IF;
END//
DELIMITER ;

DELIMITER //
CREATE EVENT IF NOT EXISTS sync_inventario_diario
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY)
DO
BEGIN
  REPLACE INTO productos_caducados (id,nombre,categoria,precio,stock,fecha_caducidad)
  SELECT id,nombre,categoria,precio,stock,fecha_caducidad
  FROM productos WHERE fecha_caducidad IS NOT NULL AND fecha_caducidad < CURDATE();

  DELETE pc FROM productos_caducados pc
  JOIN productos p ON p.id = pc.id
  WHERE p.fecha_caducidad IS NULL OR p.fecha_caducidad >= CURDATE();

  REPLACE INTO productos_sin_stock (id,nombre,categoria,precio,stock,fecha_caducidad)
  SELECT id,nombre,categoria,precio,stock,fecha_caducidad
  FROM productos WHERE stock <= 0;

  DELETE ps FROM productos_sin_stock ps
  JOIN productos p ON p.id = ps.id
  WHERE p.stock > 0;
END//
DELIMITER ;


