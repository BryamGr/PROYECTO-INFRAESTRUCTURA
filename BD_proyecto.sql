-- Crear base de datos
CREATE DATABASE IF NOT EXISTS inventario;
USE inventario;
-- Tabla principal de productos
CREATE TABLE productos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(50),
    precio DECIMAL(10,2),
    stock INT,
    fecha_caducidad DATE
);

-- Tabla para productos caducados
CREATE TABLE productos_caducados (
    id INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(50),
    precio DECIMAL(10,2),
    stock INT,
    fecha_caducidad DATE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla para productos sin stock
CREATE TABLE productos_sin_stock (
    id INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(50),
    precio DECIMAL(10,2),
    stock INT,
    fecha_caducidad DATE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertar 15 productos de ejemplo
INSERT INTO productos (nombre, categoria, precio, stock, fecha_caducidad) VALUES
('Leche Entera', 'Lácteos', 4.50, 120, '2025-12-15'),
('Yogurt Natural', 'Lácteos', 2.80, 80, '2025-11-10'),
('Queso Fresco', 'Lácteos', 12.00, 50, '2025-10-25'),
('Pan Integral', 'Panadería', 3.20, 100, '2025-10-05'),
('Galletas de Avena', 'Snacks', 5.00, 200, '2026-01-15'),
('Cereal de Maíz', 'Desayuno', 6.50, 150, '2026-03-10'),
('Aceite de Girasol', 'Abarrotes', 15.90, 70, '2026-05-20'),
('Arroz Extra', 'Granos', 7.20, 300, '2026-08-01'),
('Frijoles Negros', 'Granos', 8.10, 250, '2026-07-18'),
('Jugo de Naranja', 'Bebidas', 4.80, 90, '2025-11-22'),
('Refresco Cola', 'Bebidas', 3.50, 200, '2026-04-14'),
('Agua Mineral', 'Bebidas', 1.20, 400, '2027-01-01'),
('Chocolate en Barra', 'Dulces', 2.50, 300, '2026-09-30'),
('Caramelos Surtidos', 'Dulces', 6.00, 500, '2026-12-12'),
('Café Molido', 'Bebidas', 18.00, 60, '2027-05-05');

-- Trigger para productos caducados
DELIMITER //
CREATE TRIGGER mover_a_caducados
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.fecha_caducidad < CURDATE() THEN
        INSERT INTO productos_caducados (id, nombre, categoria, precio, stock, fecha_caducidad)
        VALUES (NEW.id, NEW.nombre, NEW.categoria, NEW.precio, NEW.stock, NEW.fecha_caducidad)
        ON DUPLICATE KEY UPDATE 
            nombre=NEW.nombre, categoria=NEW.categoria, precio=NEW.precio, stock=NEW.stock, fecha_caducidad=NEW.fecha_caducidad;
    END IF;
END//
DELIMITER ;

-- Trigger para productos sin stock
DELIMITER //
CREATE TRIGGER mover_a_sin_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock <= 0 THEN
        INSERT INTO productos_sin_stock (id, nombre, categoria, precio, stock, fecha_caducidad)
        VALUES (NEW.id, NEW.nombre, NEW.categoria, NEW.precio, NEW.stock, NEW.fecha_caducidad)
        ON DUPLICATE KEY UPDATE 
            nombre=NEW.nombre, categoria=NEW.categoria, precio=NEW.precio, stock=NEW.stock, fecha_caducidad=NEW.fecha_caducidad;
    END IF;
END//
DELIMITER ;

