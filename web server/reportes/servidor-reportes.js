const express = require('express');
const mysql = require('mysql2/promise');
const app = express();

app.use(express.json());

// Configuración de la base de datos
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

// Endpoint para reportes de productos caducados
app.get('/api/reportes/caducados', async (req, res) => {
    try {
        const connection = await getConnection();
        const [rows] = await connection.execute('SELECT * FROM productos_caducados');
        await connection.end();
        
        res.json({
            success: true,
            data: rows,
            total: rows.length
        });
    } catch (error) {
        console.error('Error obteniendo productos caducados:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener productos caducados'
        });
    }
});

// Endpoint para reportes de productos sin stock
app.get('/api/reportes/sin-stock', async (req, res) => {
    try {
        const connection = await getConnection();
        const [rows] = await connection.execute('SELECT * FROM productos_sin_stock');
        await connection.end();
        
        res.json({
            success: true,
            data: rows,
            total: rows.length
        });
    } catch (error) {
        console.error('Error obteniendo productos sin stock:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener productos sin stock'
        });
    }
});

// Endpoint para métricas del dashboard
app.get('/api/reportes/metricas', async (req, res) => {
    try {
        const connection = await getConnection();
        
        // Obtener total de productos
        const [totalProductos] = await connection.execute('SELECT COUNT(*) as total FROM productos');
        
        // Obtener valor total del inventario
        const [valorInventario] = await connection.execute('SELECT SUM(precio * stock) as valor FROM productos');
        
        // Obtener productos próximos a vencer (próximos 30 días)
        const [proximosVencer] = await connection.execute(
            'SELECT COUNT(*) as total FROM productos WHERE fecha_caducidad BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)'
        );
        
        // Obtener productos por categoría
        const [categorias] = await connection.execute(
            'SELECT categoria, COUNT(*) as cantidad FROM productos GROUP BY categoria'
        );
        
        await connection.end();
        
        res.json({
            success: true,
            data: {
                totalProductos: totalProductos[0].total,
                valorInventario: valorInventario[0].valor || 0,
                proximosVencer: proximosVencer[0].total,
                distribucionCategorias: categorias
            }
        });
    } catch (error) {
        console.error('Error obteniendo métricas:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener métricas del inventario'
        });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', service: 'reportes' });
});

app.listen(3001, '0.0.0.0', () => {
    console.log('Servidor Reportes ejecutándose en puerto 3001');
});