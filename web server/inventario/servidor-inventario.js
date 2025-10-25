const express = require('express');
const mysql = require('mysql2/promise');
const app = express();

app.use(express.json());

const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'password',
    database: process.env.DB_NAME || 'inventario',
    port: process.env.DB_PORT || 3306
};

async function getConnection() {
    return await mysql.createConnection(dbConfig);
}

app.get('/api/productos', async (req, res) => {
    try {
        const connection = await getConnection();
        const [rows] = await connection.execute('SELECT * FROM productos');
        await connection.end();
        
        res.json({
            success: true,
            data: rows
        });
    } catch (error) {
        console.error('Error obteniendo productos:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener productos de la base de datos'
        });
    }
});

app.post('/api/productos', async (req, res) => {
    try {
        const { nombre, categoria, precio, stock, fecha_caducidad } = req.body;
        const connection = await getConnection();
        
        const [result] = await connection.execute(
            'INSERT INTO productos (nombre, categoria, precio, stock, fecha_caducidad) VALUES (?, ?, ?, ?, ?)',
            [nombre, categoria, precio, stock, fecha_caducidad]
        );
        
        await connection.end();
        
        res.status(201).json({
            success: true,
            message: 'Producto agregado correctamente',
            id: result.insertId
        });
    } catch (error) {
        console.error('Error agregando producto:', error);
        res.status(500).json({
            success: false,
            error: 'Error al agregar producto'
        });
    }
});

app.put('/api/productos/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { nombre, categoria, precio, stock, fecha_caducidad } = req.body;
        const connection = await getConnection();
        
        const [result] = await connection.execute(
            'UPDATE productos SET nombre = ?, categoria = ?, precio = ?, stock = ?, fecha_caducidad = ? WHERE id = ?',
            [nombre, categoria, precio, stock, fecha_caducidad, id]
        );
        
        await connection.end();
        
        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                error: 'Producto no encontrado'
            });
        }
        
        res.json({
            success: true,
            message: 'Producto actualizado correctamente'
        });
    } catch (error) {
        console.error('Error actualizando producto:', error);
        res.status(500).json({
            success: false,
            error: 'Error al actualizar producto'
        });
    }
});

app.delete('/api/productos/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const connection = await getConnection();
        
        const [result] = await connection.execute(
            'DELETE FROM productos WHERE id = ?',
            [id]
        );
        
        await connection.end();
        
        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                error: 'Producto no encontrado'
            });
        }
        
        res.json({
            success: true,
            message: 'Producto eliminado correctamente'
        });
    } catch (error) {
        console.error('Error eliminando producto:', error);
        res.status(500).json({
            success: false,
            error: 'Error al eliminar producto'
        });
    }
});

app.get('/health', (req, res) => {
    res.json({ status: 'OK', service: 'inventario' });
});

app.listen(3000, '0.0.0.0', () => {
    console.log('Servidor Inventario ejecutándose en puerto 3000');
});
